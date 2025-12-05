# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::MessageFormatter do
  let(:formatter) { described_class.new }

  describe '#build_cities_keyboard' do
    let(:cities) do
      [
        double(id: 1, name: 'Київ'),
        double(id: 2, name: 'Львів')
      ]
    end

    it 'builds inline keyboard with cities' do
      keyboard = formatter.build_cities_keyboard(cities)

      expect(keyboard[:inline_keyboard]).to eq([
        [{ text: 'Київ', callback_data: 'booking_city_1' }],
        [{ text: 'Львів', callback_data: 'booking_city_2' }]
      ])
    end
  end

  describe '#build_service_categories_keyboard' do
    let(:categories) do
      [
        double(id: 1, name: 'Шиномонтаж'),
        double(id: 2, name: 'Балансування')
      ]
    end

    it 'builds inline keyboard with service categories' do
      keyboard = formatter.build_service_categories_keyboard(categories)

      expect(keyboard[:inline_keyboard]).to eq([
        [{ text: 'Шиномонтаж', callback_data: 'booking_service_1' }],
        [{ text: 'Балансування', callback_data: 'booking_service_2' }]
      ])
    end
  end

  describe '#build_service_points_keyboard' do
    let(:service_points) do
      [
        double(id: 1, name: 'СТО Центр', address: 'ул. Центральная, 1'),
        double(id: 2, name: 'СТО Север', address: nil)
      ]
    end

    it 'builds keyboard with address when present' do
      keyboard = formatter.build_service_points_keyboard(service_points)

      expect(keyboard[:inline_keyboard][0][0][:text]).to eq('СТО Центр (ул. Центральная, 1)')
      expect(keyboard[:inline_keyboard][1][0][:text]).to eq('СТО Север')
    end
  end

  describe '#build_calendar_keyboard' do
    it 'builds calendar starting from tomorrow' do
      keyboard = formatter.build_calendar_keyboard

      expect(keyboard[:inline_keyboard]).to be_an(Array)
      expect(keyboard[:inline_keyboard].length).to be <= 14
    end

    it 'excludes Sundays' do
      keyboard = formatter.build_calendar_keyboard(days_count: 30)

      keyboard[:inline_keyboard].each do |row|
        callback_data = row[0][:callback_data]
        date_str = callback_data.gsub('booking_date_', '')
        date = Date.parse(date_str)

        expect(date).not_to be_sunday
      end
    end

    it 'uses correct callback_data format' do
      keyboard = formatter.build_calendar_keyboard

      first_button = keyboard[:inline_keyboard].first.first
      expect(first_button[:callback_data]).to match(/^booking_date_\d{4}-\d{2}-\d{2}$/)
    end
  end

  describe '#build_time_slots_keyboard' do
    let(:time_slots) { ['09:00', '10:00', '11:00'] }

    it 'builds keyboard with time slots' do
      keyboard = formatter.build_time_slots_keyboard(time_slots)

      expect(keyboard[:inline_keyboard]).to eq([
        [{ text: '09:00', callback_data: 'booking_time_09:00' }],
        [{ text: '10:00', callback_data: 'booking_time_10:00' }],
        [{ text: '11:00', callback_data: 'booking_time_11:00' }]
      ])
    end
  end

  describe '#build_car_types_keyboard' do
    let(:car_types) do
      [
        double(id: 1, name: 'Легковий'),
        double(id: 2, name: 'Позашляховик')
      ]
    end

    it 'builds keyboard with car types' do
      keyboard = formatter.build_car_types_keyboard(car_types)

      expect(keyboard[:inline_keyboard]).to eq([
        [{ text: 'Легковий', callback_data: 'booking_car_type_1' }],
        [{ text: 'Позашляховик', callback_data: 'booking_car_type_2' }]
      ])
    end
  end

  describe '#build_phone_request_keyboard' do
    it 'builds reply keyboard with contact request' do
      keyboard = formatter.build_phone_request_keyboard

      expect(keyboard[:keyboard][0][0]).to include(
        text: '📞 Отправить контакт',
        request_contact: true
      )
      expect(keyboard[:resize_keyboard]).to be true
      expect(keyboard[:one_time_keyboard]).to be true
    end
  end

  describe '#build_confirmation_keyboard' do
    it 'builds inline keyboard with confirm/cancel buttons' do
      keyboard = formatter.build_confirmation_keyboard

      expect(keyboard[:inline_keyboard][0]).to eq([
        { text: '✅ Подтвердить', callback_data: 'booking_confirm' },
        { text: '❌ Отменить', callback_data: 'booking_cancel' }
      ])
    end
  end

  describe '#build_main_menu_keyboard' do
    it 'builds main menu with booking and settings buttons' do
      keyboard = formatter.build_main_menu_keyboard

      buttons = keyboard[:inline_keyboard].flatten
      callback_data_values = buttons.map { |b| b[:callback_data] }.compact

      expect(callback_data_values).to include('start_booking', 'settings')
    end
  end

  describe '#build_settings_keyboard' do
    it 'builds settings keyboard with notification toggles' do
      keyboard = formatter.build_settings_keyboard

      callback_data_values = keyboard[:inline_keyboard].flatten.map { |b| b[:callback_data] }

      expect(callback_data_values).to include('toggle_booking', 'toggle_promotion', 'toggle_reminder', 'change_language')
    end
  end

  describe '#remove_keyboard' do
    it 'returns remove_keyboard instruction' do
      expect(formatter.remove_keyboard).to eq({ remove_keyboard: true })
    end
  end

  describe '#format_booking_notification' do
    let(:booking) do
      double(
        id: 123,
        services: [double(name: 'Шиномонтаж')],
        service_point: double(name: 'СТО Центр', address: 'ул. Центральная', city: double(name: 'Київ')),
        service_category: nil,
        start_time: Time.zone.parse('2024-01-15 10:00'),
        end_time: Time.zone.parse('2024-01-15 11:00'),
        booking_date: Date.parse('2024-01-15'),
        client: double(user: double(phone: '+380501234567')),
        service_recipient_phone: '+380501234567',
        service_recipient_first_name: 'Іван',
        service_recipient_last_name: 'Петренко',
        service_recipient_email: 'test@example.com',
        car_brand: 'Toyota',
        car_model: 'Camry',
        license_plate: 'AA1234BB',
        status: 'confirmed',
        notes: 'Test note'
      )
    end

    before do
      allow(EmailTemplate).to receive(:where).and_return(double(first: nil))
    end

    it 'formats booking confirmation notification' do
      message = formatter.format_booking_notification(booking, 'booking_confirmation', 'uk')

      expect(message).to include('Шиномонтаж')
      expect(message).to include('СТО Центр')
    end

    it 'formats booking cancellation notification' do
      message = formatter.format_booking_notification(booking, 'booking_cancelled', 'uk')

      expect(message).to include('скасовано')
    end

    it 'formats booking reminder notification' do
      message = formatter.format_booking_notification(booking, 'booking_reminder', 'uk')

      expect(message).to include('Нагадування')
    end

    it 'formats service completed notification' do
      message = formatter.format_booking_notification(booking, 'service_completed', 'uk')

      expect(message).to include('виконана')
    end

    it 'formats review request notification' do
      message = formatter.format_booking_notification(booking, 'review_request', 'uk')

      expect(message).to include('Оцініть')
    end

    context 'with template from database' do
      let(:template) do
        double(
          name: 'Test Template',
          render_with_variables: { body: 'Custom message for {{booking_id}}' }
        )
      end

      before do
        allow(EmailTemplate).to receive(:where).and_return(double(first: template))
      end

      it 'uses template from database' do
        message = formatter.format_booking_notification(booking, 'booking_confirmation', 'uk')

        expect(message).to eq('Custom message for {{booking_id}}')
      end
    end
  end
end
