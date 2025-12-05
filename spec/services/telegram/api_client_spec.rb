# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::APIClient do
  let(:token) { 'test_bot_token_123' }
  let(:chat_id) { 123_456_789 }
  let(:client) { described_class.new(token) }

  before do
    allow(TelegramSetting).to receive(:current).and_return(
      double(effective_bot_token: token)
    )
  end

  describe '#initialize' do
    context 'with valid token' do
      it 'initializes successfully' do
        expect { described_class.new(token) }.not_to raise_error
      end
    end

    context 'without token' do
      it 'raises TokenMissingError' do
        allow(TelegramSetting).to receive(:current).and_return(
          double(effective_bot_token: nil)
        )

        expect { described_class.new(nil) }.to raise_error(Telegram::APIClient::TokenMissingError)
      end
    end
  end

  describe '#send_message' do
    let(:message) { 'Test message' }
    let(:success_response) do
      {
        'ok' => true,
        'result' => { 'message_id' => 100 }
      }
    end

    before do
      stub_request(:post, "https://api.telegram.org/bot#{token}/sendMessage")
        .to_return(status: 200, body: success_response.to_json)
    end

    it 'sends message to chat' do
      result = client.send_message(chat_id, message)

      expect(result[:ok]).to be true
      expect(result[:result][:message_id]).to eq 100
    end

    it 'includes parse_mode by default' do
      client.send_message(chat_id, message)

      expect(WebMock).to have_requested(:post, "https://api.telegram.org/bot#{token}/sendMessage")
        .with(body: hash_including(parse_mode: 'HTML'))
    end

    context 'with keyboard' do
      let(:keyboard) { { inline_keyboard: [[{ text: 'Button', callback_data: 'test' }]] } }

      it 'includes keyboard in request' do
        client.send_message(chat_id, message, keyboard: keyboard)

        expect(WebMock).to have_requested(:post, "https://api.telegram.org/bot#{token}/sendMessage")
          .with(body: hash_including(reply_markup: keyboard.to_json))
      end
    end
  end

  describe '#edit_message' do
    let(:message_id) { 100 }
    let(:text) { 'Updated text' }
    let(:success_response) do
      { 'ok' => true, 'result' => { 'message_id' => message_id } }
    end

    before do
      stub_request(:post, "https://api.telegram.org/bot#{token}/editMessageText")
        .to_return(status: 200, body: success_response.to_json)
    end

    it 'edits existing message' do
      result = client.edit_message(chat_id, message_id, text)

      expect(result[:ok]).to be true
    end

    context 'when edit fails' do
      before do
        stub_request(:post, "https://api.telegram.org/bot#{token}/editMessageText")
          .to_return(status: 400, body: { 'ok' => false, 'description' => 'Message not modified' }.to_json)
        stub_request(:post, "https://api.telegram.org/bot#{token}/sendMessage")
          .to_return(status: 200, body: success_response.to_json)
      end

      it 'falls back to sending new message' do
        client.edit_message(chat_id, message_id, text)

        expect(WebMock).to have_requested(:post, "https://api.telegram.org/bot#{token}/sendMessage")
      end
    end
  end

  describe '#answer_callback_query' do
    let(:callback_query_id) { 'callback_123' }
    let(:success_response) { { 'ok' => true } }

    before do
      stub_request(:post, "https://api.telegram.org/bot#{token}/answerCallbackQuery")
        .to_return(status: 200, body: success_response.to_json)
    end

    it 'answers callback query' do
      result = client.answer_callback_query(callback_query_id)

      expect(result[:ok]).to be true
    end

    it 'can include text' do
      client.answer_callback_query(callback_query_id, text: 'Done!')

      expect(WebMock).to have_requested(:post, "https://api.telegram.org/bot#{token}/answerCallbackQuery")
        .with(body: hash_including(text: 'Done!'))
    end
  end

  describe '#get_me' do
    let(:bot_info) do
      {
        'ok' => true,
        'result' => { 'id' => 123, 'is_bot' => true, 'username' => 'test_bot' }
      }
    end

    before do
      stub_request(:get, "https://api.telegram.org/bot#{token}/getMe")
        .to_return(status: 200, body: bot_info.to_json)
    end

    it 'returns bot info' do
      result = client.get_me

      expect(result[:ok]).to be true
      expect(result[:result][:username]).to eq 'test_bot'
    end
  end

  describe '#set_webhook' do
    let(:webhook_url) { 'https://example.com/webhook' }
    let(:success_response) { { 'ok' => true, 'description' => 'Webhook set' } }

    before do
      stub_request(:post, "https://api.telegram.org/bot#{token}/setWebhook")
        .to_return(status: 200, body: success_response.to_json)
    end

    it 'sets webhook URL' do
      result = client.set_webhook(webhook_url)

      expect(result[:ok]).to be true
      expect(WebMock).to have_requested(:post, "https://api.telegram.org/bot#{token}/setWebhook")
        .with(body: hash_including(url: webhook_url))
    end
  end

  describe '#delete_webhook' do
    let(:success_response) { { 'ok' => true } }

    before do
      stub_request(:post, "https://api.telegram.org/bot#{token}/deleteWebhook")
        .to_return(status: 200, body: success_response.to_json)
    end

    it 'deletes webhook' do
      result = client.delete_webhook

      expect(result[:ok]).to be true
    end
  end
end
