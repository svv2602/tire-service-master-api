require 'rails_helper'

RSpec.describe ScheduleManager, type: :service do
  let!(:region) { create(:region) }
  let!(:city) { create(:city, region: region) }
  let!(:partner) { create(:partner, is_active: true) }
  let!(:service_point) { create(:service_point, partner: partner, city: city) }
  let!(:weekday) { create(:weekday, sort_order: 1) } # Понедельник
  let!(:template) { create(:schedule_template, 
                          service_point: service_point, 
                          weekday: weekday,
                          is_working_day: true,
                          opening_time: '09:00:00',
                          closing_time: '18:00:00') }
  
  # Создаем посты с разными длительностями
  let!(:service_post_1) { create(:service_post, 
                                 service_point: service_point, 
                                 post_number: 1, 
                                 slot_duration: 30,
                                 name: "Быстрый пост") }
  let!(:service_post_2) { create(:service_post, 
                                 service_point: service_point, 
                                 post_number: 2, 
                                 slot_duration: 60,
                                 name: "Стандартный пост") }
  let!(:service_post_3) { create(:service_post, 
                                 service_point: service_point, 
                                 post_number: 3, 
                                 slot_duration: 90,
                                 name: "Сложный пост") }

  describe '.generate_slots_for_date' do
    let(:test_date) { Date.current.next_occurring(:monday) }

    context 'когда у точки есть активные посты' do
      it 'генерирует слоты с индивидуальными длительностями для каждого поста' do
        ScheduleManager.generate_slots_for_date(service_point.id, test_date)

        # Проверяем слоты для поста 1 (30 минут)
        post_1_slots = ScheduleSlot.where(service_post: service_post_1, slot_date: test_date)
        expect(post_1_slots.count).to eq(18) # 9 часов / 30 минут = 18 слотов
        expect(post_1_slots.first.duration_in_minutes).to eq(30)

        # Проверяем слоты для поста 2 (60 минут)
        post_2_slots = ScheduleSlot.where(service_post: service_post_2, slot_date: test_date)
        expect(post_2_slots.count).to eq(9) # 9 часов / 60 минут = 9 слотов
        expect(post_2_slots.first.duration_in_minutes).to eq(60)

        # Проверяем слоты для поста 3 (90 минут)
        post_3_slots = ScheduleSlot.where(service_post: service_post_3, slot_date: test_date)
        expect(post_3_slots.count).to eq(6) # 9 часов / 90 минут = 6 слотов
        expect(post_3_slots.first.duration_in_minutes).to eq(90)
      end

      it 'правильно связывает слоты с service_post_id' do
        ScheduleManager.generate_slots_for_date(service_point.id, test_date)

        service_point.service_posts.each do |service_post|
          slots = ScheduleSlot.where(service_post: service_post, slot_date: test_date)
          expect(slots.all? { |slot| slot.service_post_id == service_post.id }).to be_truthy
          expect(slots.all? { |slot| slot.post_number == service_post.post_number }).to be_truthy
        end
      end

      it 'генерирует непрерывное покрытие рабочего времени' do
        ScheduleManager.generate_slots_for_date(service_point.id, test_date)

        service_point.service_posts.each do |service_post|
          slots = ScheduleSlot.where(service_post: service_post, slot_date: test_date)
                              .order(:start_time)
          
          # Первый слот начинается в начале рабочего дня
          expect(slots.first.start_time.strftime('%H:%M')).to eq('09:00')
          
          # Слоты идут непрерывно
          slots.each_cons(2) do |current_slot, next_slot|
            expect(current_slot.end_time).to eq(next_slot.start_time)
          end
        end
      end
    end

    context 'когда у точки нет активных постов' do
      before do
        service_point.service_posts.update_all(is_active: false)
      end

      it 'удаляет неиспользуемые слоты и завершается' do
        # Создаем тестовые слоты
        create(:schedule_slot, service_point: service_point, slot_date: test_date)
        
        expect {
          ScheduleManager.generate_slots_for_date(service_point.id, test_date)
        }.to change { ScheduleSlot.where(service_point: service_point, slot_date: test_date).count }.to(0)
      end

      it 'логирует предупреждение' do
        expect(Rails.logger).to receive(:warn)
          .with("ScheduleManager: Нет активных постов для точки обслуживания #{service_point.id}")
        
        ScheduleManager.generate_slots_for_date(service_point.id, test_date)
      end
    end

    context 'когда день нерабочий' do
      before do
        template.update!(is_working_day: false)
      end

      it 'удаляет неиспользуемые слоты' do
        create(:schedule_slot, service_point: service_point, slot_date: test_date)
        
        expect {
          ScheduleManager.generate_slots_for_date(service_point.id, test_date)
        }.to change { ScheduleSlot.where(service_point: service_point, slot_date: test_date).count }.to(0)
      end
    end
  end

  describe '.generate_slots_for_period' do
    let(:start_date) { Date.current.next_occurring(:monday) }
    let(:end_date) { start_date + 2.days }

    it 'генерирует слоты для каждого дня в периоде' do
      ScheduleManager.generate_slots_for_period(service_point.id, start_date, end_date)

      (start_date..end_date).each do |date|
        total_slots = ScheduleSlot.where(service_point: service_point, slot_date: date).count
        expect(total_slots).to be > 0
      end
    end
  end

  describe '.delete_unused_slots' do
    let(:test_date) { Date.current + 1.day }
    let!(:used_slot) { create(:schedule_slot, service_point: service_point, slot_date: test_date) }
    let!(:unused_slot) { create(:schedule_slot, service_point: service_point, slot_date: test_date) }
    let!(:booking) { create(:booking, slot: used_slot) }

    it 'удаляет только неиспользуемые слоты' do
      expect {
        ScheduleManager.delete_unused_slots(service_point.id, test_date)
      }.to change { ScheduleSlot.where(service_point: service_point, slot_date: test_date).count }.by(-1)

      expect(ScheduleSlot.exists?(used_slot.id)).to be_truthy
      expect(ScheduleSlot.exists?(unused_slot.id)).to be_falsey
    end
  end

  describe 'интеграция с ServicePost' do
    let(:test_date) { Date.current.next_occurring(:monday) }

    it 'использует актуальные настройки слотов из service_posts' do
      # Изменяем длительность слота для поста
      service_post_1.update!(slot_duration: 45)

      ScheduleManager.generate_slots_for_date(service_point.id, test_date)

      slots = ScheduleSlot.where(service_post: service_post_1, slot_date: test_date)
      expect(slots.first.duration_in_minutes).to eq(45)
      expect(slots.count).to eq(12) # 9 часов / 45 минут = 12 слотов
    end

    it 'не генерирует слоты для неактивных постов' do
      service_post_2.update!(is_active: false)

      ScheduleManager.generate_slots_for_date(service_point.id, test_date)

      slots = ScheduleSlot.where(service_post: service_post_2, slot_date: test_date)
      expect(slots.count).to eq(0)
    end
  end
end 