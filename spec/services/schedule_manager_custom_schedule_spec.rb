require 'rails_helper'

RSpec.describe ScheduleManager, type: :service do
  let(:service_point) { create(:service_point) }
  let(:date) { Date.parse('2024-12-09') } # понедельник

  describe '.generate_slots_for_date с индивидуальными расписаниями' do
    let!(:weekday) { create(:weekday, sort_order: 1, name: 'Monday') } # понедельник
    let!(:template) do
      create(:schedule_template, 
        service_point: service_point,
        weekday: weekday,
        is_working_day: true,
        opening_time: '08:00',
        closing_time: '18:00'
      )
    end

    context 'когда нет активных постов' do
      it 'не создает слоты' do
        expect {
          ScheduleManager.generate_slots_for_date(service_point.id, date)
        }.not_to change(ScheduleSlot, :count)
      end
    end

    context 'с постом без индивидуального расписания' do
      let!(:regular_post) do
        create(:service_post, 
          service_point: service_point,
          post_number: 1,
          slot_duration: 60,
          has_custom_schedule: false
        )
      end

      it 'создает слоты по общему расписанию точки' do
        expect {
          ScheduleManager.generate_slots_for_date(service_point.id, date)
        }.to change(ScheduleSlot, :count)

        slots = ScheduleSlot.where(service_point: service_point, service_post: regular_post, slot_date: date)
        expect(slots).not_to be_empty
        
        # Первый слот должен начинаться в 08:00
        first_slot = slots.order(:start_time).first
        expect(first_slot.start_time.strftime('%H:%M:%S')).to eq('08:00:00')
      end
    end

    context 'с постом с индивидуальным расписанием' do
      let!(:custom_post) do
        create(:service_post, 
          service_point: service_point,
          post_number: 2,
          slot_duration: 30,
          has_custom_schedule: true,
          working_days: {
            'monday' => true,
            'tuesday' => false,
            'wednesday' => true
          },
          custom_hours: {
            'start' => '10:00',
            'end' => '16:00'
          }
        )
      end

      it 'создает слоты по индивидуальному расписанию' do
        expect {
          ScheduleManager.generate_slots_for_date(service_point.id, date)
        }.to change(ScheduleSlot, :count)

        slots = ScheduleSlot.where(service_point: service_point, service_post: custom_post, slot_date: date)
        expect(slots).not_to be_empty
        
        # Первый слот должен начинаться в 10:00 (индивидуальное время)
        first_slot = slots.order(:start_time).first
        expect(first_slot.start_time.strftime('%H:%M:%S')).to eq('10:00:00')
        
        # Последний слот должен заканчиваться не позже 16:00
        last_slot = slots.order(:start_time).last
        expect(last_slot.end_time.strftime('%H:%M:%S')).to eq('16:00:00')
      end

      context 'в нерабочий день' do
        let(:tuesday_date) { Date.parse('2024-12-10') } # вторник
        let!(:tuesday_weekday) { create(:weekday, sort_order: 2, name: 'Tuesday') }
        let!(:tuesday_template) do
          create(:schedule_template, 
            service_point: service_point,
            weekday: tuesday_weekday,
            is_working_day: true,
            opening_time: '08:00',
            closing_time: '18:00'
          )
        end

        it 'не создает слоты для поста в его нерабочий день' do
          expect {
            ScheduleManager.generate_slots_for_date(service_point.id, tuesday_date)
          }.not_to change { 
            ScheduleSlot.where(service_point: service_point, service_post: custom_post, slot_date: tuesday_date).count 
          }
        end
      end
    end

    context 'с несколькими постами с разными расписаниями' do
      let!(:regular_post) do
        create(:service_post, 
          service_point: service_point,
          post_number: 1,
          slot_duration: 60,
          has_custom_schedule: false
        )
      end

      let!(:custom_post) do
        create(:service_post, 
          service_point: service_point,
          post_number: 2,
          slot_duration: 30,
          has_custom_schedule: true,
          working_days: { 'monday' => true },
          custom_hours: {
            'start' => '10:00',
            'end' => '16:00'
          }
        )
      end

      it 'создает слоты для всех рабочих постов' do
        ScheduleManager.generate_slots_for_date(service_point.id, date)

        regular_slots = ScheduleSlot.where(service_point: service_point, service_post: regular_post, slot_date: date)
        custom_slots = ScheduleSlot.where(service_point: service_point, service_post: custom_post, slot_date: date)

        expect(regular_slots).not_to be_empty
        expect(custom_slots).not_to be_empty

        # Регулярный пост начинает с 08:00
        expect(regular_slots.order(:start_time).first.start_time.strftime('%H:%M:%S')).to eq('08:00:00')
        
        # Кастомный пост начинает с 10:00
        expect(custom_slots.order(:start_time).first.start_time.strftime('%H:%M:%S')).to eq('10:00:00')
      end
    end
  end

  describe '.parse_time_for_post' do
    let(:service_point_with_hours) do
      create(:service_point, working_hours: {
        'monday' => { 'start' => '09:00', 'end' => '17:00' }
      })
    end

    let(:default_time) { Time.parse('08:00') }

    context 'для поста с индивидуальным расписанием' do
      let(:custom_post) do
        create(:service_post,
          service_point: service_point_with_hours,
          has_custom_schedule: true,
          custom_hours: {
            'start' => '10:00',
            'end' => '18:00'
          }
        )
      end

      it 'возвращает время из индивидуального расписания' do
        result = ScheduleManager.send(:parse_time_for_post, custom_post, 'monday', 'start', default_time)
        expect(result).to eq('10:00:00')
      end
    end

    context 'для поста без индивидуального расписания' do
      let(:regular_post) do
        create(:service_post,
          service_point: service_point_with_hours,
          has_custom_schedule: false
        )
      end

      it 'возвращает время точки обслуживания' do
        result = ScheduleManager.send(:parse_time_for_post, regular_post, 'monday', 'start', default_time)
        expect(result).to eq('09:00')
      end

      it 'возвращает время по умолчанию если нет данных о точке' do
        post_without_data = create(:service_post, service_point: service_point, has_custom_schedule: false)
        result = ScheduleManager.send(:parse_time_for_post, post_without_data, 'monday', 'start', default_time)
        expect(result).to eq('08:00:00')
      end
    end
  end

  describe '.generate_slots_for_post' do
    let!(:service_post) do
      create(:service_post, 
        service_point: service_point,
        post_number: 1,
        slot_duration: 30
      )
    end

    it 'создает слоты с правильными интервалами' do
      start_time = '10:00:00'
      end_time = '12:00:00'

      expect {
        ScheduleManager.send(:generate_slots_for_post, service_point, date, start_time, end_time, service_post)
      }.to change(ScheduleSlot, :count).by(4) # 4 слота по 30 минут

      slots = ScheduleSlot.where(service_post: service_post, slot_date: date).order(:start_time)
      
      expect(slots.first.start_time.strftime('%H:%M:%S')).to eq('10:00:00')
      expect(slots.first.end_time.strftime('%H:%M:%S')).to eq('10:30:00')
      
      expect(slots.last.start_time.strftime('%H:%M:%S')).to eq('11:30:00')
      expect(slots.last.end_time.strftime('%H:%M:%S')).to eq('12:00:00')
    end

    it 'не создает дублирующиеся слоты' do
      start_time = '10:00:00'
      end_time = '11:00:00'

      # Первый вызов
      ScheduleManager.send(:generate_slots_for_post, service_point, date, start_time, end_time, service_post)
      initial_count = ScheduleSlot.count

      # Второй вызов - не должен создать новые слоты
      expect {
        ScheduleManager.send(:generate_slots_for_post, service_point, date, start_time, end_time, service_post)
      }.not_to change(ScheduleSlot, :count)
    end
  end
end 