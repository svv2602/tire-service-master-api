# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::Service do
  let(:token) { 'test_bot_token_123' }
  let(:chat_id) { 123_456_789 }
  let(:api_client) { instance_double(Telegram::APIClient) }
  let(:formatter) { instance_double(Telegram::MessageFormatter) }
  let(:booking_flow) { instance_double(Telegram::BookingFlow) }
  let(:command_handler) { instance_double(Telegram::CommandHandler) }
  let(:service) do
    described_class.new(
      api_client: api_client,
      formatter: formatter,
      booking_flow: booking_flow,
      command_handler: command_handler
    )
  end

  before do
    allow(TelegramSetting).to receive(:current).and_return(
      double(effective_bot_token: token)
    )
  end

  describe '#initialize' do
    it 'creates with default dependencies' do
      allow(Telegram::APIClient).to receive(:new).and_return(api_client)
      allow(Telegram::MessageFormatter).to receive(:new).and_return(formatter)
      allow(Telegram::BookingFlow).to receive(:new).and_return(booking_flow)
      allow(Telegram::CommandHandler).to receive(:new).and_return(command_handler)

      service = described_class.new

      expect(service.api_client).to eq(api_client)
      expect(service.formatter).to eq(formatter)
    end

    it 'accepts custom dependencies' do
      expect(service.api_client).to eq(api_client)
      expect(service.formatter).to eq(formatter)
      expect(service.booking_flow).to eq(booking_flow)
      expect(service.command_handler).to eq(command_handler)
    end
  end

  describe 'API delegation' do
    describe '#send_message' do
      it 'delegates to api_client' do
        expect(api_client).to receive(:send_message).with(chat_id, 'Hello', keyboard: nil, parse_mode: 'HTML')

        service.send_message(chat_id, 'Hello')
      end
    end

    describe '#edit_message' do
      it 'delegates to api_client' do
        expect(api_client).to receive(:edit_message).with(chat_id, 100, 'Updated', keyboard: nil, parse_mode: 'HTML')

        service.edit_message(chat_id, 100, 'Updated')
      end
    end

    describe '#answer_callback_query' do
      it 'delegates to api_client' do
        expect(api_client).to receive(:answer_callback_query).with('callback_123', text: nil, show_alert: false)

        service.answer_callback_query('callback_123')
      end
    end

    describe '#get_me' do
      it 'delegates to api_client' do
        expect(api_client).to receive(:get_me)

        service.get_me
      end
    end

    describe '#set_webhook' do
      it 'delegates to api_client' do
        expect(api_client).to receive(:set_webhook).with('https://example.com/webhook')

        service.set_webhook('https://example.com/webhook')
      end
    end

    describe '#delete_webhook' do
      it 'delegates to api_client' do
        expect(api_client).to receive(:delete_webhook)

        service.delete_webhook
      end
    end
  end

  describe 'Command delegation' do
    describe '#handle_command' do
      it 'delegates to command_handler' do
        expect(command_handler).to receive(:handle_command).with(chat_id, '/start', {})

        service.handle_command(chat_id, '/start')
      end
    end

    describe '#handle_callback_query' do
      it 'delegates to command_handler' do
        expect(command_handler).to receive(:handle_callback_query).with(chat_id, 'settings', 100, {})

        service.handle_callback_query(chat_id, 'settings', 100)
      end
    end

    describe '#handle_booking_command' do
      it 'delegates to booking_flow' do
        expect(booking_flow).to receive(:start_booking).with(chat_id)

        service.handle_booking_command(chat_id)
      end
    end
  end

  describe '#send_notification' do
    let(:user) do
      instance_double(
        User,
        id: 1,
        telegram_subscription: subscription
      )
    end
    let(:subscription) do
      instance_double(
        TelegramSubscription,
        chat_id: chat_id,
        can_receive_notifications?: true
      )
    end
    let(:notification) do
      instance_double(TelegramNotification)
    end

    before do
      allow(TelegramNotification).to receive(:create!).and_return(notification)
    end

    context 'when subscription can receive notifications' do
      before do
        allow(api_client).to receive(:send_message).and_return({
          ok: true,
          result: { message_id: 100 }
        })
        allow(notification).to receive(:mark_as_sent!)
        allow(subscription).to receive(:update_last_interaction!)
      end

      it 'creates notification record' do
        expect(TelegramNotification).to receive(:create!).with(
          hash_including(user: user, chat_id: chat_id)
        )

        service.send_notification(user, 'Test message')
      end

      it 'sends message via api_client' do
        expect(api_client).to receive(:send_message).with(chat_id, 'Test message', keyboard: nil)

        service.send_notification(user, 'Test message')
      end

      it 'marks notification as sent on success' do
        expect(notification).to receive(:mark_as_sent!)

        service.send_notification(user, 'Test message')
      end

      it 'returns true on success' do
        result = service.send_notification(user, 'Test message')

        expect(result).to be true
      end
    end

    context 'when subscription cannot receive notifications' do
      let(:subscription) do
        instance_double(
          TelegramSubscription,
          can_receive_notifications?: false
        )
      end

      it 'returns false' do
        result = service.send_notification(user, 'Test message')

        expect(result).to be false
      end
    end

    context 'when API call fails' do
      before do
        allow(api_client).to receive(:send_message).and_return({
          ok: false,
          description: 'Chat not found'
        })
        allow(notification).to receive(:mark_as_failed!)
      end

      it 'marks notification as failed' do
        expect(notification).to receive(:mark_as_failed!).with('Chat not found')

        service.send_notification(user, 'Test message')
      end

      it 'returns false' do
        result = service.send_notification(user, 'Test message')

        expect(result).to be false
      end
    end
  end

  describe '#send_bulk_notification' do
    let(:user1) { instance_double(User, id: 1, telegram_subscription: subscription1) }
    let(:user2) { instance_double(User, id: 2, telegram_subscription: subscription2) }
    let(:subscription1) { instance_double(TelegramSubscription, chat_id: 111, can_receive_notifications?: true) }
    let(:subscription2) { instance_double(TelegramSubscription, chat_id: 222, can_receive_notifications?: true) }
    let(:users) { [user1, user2] }

    before do
      allow(TelegramNotification).to receive(:create!).and_return(instance_double(TelegramNotification, mark_as_sent!: true))
      allow(api_client).to receive(:send_message).and_return({ ok: true, result: { message_id: 100 } })
      allow(subscription1).to receive(:update_last_interaction!)
      allow(subscription2).to receive(:update_last_interaction!)
    end

    it 'sends notifications to all users' do
      expect(api_client).to receive(:send_message).twice

      service.send_bulk_notification(users, 'Bulk message')
    end

    it 'returns results summary' do
      results = service.send_bulk_notification(users, 'Bulk message')

      expect(results[:total]).to eq(2)
      expect(results[:sent]).to eq(2)
      expect(results[:failed]).to eq(0)
    end
  end

  describe '#retry_failed_notifications' do
    let(:failed_notifications) { [] }

    before do
      failed_relation = double('ActiveRecord::Relation')
      allow(TelegramNotification).to receive(:failed).and_return(failed_relation)
      allow(failed_relation).to receive(:where).and_return(failed_notifications)
    end

    it 'attempts to retry failed notifications' do
      expect(service.retry_failed_notifications).to eq(0)
    end
  end

  describe '#format_booking_notification' do
    let(:booking) { instance_double(Booking) }

    it 'delegates to formatter' do
      expect(formatter).to receive(:format_booking_notification).with(booking, 'booking_confirmation', 'uk')

      service.format_booking_notification(booking, 'booking_confirmation', 'uk')
    end
  end
end
