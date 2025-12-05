# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::CommandHandler do
  let(:token) { 'test_bot_token_123' }
  let(:chat_id) { 123_456_789 }
  let(:api_client) { instance_double(Telegram::APIClient) }
  let(:formatter) { Telegram::MessageFormatter.new }
  let(:booking_flow) { instance_double(Telegram::BookingFlow) }
  let(:handler) { described_class.new(api_client: api_client, formatter: formatter, booking_flow: booking_flow) }

  before do
    allow(api_client).to receive(:send_message)
  end

  describe '#handle_command' do
    describe '/start command' do
      it 'sends welcome message with main menu keyboard' do
        expect(api_client).to receive(:send_message) do |cid, message, opts|
          expect(cid).to eq(chat_id)
          expect(message).to include('Вітаємо')
          expect(opts[:keyboard]).to be_present
        end

        handler.handle_command(chat_id, '/start')
      end
    end

    describe '/stop command' do
      context 'with active subscription' do
        let(:subscription) { instance_double(TelegramSubscription) }

        before do
          allow(TelegramSubscription).to receive(:find_by).with(chat_id: chat_id).and_return(subscription)
          allow(subscription).to receive(:deactivate!)
        end

        it 'deactivates subscription and confirms' do
          expect(subscription).to receive(:deactivate!)
          expect(api_client).to receive(:send_message) do |cid, message|
            expect(cid).to eq(chat_id)
            expect(message).to include('відключено')
          end

          handler.handle_command(chat_id, '/stop')
        end
      end

      context 'without subscription' do
        before do
          allow(TelegramSubscription).to receive(:find_by).with(chat_id: chat_id).and_return(nil)
        end

        it 'sends not found message' do
          expect(api_client).to receive(:send_message) do |cid, message|
            expect(cid).to eq(chat_id)
            expect(message).to include('не знайдена')
          end

          handler.handle_command(chat_id, '/stop')
        end
      end
    end

    describe '/help command' do
      it 'sends help message with available commands' do
        expect(api_client).to receive(:send_message) do |cid, message|
          expect(cid).to eq(chat_id)
          expect(message).to include('/start')
          expect(message).to include('/booking')
          expect(message).to include('/stop')
          expect(message).to include('/status')
          expect(message).to include('/settings')
          expect(message).to include('/help')
        end

        handler.handle_command(chat_id, '/help')
      end
    end

    describe '/status command' do
      context 'with subscription' do
        let(:user) { instance_double(User, full_name: 'Test User', email: 'test@example.com') }
        let(:subscription) do
          instance_double(
            TelegramSubscription,
            user: user,
            is_active?: true,
            sent_notifications_count: 5,
            success_rate: 98.5
          )
        end

        before do
          allow(TelegramSubscription).to receive(:find_by).with(chat_id: chat_id).and_return(subscription)
        end

        it 'sends subscription status' do
          expect(api_client).to receive(:send_message) do |cid, message|
            expect(cid).to eq(chat_id)
            expect(message).to include('Test User')
            expect(message).to include('test@example.com')
            expect(message).to include('Активна')
          end

          handler.handle_command(chat_id, '/status')
        end
      end

      context 'without subscription' do
        before do
          allow(TelegramSubscription).to receive(:find_by).with(chat_id: chat_id).and_return(nil)
        end

        it 'sends not found message' do
          expect(api_client).to receive(:send_message) do |cid, message|
            expect(cid).to eq(chat_id)
            expect(message).to include('не знайдена')
          end

          handler.handle_command(chat_id, '/status')
        end
      end
    end

    describe '/settings command' do
      context 'with subscription' do
        let(:subscription) { instance_double(TelegramSubscription) }

        before do
          allow(TelegramSubscription).to receive(:find_by).with(chat_id: chat_id).and_return(subscription)
        end

        it 'sends settings keyboard' do
          expect(api_client).to receive(:send_message) do |cid, message, opts|
            expect(cid).to eq(chat_id)
            expect(message).to include('Настройки')
            expect(opts[:keyboard][:inline_keyboard]).to be_present
          end

          handler.handle_command(chat_id, '/settings')
        end
      end
    end

    describe '/booking command' do
      it 'delegates to booking_flow' do
        expect(booking_flow).to receive(:start_booking).with(chat_id)

        handler.handle_command(chat_id, '/booking')
      end
    end

    describe 'unknown command' do
      context 'with active booking session' do
        let(:session) { instance_double(TelegramBookingSession) }
        let(:session_relation) { double('ActiveRecord::Relation') }

        before do
          allow(TelegramBookingSession).to receive(:active).and_return(session_relation)
          allow(session_relation).to receive(:find_by).with(chat_id: chat_id).and_return(session)
        end

        it 'delegates to booking_flow for text input' do
          expect(booking_flow).to receive(:handle_step).with(chat_id, 'some text', session)

          handler.handle_command(chat_id, 'some text')
        end
      end

      context 'without booking session' do
        let(:session_relation) { double('ActiveRecord::Relation') }

        before do
          allow(TelegramBookingSession).to receive(:active).and_return(session_relation)
          allow(session_relation).to receive(:find_by).with(chat_id: chat_id).and_return(nil)
        end

        it 'sends unknown command message' do
          expect(api_client).to receive(:send_message) do |cid, message|
            expect(cid).to eq(chat_id)
            expect(message).to include('Неизвестная команда')
          end

          handler.handle_command(chat_id, 'random text')
        end
      end
    end
  end

  describe '#handle_callback_query' do
    describe 'booking callbacks' do
      let(:session) { instance_double(TelegramBookingSession) }
      let(:session_relation) { double('ActiveRecord::Relation') }

      before do
        allow(TelegramBookingSession).to receive(:active).and_return(session_relation)
        allow(session_relation).to receive(:find_by).with(chat_id: chat_id).and_return(session)
      end

      it 'delegates booking callbacks to booking_flow' do
        expect(booking_flow).to receive(:handle_callback).with(chat_id, 'booking_city_1', 100, session)

        handler.handle_callback_query(chat_id, 'booking_city_1', 100)
      end
    end

    describe 'settings callbacks' do
      let(:session_relation) { double('ActiveRecord::Relation') }

      before do
        allow(TelegramBookingSession).to receive(:active).and_return(session_relation)
        allow(session_relation).to receive(:find_by).with(chat_id: chat_id).and_return(nil)
      end

      it 'handles settings callback' do
        subscription = instance_double(TelegramSubscription)
        allow(TelegramSubscription).to receive(:find_by).with(chat_id: chat_id).and_return(subscription)

        expect(api_client).to receive(:send_message)

        handler.handle_callback_query(chat_id, 'settings', 100)
      end

      it 'handles start_booking callback' do
        expect(booking_flow).to receive(:start_booking).with(chat_id)

        handler.handle_callback_query(chat_id, 'start_booking', 100)
      end
    end
  end
end
