# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicAvailabilityService, type: :service do
  let!(:partner) { create(:partner) }
  let!(:service_category) { create(:service_category) }
  let!(:service_point) do
    create(:service_point,
           partner: partner,
           working_hours: {
             'monday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'tuesday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'wednesday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'thursday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'friday' => { 'is_working_day' => true, 'start' => '09:00', 'end' => '18:00' },
             'saturday' => { 'is_working_day' => true, 'start' => '10:00', 'end' => '16:00' },
             'sunday' => { 'is_working_day' => false, 'start' => '00:00', 'end' => '00:00' }
           })
  end
  let!(:service_posts) do
    3.times.map do |i|
      create(:service_post,
             service_point: service_point,
             service_category: service_category,
             post_number: i + 1,
             slot_duration: 60,
             is_active: true,
             has_custom_schedule: false)
    end
  end

  # Динамически определяем понедельник - рабочий день
  let(:test_date) do
    # Находим ближайший понедельник
    date = Date.current
    date += 1 until date.wday == 1 # 1 = Monday
    date
  end

  # Воскресенье - нерабочий день
  let(:sunday_date) do
    date = Date.current
    date += 1 until date.wday == 0 # 0 = Sunday
    date
  end

  describe '.all_slots_for_date' do
    context 'рабочий день без бронирований' do
      it 'возвращает все слоты для дня' do
        slots = described_class.all_slots_for_date(service_point.id, test_date)

        expect(slots).not_to be_empty
        expect(slots.first).to include(
          :service_post_id,
          :post_number,
          :start_time,
          :end_time,
          :available
        )
      end

      it 'слоты имеют корректную длительность' do
        slots = described_class.all_slots_for_date(service_point.id, test_date)
        # Проверяем слоты от основных постов (60 мин) - исключаем посты с другой длительностью
        standard_slots = slots.select { |s| service_posts.map(&:id).include?(s[:service_post_id]) }

        standard_slots.each do |slot|
          expect(slot[:duration_minutes]).to eq(60)
        end
      end

      it 'слоты покрывают весь рабочий день' do
        slots = described_class.all_slots_for_date(service_point.id, test_date)

        expect(slots.first[:start_time]).to eq('09:00')
        expect(slots.last[:end_time]).to eq('18:00')
      end

      it 'возвращает слоты для всех 3 постов в каждый временной интервал' do
        slots = described_class.all_slots_for_date(service_point.id, test_date)
        slots_at_9am = slots.select { |s| s[:start_time] == '09:00' }

        expect(slots_at_9am.length).to eq(3)
        expect(slots_at_9am.map { |s| s[:post_number] }).to contain_exactly(1, 2, 3)
      end
    end

    context 'нерабочий день' do
      it 'возвращает пустой массив' do
        slots = described_class.all_slots_for_date(service_point.id, sunday_date)

        expect(slots).to eq([])
      end
    end

    context 'с бронированиями' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'помечает занятые слоты как недоступные' do
        slots = described_class.all_slots_for_date(service_point.id, test_date)
        slots_at_10am = slots.select { |s| s[:start_time] == '10:00' }
        unavailable_slot = slots_at_10am.find { |s| !s[:available] }

        expect(unavailable_slot).not_to be_nil
        expect(unavailable_slot[:bookings_count]).to eq(1)
      end

      it 'помечает свободные слоты как доступные' do
        slots = described_class.all_slots_for_date(service_point.id, test_date)
        free_slot = slots.find { |s| s[:start_time] == '11:00' && s[:available] }

        expect(free_slot).not_to be_nil
      end
    end
  end

  describe '.available_slots_for_date' do
    it 'возвращает только доступные слоты' do
      slots = described_class.available_slots_for_date(service_point.id, test_date)

      slots.each do |slot|
        expect(slot[:available]).to be true
      end
    end

    context 'с бронированием' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'уменьшает количество доступных слотов для забронированного времени' do
        slots = described_class.available_slots_for_date(service_point.id, test_date)
        slots_at_10am = slots.select { |s| s[:start_time] == '10:00' }

        # Было 3 поста, 1 занят = 2 доступных
        expect(slots_at_10am.length).to eq(2)
      end
    end
  end

  describe '.available_times_for_date' do
    it 'возвращает агрегированные временные слоты' do
      times = described_class.available_times_for_date(service_point.id, test_date)

      expect(times).not_to be_empty
      expect(times.first).to include(:time, :available_posts, :total_posts)
    end

    it 'показывает правильное количество доступных постов' do
      times = described_class.available_times_for_date(service_point.id, test_date)

      times.each do |time_slot|
        expect(time_slot[:available_posts]).to eq(3)
        expect(time_slot[:total_posts]).to eq(3)
      end
    end

    context 'с минимальной длительностью' do
      it 'фильтрует слоты по минимальной длительности' do
        times = described_class.available_times_for_date(service_point.id, test_date, 30)

        expect(times).not_to be_empty
      end

      it 'возвращает пустой массив если длительность слишком большая' do
        # Слоты по 60 минут, запрашиваем 120 минут
        times = described_class.available_times_for_date(service_point.id, test_date, 120)

        expect(times).to be_empty
      end
    end

    context 'нерабочий день' do
      it 'возвращает пустой массив' do
        times = described_class.available_times_for_date(service_point.id, sunday_date)

        expect(times).to eq([])
      end
    end
  end

  describe '.check_availability_at_time' do
    context 'когда слот свободен' do
      it 'возвращает available: true' do
        result = described_class.check_availability_at_time(
          service_point.id,
          test_date,
          '10:00'
        )

        expect(result[:available]).to be true
        expect(result[:available_posts]).to be >= 1
      end
    end

    context 'когда все посты заняты' do
      before do
        3.times do
          create(:booking,
                 service_point: service_point,
                 booking_date: test_date,
                 start_time: '10:00',
                 end_time: '11:00')
        end
      end

      it 'возвращает available: false когда все посты заняты' do
        result = described_class.check_availability_at_time(
          service_point.id,
          test_date,
          '10:00'
        )

        expect(result[:available]).to be false
      end
    end

    context 'проверка вне рабочих часов' do
      it 'возвращает недоступность для времени до открытия' do
        result = described_class.check_availability_at_time(
          service_point.id,
          test_date,
          '07:00'
        )

        expect(result[:available]).to be false
        expect(result[:reason]).to include('рабочих')
      end

      it 'возвращает недоступность для времени после закрытия' do
        result = described_class.check_availability_at_time(
          service_point.id,
          test_date,
          '19:00'
        )

        expect(result[:available]).to be false
      end
    end

    context 'нерабочий день' do
      it 'возвращает недоступность' do
        result = described_class.check_availability_at_time(
          service_point.id,
          sunday_date,
          '10:00'
        )

        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Не рабочий день')
      end
    end

    context 'с исключением бронирования' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'исключает указанное бронирование при проверке' do
        # Сначала создаем еще 2 бронирования чтобы заполнить все посты
        2.times do
          create(:booking,
                 service_point: service_point,
                 booking_date: test_date,
                 start_time: '10:00',
                 end_time: '11:00')
        end

        # Без исключения - недоступно
        result_without_exclude = described_class.check_availability_at_time(
          service_point.id,
          test_date,
          '10:00'
        )
        expect(result_without_exclude[:available]).to be false

        # С исключением одного бронирования - доступно
        result_with_exclude = described_class.check_availability_at_time(
          service_point.id,
          test_date,
          '10:00',
          nil,
          exclude_booking_id: booking.id
        )
        expect(result_with_exclude[:available]).to be true
      end
    end
  end

  describe '.count_bookings_at_time' do
    let(:check_time) { Time.parse("#{test_date} 10:00") }
    let(:check_end_time) { Time.parse("#{test_date} 11:00") }

    context 'когда бронирований нет' do
      it 'возвращает 0' do
        count = described_class.count_bookings_at_time(
          service_point.id,
          test_date,
          check_time,
          check_end_time
        )

        expect(count).to eq(0)
      end
    end

    context 'когда есть бронирование' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'возвращает количество бронирований' do
        count = described_class.count_bookings_at_time(
          service_point.id,
          test_date,
          check_time,
          check_end_time
        )

        expect(count).to eq(1)
      end
    end

    context 'когда есть отмененные бронирования' do
      let!(:cancelled_booking) do
        create(:booking, :canceled_by_client,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'не учитывает отмененные бронирования' do
        count = described_class.count_bookings_at_time(
          service_point.id,
          test_date,
          check_time,
          check_end_time
        )

        expect(count).to eq(0)
      end
    end
  end

  describe '.find_next_available_time' do
    context 'когда есть доступное время' do
      it 'возвращает ближайший доступный слот' do
        after_time = Time.parse("#{test_date} 08:00")

        result = described_class.find_next_available_time(
          service_point.id,
          test_date,
          after_time
        )

        expect(result).not_to be_nil
        expect(result[:time]).to eq('09:00')
      end
    end

    context 'когда запрашиваем после определенного времени' do
      it 'возвращает слот после указанного времени' do
        after_time = Time.parse("#{test_date} 10:00")

        result = described_class.find_next_available_time(
          service_point.id,
          test_date,
          after_time
        )

        expect(result).not_to be_nil
        expect(Time.parse("#{test_date} #{result[:time]}")).to be >= after_time
      end
    end
  end

  describe '.day_occupancy_details' do
    context 'когда сервисная точка работает' do
      it 'возвращает детальную информацию о загрузке' do
        details = described_class.day_occupancy_details(service_point.id, test_date)

        expect(details[:is_working]).to be true
        expect(details[:opening_time]).to eq('09:00')
        expect(details[:closing_time]).to eq('18:00')
        expect(details).to include(:summary)
        expect(details[:summary]).to include(
          :total_slots,
          :available_slots,
          :occupied_slots,
          :occupancy_percentage
        )
      end

      it 'показывает правильную статистику' do
        details = described_class.day_occupancy_details(service_point.id, test_date)

        expect(details[:summary][:occupancy_percentage]).to eq(0.0)
        expect(details[:summary][:available_slots]).to eq(details[:summary][:total_slots])
      end
    end

    context 'когда сервисная точка не работает' do
      it 'возвращает is_working: false с сообщением' do
        details = described_class.day_occupancy_details(service_point.id, sunday_date)

        expect(details[:is_working]).to be false
        expect(details[:message]).to be_present
      end
    end

    context 'с бронированиями' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'отражает занятость в статистике' do
        details = described_class.day_occupancy_details(service_point.id, test_date)

        expect(details[:summary][:occupied_slots]).to be >= 1
        expect(details[:summary][:occupancy_percentage]).to be > 0
      end
    end
  end

  describe '.get_all_possible_slots_for_date' do
    it 'возвращает все возможные слоты включая занятые' do
      create(:booking,
             service_point: service_point,
             booking_date: test_date,
             start_time: '10:00',
             end_time: '11:00')

      slots = described_class.get_all_possible_slots_for_date(service_point.id, test_date)
      slot_at_10am = slots.find { |s| s[:start_time] == '10:00' }

      expect(slot_at_10am).not_to be_nil
    end

    context 'когда сервисная точка не работает' do
      it 'возвращает пустой массив' do
        slots = described_class.get_all_possible_slots_for_date(service_point.id, sunday_date)

        expect(slots).to eq([])
      end
    end
  end

  describe 'работа с категориями услуг' do
    let!(:category2) { create(:service_category) }
    let!(:category2_post) do
      create(:service_post,
             service_point: service_point,
             service_category: category2,
             post_number: 10,
             slot_duration: 60,
             is_active: true)
    end

    describe '.available_slots_for_category' do
      it 'возвращает слоты только для указанной категории' do
        slots = described_class.available_slots_for_category(
          service_point.id,
          test_date,
          service_category.id
        )

        expect(slots).not_to be_empty
        slots.each do |slot|
          expect(slot[:category_id]).to eq(service_category.id)
        end
      end

      it 'не включает слоты других категорий' do
        slots = described_class.available_slots_for_category(
          service_point.id,
          test_date,
          service_category.id
        )

        slots.each do |slot|
          expect(slot[:category_id]).not_to eq(category2.id)
        end
      end
    end

    describe '.day_occupancy_details_for_category' do
      it 'возвращает статистику для конкретной категории' do
        details = described_class.day_occupancy_details_for_category(
          service_point.id,
          test_date,
          service_category.id
        )

        expect(details[:is_working]).to be true
        expect(details[:category_id]).to eq(service_category.id)
        expect(details[:total_posts]).to eq(3) # 3 поста в первой категории
      end

      context 'когда категория не имеет постов' do
        let!(:empty_category) { create(:service_category) }

        it 'возвращает is_working: false' do
          details = described_class.day_occupancy_details_for_category(
            service_point.id,
            test_date,
            empty_category.id
          )

          expect(details[:is_working]).to be false
        end
      end
    end

    describe '.check_availability_with_category' do
      it 'проверяет доступность только для постов указанной категории' do
        result = described_class.check_availability_with_category(
          service_point.id,
          test_date,
          '10:00',
          60,
          service_category.id
        )

        expect(result[:available]).to be true
        expect(result[:category_id]).to eq(service_category.id)
      end

      context 'когда сервисная точка не найдена' do
        it 'возвращает ошибку' do
          result = described_class.check_availability_with_category(
            999_999,
            test_date,
            '10:00',
            60,
            service_category.id
          )

          expect(result[:available]).to be false
          expect(result[:reason]).to include('не найдена')
        end
      end

      context 'когда нет постов для категории' do
        let(:empty_category) { create(:service_category) }

        it 'возвращает ошибку' do
          result = described_class.check_availability_with_category(
            service_point.id,
            test_date,
            '10:00',
            60,
            empty_category.id
          )

          expect(result[:available]).to be false
          expect(result[:reason]).to include('Нет активных постов')
        end
      end
    end
  end

  describe 'индивидуальное расписание постов' do
    let!(:custom_schedule_post) do
      create(:service_post,
             service_point: service_point,
             service_category: service_category,
             post_number: 20,
             slot_duration: 30,
             is_active: true,
             has_custom_schedule: true,
             working_days: {
               'monday' => true,
               'tuesday' => true,
               'wednesday' => true,
               'thursday' => true,
               'friday' => true,
               'saturday' => false,
               'sunday' => false
             },
             custom_hours: {
               'start' => '08:00',
               'end' => '20:00'
             })
    end

    it 'включает пост с индивидуальным расписанием в слоты' do
      slots = described_class.all_slots_for_date(service_point.id, test_date)
      custom_post_slots = slots.select { |s| s[:service_post_id] == custom_schedule_post.id }

      # Пост с индивидуальным расписанием должен быть включен
      expect(custom_post_slots).not_to be_empty
    end

    it 'пост с индивидуальным расписанием не работает в субботу' do
      saturday = Date.current
      saturday += 1 until saturday.wday == 6 # 6 = Saturday

      slots = described_class.all_slots_for_date(service_point.id, saturday)
      custom_post_slots = slots.select { |s| s[:service_post_id] == custom_schedule_post.id }

      expect(custom_post_slots).to be_empty
    end
  end

  describe '.is_slot_occupied?' do
    let(:check_time) { Time.parse("#{test_date} 10:00") }
    let(:check_end_time) { Time.parse("#{test_date} 11:00") }

    context 'когда слот свободен' do
      it 'возвращает false' do
        result = described_class.is_slot_occupied?(
          service_point.id,
          service_posts.first.id,
          test_date,
          check_time,
          check_end_time
        )

        expect(result).to be false
      end
    end

    context 'когда слот занят' do
      let!(:booking) do
        create(:booking,
               service_point: service_point,
               booking_date: test_date,
               start_time: '10:00',
               end_time: '11:00')
      end

      it 'возвращает true' do
        result = described_class.is_slot_occupied?(
          service_point.id,
          service_posts.first.id,
          test_date,
          check_time,
          check_end_time
        )

        expect(result).to be true
      end
    end
  end

  describe 'приватные методы' do
    describe '.get_schedule_for_date' do
      it 'возвращает рабочие часы для рабочего дня' do
        result = described_class.send(:get_schedule_for_date, service_point, test_date)

        expect(result[:is_working]).to be true
        expect(result[:opening_time].strftime('%H:%M')).to eq('09:00')
        expect(result[:closing_time].strftime('%H:%M')).to eq('18:00')
      end

      it 'возвращает is_working: false для нерабочего дня' do
        result = described_class.send(:get_schedule_for_date, service_point, sunday_date)

        expect(result[:is_working]).to be false
      end
    end

    describe '.has_any_working_posts_on_date?' do
      it 'возвращает true для рабочего дня' do
        result = described_class.send(:has_any_working_posts_on_date?, service_point, test_date)

        expect(result).to be true
      end

      it 'возвращает false для нерабочего дня' do
        result = described_class.send(:has_any_working_posts_on_date?, service_point, sunday_date)

        expect(result).to be false
      end
    end

    describe '.count_occupied_posts_at_time' do
      it 'возвращает 0 без бронирований' do
        check_time = Time.parse("#{test_date} 10:00")
        count = described_class.send(:count_occupied_posts_at_time, service_point.id, test_date, check_time)

        expect(count).to eq(0)
      end

      it 'возвращает количество занятых постов с бронированием' do
        booking = create(:booking,
                         service_point: service_point,
                         booking_date: test_date,
                         start_time: '10:00:00',
                         end_time: '11:00:00')

        check_time = Time.parse("#{test_date} 10:00")
        count = described_class.send(:count_occupied_posts_at_time, service_point.id, test_date, check_time)

        expect(count).to eq(1)
      end

      it 'исключает бронирование по ID' do
        booking = create(:booking,
                         service_point: service_point,
                         booking_date: test_date,
                         start_time: '10:00:00',
                         end_time: '11:00:00')

        check_time = Time.parse("#{test_date} 10:00")
        count = described_class.send(:count_occupied_posts_at_time,
                                     service_point.id,
                                     test_date,
                                     check_time,
                                     exclude_booking_id: booking.id)

        expect(count).to eq(0)
      end
    end
  end

  describe 'константы' do
    it 'определяет MIN_TIME_INTERVAL' do
      expect(DynamicAvailabilityService::MIN_TIME_INTERVAL).to eq(15)
    end
  end
end
