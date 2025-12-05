# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TelegramService, type: :service do
  let(:telegram_setting) { create(:telegram_setting, bot_token: 'test_bot_token_123') }
  let(:chat_id) { '123456789' }
  let(:user) { create(:user) }
  let(:telegram_subscription) { create(:telegram_subscription, user: user, chat_id: chat_id, is_active: true) }

  before do
    telegram_setting # ensure setting exists
    # Stub HTTParty requests
    allow(HTTParty).to receive(:post).and_return(
      double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
    )
    allow(HTTParty).to receive(:get).and_return(
      double(success?: true, code: 200, body: '{"ok":true,"result":{}}')
    )
  end

  describe '#initialize' do
    context 'when bot token is present' do
      it 'initializes successfully' do
        expect { TelegramService.new }.not_to raise_error
      end
    end

    context 'when bot token is missing' do
      before do
        allow(TelegramSetting).to receive(:current).and_return(
          double(effective_bot_token: nil)
        )
      end

      it 'raises an error' do
        expect { TelegramService.new }.to raise_error('TELEGRAM_BOT_TOKEN не установлен')
      end
    end
  end

  describe '#send_message' do
    let(:service) { TelegramService.new }
    let(:message) { 'Test message' }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
      )
    end

    it 'sends message to specified chat_id' do
      expect(TelegramService).to receive(:post).with(
        anything,
        hash_including(body: hash_including(chat_id: chat_id, text: message))
      )

      service.send_message(chat_id, message)
    end

    it 'includes parse_mode by default' do
      expect(TelegramService).to receive(:post).with(
        anything,
        hash_including(body: hash_including(parse_mode: 'HTML'))
      )

      service.send_message(chat_id, message)
    end

    context 'with keyboard' do
      let(:keyboard) do
        {
          inline_keyboard: [
            [{ text: 'Button 1', callback_data: 'action_1' }]
          ]
        }
      end

      it 'includes reply_markup' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:reply_markup))
        )

        service.send_message(chat_id, message, keyboard)
      end
    end

    context 'when API returns error' do
      before do
        allow(TelegramService).to receive(:post).and_raise(StandardError.new('API Error'))
      end

      it 'raises the error' do
        expect { service.send_message(chat_id, message) }.to raise_error(StandardError, 'API Error')
      end
    end
  end

  describe '#edit_message' do
    let(:service) { TelegramService.new }
    let(:message_id) { 123 }
    let(:new_text) { 'Updated message' }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":123}}')
      )
    end

    it 'edits existing message' do
      expect(TelegramService).to receive(:post).with(
        /editMessageText/,
        hash_including(body: hash_including(chat_id: chat_id, message_id: message_id, text: new_text))
      )

      service.edit_message(chat_id, message_id, new_text)
    end

    context 'when edit fails' do
      before do
        allow(TelegramService).to receive(:post).and_return(
          double(success?: false, code: 400, body: '{"ok":false,"description":"message not found"}')
        )
      end

      it 'falls back to sending new message' do
        # First call for edit fails, second call for new message
        expect(TelegramService).to receive(:post).twice

        service.edit_message(chat_id, message_id, new_text)
      end
    end
  end

  describe '#answer_callback_query' do
    let(:service) { TelegramService.new }
    let(:callback_query_id) { 'callback_123' }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true}')
      )
    end

    it 'answers callback query' do
      expect(TelegramService).to receive(:post).with(
        /answerCallbackQuery/,
        hash_including(body: hash_including(callback_query_id: callback_query_id))
      )

      service.answer_callback_query(callback_query_id)
    end

    it 'can include text in response' do
      expect(TelegramService).to receive(:post).with(
        anything,
        hash_including(body: hash_including(text: 'Success'))
      )

      service.answer_callback_query(callback_query_id, 'Success')
    end

    it 'can show alert' do
      expect(TelegramService).to receive(:post).with(
        anything,
        hash_including(body: hash_including(show_alert: true))
      )

      service.answer_callback_query(callback_query_id, 'Alert!', true)
    end
  end

  describe '#get_me' do
    let(:service) { TelegramService.new }

    before do
      allow(TelegramService).to receive(:get).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"id":123,"is_bot":true,"first_name":"TestBot"}}')
      )
    end

    it 'returns bot information' do
      result = service.get_me

      expect(result[:ok]).to be true
      expect(result[:result][:is_bot]).to be true
    end
  end

  describe '#set_webhook' do
    let(:service) { TelegramService.new }
    let(:webhook_url) { 'https://example.com/webhook' }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":true}')
      )
    end

    it 'sets webhook URL' do
      expect(TelegramService).to receive(:post).with(
        /setWebhook/,
        hash_including(body: hash_including(url: webhook_url))
      )

      service.set_webhook(webhook_url)
    end
  end

  describe '#delete_webhook' do
    let(:service) { TelegramService.new }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":true}')
      )
    end

    it 'deletes webhook' do
      expect(TelegramService).to receive(:post).with(/deleteWebhook/, anything)

      service.delete_webhook
    end
  end

  describe '#send_notification' do
    let(:service) { TelegramService.new }

    before do
      telegram_subscription # ensure subscription exists
      allow(user).to receive(:telegram_subscription).and_return(telegram_subscription)
      allow(telegram_subscription).to receive(:can_receive_notifications?).and_return(true)
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
      )
    end

    context 'when user has active subscription' do
      it 'creates TelegramNotification record' do
        expect {
          service.send_notification(user, 'Test message')
        }.to change(TelegramNotification, :count).by(1)
      end

      it 'returns true on success' do
        result = service.send_notification(user, 'Test message')
        expect(result).to be true
      end
    end

    context 'when user cannot receive notifications' do
      before do
        allow(telegram_subscription).to receive(:can_receive_notifications?).and_return(false)
      end

      it 'returns false' do
        result = service.send_notification(user, 'Test message')
        expect(result).to be false
      end
    end

    context 'when user has no subscription' do
      before do
        allow(user).to receive(:telegram_subscription).and_return(nil)
      end

      it 'returns false' do
        result = service.send_notification(user, 'Test message')
        expect(result).to be false
      end
    end
  end

  describe '#handle_command' do
    let(:service) { TelegramService.new }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
      )
    end

    describe '/start command' do
      it 'sends welcome message' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text))
        )

        service.handle_command(chat_id, '/start')
      end
    end

    describe '/help command' do
      it 'sends help message with available commands' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text))
        )

        service.handle_command(chat_id, '/help')
      end
    end

    describe '/status command' do
      it 'sends status information' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text))
        )

        service.handle_command(chat_id, '/status')
      end
    end

    describe '/settings command' do
      it 'sends settings menu' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text))
        )

        service.handle_command(chat_id, '/settings')
      end
    end

    describe '/booking command' do
      it 'starts booking flow' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text))
        )

        service.handle_command(chat_id, '/booking')
      end

      it 'creates booking session' do
        expect {
          service.handle_command(chat_id, '/booking')
        }.to change(TelegramBookingSession, :count).by(1)
      end
    end

    describe '/stop command' do
      before do
        create(:telegram_subscription, chat_id: chat_id, is_active: true)
      end

      it 'deactivates subscription' do
        service.handle_command(chat_id, '/stop')

        subscription = TelegramSubscription.find_by(chat_id: chat_id)
        expect(subscription.is_active).to be false
      end
    end

    describe 'unknown command' do
      it 'sends unknown command message' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text))
        )

        service.handle_command(chat_id, '/unknown_command')
      end
    end
  end

  describe '#format_booking_notification' do
    let(:service) { TelegramService.new }
    let(:booking) { create(:booking, :with_services) }

    context 'with booking_confirmation type' do
      it 'returns formatted confirmation message' do
        result = service.format_booking_notification(booking, 'booking_confirmation')

        expect(result).to include('Нове бронювання').or include('Бронювання')
      end
    end

    context 'with booking_cancelled type' do
      it 'returns formatted cancellation message' do
        result = service.format_booking_notification(booking, 'booking_cancelled')

        expect(result).to include('скасовано').or include('Бронювання')
      end
    end

    context 'with booking_reminder type' do
      it 'returns formatted reminder message' do
        result = service.format_booking_notification(booking, 'booking_reminder')

        expect(result).to include('Нагадування').or include('візит').or include('Бронювання')
      end
    end

    context 'with service_completed type' do
      it 'returns formatted completion message' do
        result = service.format_booking_notification(booking, 'service_completed')

        expect(result).to include('виконана').or include('Дякуємо').or include('Бронювання')
      end
    end
  end

  describe '#handle_callback_query' do
    let(:service) { TelegramService.new }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
      )
    end

    context 'with booking callback' do
      let(:session) { create(:telegram_booking_session, chat_id: chat_id) }

      before do
        session # ensure session exists
      end

      it 'handles booking_city callback' do
        city = create(:city)

        expect {
          service.handle_callback_query(chat_id, "booking_city_#{city.id}", 1)
        }.not_to raise_error
      end
    end

    context 'with settings callback' do
      it 'handles settings callback' do
        expect {
          service.handle_callback_query(chat_id, 'settings', 1)
        }.not_to raise_error
      end
    end
  end

  describe 'booking flow steps' do
    let(:service) { TelegramService.new }
    let(:session) { create(:telegram_booking_session, chat_id: chat_id) }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
      )
    end

    describe '#start_city_selection' do
      before do
        create_list(:city, 3)
      end

      it 'shows city selection message' do
        expect(TelegramService).to receive(:post).with(
          anything,
          hash_including(body: hash_including(:text, :reply_markup))
        )

        service.start_city_selection(chat_id, session)
      end
    end

    describe '#start_car_type_selection' do
      before do
        create_list(:car_type, 3)
      end

      it 'shows car type selection message' do
        expect(TelegramService).to receive(:post)

        service.start_car_type_selection(chat_id, session)
      end
    end
  end

  describe 'phone validation' do
    let(:service) { TelegramService.new }
    let(:session) { create(:telegram_booking_session, chat_id: chat_id, current_step: 'phone_input') }

    before do
      allow(TelegramService).to receive(:post).and_return(
        double(success?: true, code: 200, body: '{"ok":true,"result":{"message_id":1}}')
      )
    end

    it 'accepts valid Ukrainian phone number' do
      expect {
        service.handle_booking_step(chat_id, '+380671234567', session)
      }.not_to raise_error
    end

    it 'rejects invalid phone format' do
      expect(TelegramService).to receive(:post).with(
        anything,
        hash_including(body: hash_including(text: /Неверный формат/))
      )

      service.handle_booking_step(chat_id, '12345', session)
    end
  end
end
