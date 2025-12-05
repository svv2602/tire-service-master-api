# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::BookingFlow do
  let(:chat_id) { 123_456_789 }
  let(:api_client) { instance_double(Telegram::APIClient) }
  let(:formatter) { Telegram::MessageFormatter.new }
  let(:booking_flow) { described_class.new(api_client: api_client, formatter: formatter) }

  before do
    allow(api_client).to receive(:send_message)
  end

  describe '#start_booking' do
    let(:cities) do
      [
        instance_double(City, id: 1, name: 'Київ'),
        instance_double(City, id: 2, name: 'Львів')
      ]
    end

    before do
      # Mock existing session destruction
      existing_session = instance_double(TelegramBookingSession)
      session_relation = double('ActiveRecord::Relation')
      allow(TelegramBookingSession).to receive(:active).and_return(session_relation)
      allow(session_relation).to receive(:find_by).with(chat_id: chat_id).and_return(existing_session)
      allow(existing_session).to receive(:destroy)

      # Mock session creation
      allow(TelegramBookingSession).to receive(:create!).and_return(
        instance_double(TelegramBookingSession, chat_id: chat_id)
      )

      # Mock cities query
      city_relation = double('ActiveRecord::Relation')
      allow(City).to receive(:joins).and_return(city_relation)
      allow(city_relation).to receive(:where).and_return(city_relation)
      allow(city_relation).to receive(:distinct).and_return(city_relation)
      allow(city_relation).to receive(:order).and_return(cities)
    end

    it 'destroys existing session' do
      existing = instance_double(TelegramBookingSession)
      session_relation = double('ActiveRecord::Relation')
      allow(TelegramBookingSession).to receive(:active).and_return(session_relation)
      allow(session_relation).to receive(:find_by).with(chat_id: chat_id).and_return(existing)

      expect(existing).to receive(:destroy)

      booking_flow.start_booking(chat_id)
    end

    it 'creates new session' do
      expect(TelegramBookingSession).to receive(:create!).with(
        hash_including(chat_id: chat_id, current_step: 'city_selection')
      )

      booking_flow.start_booking(chat_id)
    end

    it 'sends city selection message' do
      expect(api_client).to receive(:send_message) do |cid, message, opts|
        expect(cid).to eq(chat_id)
        expect(message).to include('Выберите город')
        expect(opts[:keyboard][:inline_keyboard]).to be_present
      end

      booking_flow.start_booking(chat_id)
    end
  end

  describe '#handle_callback' do
    let(:session) do
      instance_double(
        TelegramBookingSession,
        chat_id: chat_id,
        current_step: 'city_selection',
        booking_data: {}
      )
    end

    describe 'city selection' do
      let(:city) { instance_double(City, id: 1, name: 'Київ') }
      let(:categories) { [instance_double(ServiceCategory, id: 1, name: 'Шиномонтаж')] }

      before do
        allow(session).to receive(:update_step)
        allow(session).to receive(:get_data).with(:city_id).and_return(1)
        allow(City).to receive(:find).with(1).and_return(city)

        # Mock service categories query
        category_relation = double('ActiveRecord::Relation')
        allow(ServiceCategory).to receive(:joins).and_return(category_relation)
        allow(category_relation).to receive(:joins).and_return(category_relation)
        allow(category_relation).to receive(:where).and_return(category_relation)
        allow(category_relation).to receive(:distinct).and_return(category_relation)
        allow(category_relation).to receive(:order).and_return(categories)
      end

      it 'updates session with city_id' do
        expect(session).to receive(:update_step).with('service_selection', { city_id: 1 })

        booking_flow.handle_callback(chat_id, 'booking_city_1', 100, session)
      end

      it 'sends service selection message' do
        expect(api_client).to receive(:send_message) do |cid, message, opts|
          expect(cid).to eq(chat_id)
          expect(message).to include('Выберите тип услуги')
        end

        booking_flow.handle_callback(chat_id, 'booking_city_1', 100, session)
      end
    end

    describe 'booking confirmation' do
      let(:session) do
        instance_double(
          TelegramBookingSession,
          chat_id: chat_id,
          current_step: 'confirmation',
          booking_data: {
            city_id: 1,
            service_category_id: 1,
            service_point_id: 1,
            car_type_id: 1,
            date: '2024-01-15',
            time: '10:00',
            phone: '+380501234567',
            license_plate: 'AA1234BB',
            comment: ''
          }
        )
      end

      before do
        allow(session).to receive(:destroy)
      end

      it 'cancels booking when requested' do
        expect(session).to receive(:destroy)
        expect(api_client).to receive(:send_message) do |cid, message|
          expect(message).to include('отменено')
        end

        booking_flow.handle_callback(chat_id, 'booking_cancel', 100, session)
      end
    end

    describe 'skip comment' do
      let(:city) { instance_double(City, id: 1, name: 'Київ') }
      let(:service_category) { instance_double(ServiceCategory, id: 1, name: 'Шиномонтаж') }
      let(:service_point) { instance_double(ServicePoint, id: 1, name: 'СТО') }
      let(:car_type) { instance_double(CarType, id: 1, name: 'Легковий') }

      let(:session) do
        instance_double(
          TelegramBookingSession,
          chat_id: chat_id,
          current_step: 'comment_input',
          booking_data: {
            city_id: 1,
            service_category_id: 1,
            service_point_id: 1,
            car_type_id: 1,
            date: '2024-01-15',
            time: '10:00',
            phone: '+380501234567',
            license_plate: 'AA1234BB'
          }
        )
      end

      before do
        allow(session).to receive(:update_step)
        allow(City).to receive(:find).with(1).and_return(city)
        allow(ServiceCategory).to receive(:find).with(1).and_return(service_category)
        allow(ServicePoint).to receive(:find).with(1).and_return(service_point)
        allow(CarType).to receive(:find).with(1).and_return(car_type)
      end

      it 'skips comment and shows confirmation' do
        expect(session).to receive(:update_step).with('confirmation', { comment: '' })
        expect(api_client).to receive(:send_message) do |cid, message|
          expect(message).to include('Подтверждение')
        end

        booking_flow.handle_callback(chat_id, 'booking_skip_comment', 100, session)
      end
    end
  end

  describe '#handle_step' do
    describe 'phone_input step' do
      let(:session) do
        instance_double(
          TelegramBookingSession,
          chat_id: chat_id,
          current_step: 'phone_input',
          booking_data: {}
        )
      end

      before do
        allow(session).to receive(:update_step)
      end

      context 'with valid phone' do
        it 'accepts valid Ukrainian phone' do
          expect(session).to receive(:update_step).with('license_plate_input', { phone: '+380501234567' })

          booking_flow.handle_step(chat_id, '+380501234567', session)
        end
      end

      context 'with invalid phone' do
        it 'shows error message' do
          expect(api_client).to receive(:send_message) do |cid, message|
            expect(message).to include('Неверный формат')
          end

          booking_flow.handle_step(chat_id, '12345', session)
        end
      end
    end

    describe 'license_plate_input step' do
      let(:session) do
        instance_double(
          TelegramBookingSession,
          chat_id: chat_id,
          current_step: 'license_plate_input',
          booking_data: {}
        )
      end

      before do
        allow(session).to receive(:update_step)
      end

      it 'accepts license plate and moves to comment' do
        expect(session).to receive(:update_step).with('comment_input', { license_plate: 'AA1234BB' })

        booking_flow.handle_step(chat_id, 'AA1234BB', session)
      end

      it 'rejects empty license plate' do
        expect(api_client).to receive(:send_message) do |cid, message|
          expect(message).to include('введите номер')
        end

        booking_flow.handle_step(chat_id, '   ', session)
      end
    end

    describe 'comment_input step' do
      let(:city) { instance_double(City, id: 1, name: 'Київ') }
      let(:service_category) { instance_double(ServiceCategory, id: 1, name: 'Шиномонтаж') }
      let(:service_point) { instance_double(ServicePoint, id: 1, name: 'СТО') }
      let(:car_type) { instance_double(CarType, id: 1, name: 'Легковий') }

      let(:session) do
        instance_double(
          TelegramBookingSession,
          chat_id: chat_id,
          current_step: 'comment_input',
          booking_data: {
            city_id: 1,
            service_category_id: 1,
            service_point_id: 1,
            car_type_id: 1,
            date: '2024-01-15',
            time: '10:00',
            phone: '+380501234567',
            license_plate: 'AA1234BB'
          }
        )
      end

      before do
        allow(session).to receive(:update_step)
        allow(City).to receive(:find).with(1).and_return(city)
        allow(ServiceCategory).to receive(:find).with(1).and_return(service_category)
        allow(ServicePoint).to receive(:find).with(1).and_return(service_point)
        allow(CarType).to receive(:find).with(1).and_return(car_type)
      end

      it 'saves comment and shows confirmation' do
        expect(session).to receive(:update_step).with('confirmation', { comment: 'My comment' })
        expect(api_client).to receive(:send_message) do |cid, message|
          expect(message).to include('Подтверждение')
        end

        booking_flow.handle_step(chat_id, 'My comment', session)
      end
    end
  end
end
