# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::TemplateRenderer do
  let(:renderer) { described_class.new }

  describe '#prepare_notification_data' do
    let(:recipient) { instance_double(User) }
    let(:notification_type) { instance_double(NotificationType, name: 'test_notification', template: nil) }

    it 'returns default data when no template' do
      data = renderer.prepare_notification_data(recipient, notification_type, {
        title: 'Test Title',
        message: 'Test Message',
        priority: 'high'
      })

      expect(data[:title]).to eq('Test Title')
      expect(data[:message]).to eq('Test Message')
      expect(data[:priority]).to eq('high')
    end

    it 'uses humanized name as default title' do
      data = renderer.prepare_notification_data(recipient, notification_type, {})

      expect(data[:title]).to eq('Test notification')
    end

    context 'with template' do
      let(:notification_type) do
        instance_double(
          NotificationType,
          name: 'test',
          template: 'Hello {{name}}! Your order {{order_id}} is ready.'
        )
      end

      it 'fills template with data' do
        data = renderer.prepare_notification_data(recipient, notification_type, {
          template_data: { name: 'John', order_id: '123' }
        })

        expect(data[:message]).to eq('Hello John! Your order 123 is ready.')
      end
    end
  end

  describe '#fill_template' do
    it 'replaces placeholders with values' do
      template = 'Hello {{name}}, your booking #{{id}} is confirmed.'
      result = renderer.fill_template(template, { name: 'John', id: 123 })

      expect(result).to eq('Hello John, your booking #123 is confirmed.')
    end

    it 'handles missing placeholders gracefully' do
      template = 'Hello {{name}}, {{missing}} placeholder'
      result = renderer.fill_template(template, { name: 'John' })

      expect(result).to eq('Hello John, {{missing}} placeholder')
    end

    it 'converts non-string values to strings' do
      template = 'Count: {{count}}, Active: {{active}}'
      result = renderer.fill_template(template, { count: 42, active: true })

      expect(result).to eq('Count: 42, Active: true')
    end
  end

  describe '#build_booking_variables' do
    let(:city) { instance_double(City, name: 'Київ') }
    let(:service_category) { instance_double(ServiceCategory, name: 'Шиномонтаж') }
    let(:service_point) do
      instance_double(
        ServicePoint,
        name: 'СТО Центр',
        address: 'вул. Центральна, 1',
        city: city
      )
    end
    let(:client) do
      instance_double(
        Client,
        email: 'client@example.com',
        phone: '+380501234567',
        first_name: 'Іван',
        last_name: 'Петренко'
      )
    end
    let(:booking) do
      instance_double(
        Booking,
        id: 123,
        service_recipient_first_name: 'Іван',
        service_recipient_last_name: 'Петренко',
        service_recipient_email: 'ivan@example.com',
        service_recipient_phone: '+380501234567',
        booking_date: Date.new(2024, 1, 15),
        start_time: Time.zone.parse('2024-01-15 10:00'),
        status: 'confirmed',
        service_point: service_point,
        service_category: service_category,
        service_category_id: 1,
        client: client,
        car_brand: 'Toyota',
        car_model: 'Camry',
        license_plate: 'AA1234BB'
      )
    end

    before do
      allow(service_point).to receive(:contact_phone_for_category).and_return('+380441234567')
    end

    it 'includes system variables' do
      variables = renderer.build_booking_variables(booking)

      expect(variables['company_name']).to eq('Tire Service Master')
      expect(variables['current_date']).to be_present
    end

    it 'includes client variables' do
      variables = renderer.build_booking_variables(booking)

      expect(variables['client_name']).to eq('Іван Петренко')
      expect(variables['client_email']).to eq('ivan@example.com')
      expect(variables['client_phone']).to eq('+380501234567')
    end

    it 'includes booking variables' do
      variables = renderer.build_booking_variables(booking)

      expect(variables['booking_id']).to eq('#123')
      expect(variables['booking_date']).to eq('15.01.2024')
      expect(variables['booking_time']).to eq('10:00')
    end

    it 'includes service point variables' do
      variables = renderer.build_booking_variables(booking)

      expect(variables['service_point_name']).to eq('СТО Центр')
      expect(variables['service_point_address']).to eq('вул. Центральна, 1')
      expect(variables['service_point_city']).to eq('Київ')
    end

    it 'includes service variables' do
      variables = renderer.build_booking_variables(booking)

      expect(variables['service_name']).to eq('Шиномонтаж')
    end

    it 'includes car variables' do
      variables = renderer.build_booking_variables(booking)

      expect(variables['car_brand']).to eq('Toyota')
      expect(variables['car_model']).to eq('Camry')
      expect(variables['license_plate']).to eq('AA1234BB')
    end
  end

  describe '#build_operator_variables' do
    let(:user) do
      instance_double(
        User,
        full_name: 'Оператор Тест',
        first_name: 'Оператор',
        email: 'operator@example.com',
        phone: '+380501234567'
      )
    end
    let(:operator) { instance_double(Operator, user: user) }
    let(:partner) { instance_double(Partner, name: 'Партнер СТО') }
    let(:service_point) do
      instance_double(
        ServicePoint,
        name: 'СТО Центр',
        address: 'вул. Центральна, 1',
        phone: '+380441234567',
        partner: partner
      )
    end

    it 'builds variables for assignment' do
      variables = renderer.build_operator_variables(operator, service_point, 'assigned')

      expect(variables[:operator_name]).to eq('Оператор Тест')
      expect(variables[:service_point_name]).to eq('СТО Центр')
      expect(variables[:action_type]).to eq('assigned')
      expect(variables[:login_url]).to include('/admin/dashboard')
    end
  end

  describe '#build_telegram_assignment_message' do
    let(:user) { instance_double(User, first_name: 'Оператор') }
    let(:operator) { instance_double(Operator, user: user) }
    let(:partner) { instance_double(Partner, name: 'Партнер') }
    let(:service_point) do
      instance_double(
        ServicePoint,
        name: 'СТО Центр',
        address: 'вул. Центральна, 1',
        phone: '+380441234567',
        partner: partner
      )
    end

    it 'builds assigned message' do
      message = renderer.build_telegram_assignment_message(operator, service_point, 'assigned')

      expect(message).to include('Новое назначение')
      expect(message).to include('СТО Центр')
      expect(message).to include('Оператор')
    end

    it 'builds unassigned message' do
      message = renderer.build_telegram_assignment_message(operator, service_point, 'unassigned')

      expect(message).to include('Отзыв назначения')
      expect(message).to include('СТО Центр')
    end
  end
end
