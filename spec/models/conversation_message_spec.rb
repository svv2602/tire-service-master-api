# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationMessage, type: :model do
  describe 'associations' do
    it { should belong_to(:conversation).touch(true) }
  end

  describe 'validations' do
    it { should validate_presence_of(:role) }
    it { should validate_presence_of(:content) }
    it { should validate_inclusion_of(:role).in_array(%w[user assistant system]) }
  end

  describe 'scopes' do
    let(:conversation) { create(:conversation) }
    let!(:user_message) { create(:conversation_message, conversation: conversation, role: 'user') }
    let!(:assistant_message) { create(:conversation_message, conversation: conversation, role: 'assistant') }
    let!(:system_message) { create(:conversation_message, conversation: conversation, role: 'system') }

    describe '.user_messages' do
      it 'returns only user messages' do
        expect(described_class.user_messages).to include(user_message)
        expect(described_class.user_messages).not_to include(assistant_message)
      end
    end

    describe '.assistant_messages' do
      it 'returns only assistant messages' do
        expect(described_class.assistant_messages).to include(assistant_message)
        expect(described_class.assistant_messages).not_to include(user_message)
      end
    end

    describe '.chronological' do
      it 'returns messages in chronological order' do
        messages = conversation.messages.chronological
        expect(messages.first).to eq(user_message)
      end
    end
  end

  describe '#user?, #assistant?, #system?' do
    it 'returns true for matching role' do
      user_message = build(:conversation_message, role: 'user')
      expect(user_message.user?).to be true
      expect(user_message.assistant?).to be false
    end
  end

  describe '#products' do
    it 'returns products from metadata' do
      products = [{ 'id' => 1, 'name' => 'Tire' }]
      message = build(:conversation_message, metadata: { 'products' => products })
      expect(message.products).to eq(products)
    end

    it 'returns empty array when no products' do
      message = build(:conversation_message, metadata: {})
      expect(message.products).to eq([])
    end
  end

  describe '#search_params' do
    it 'returns search_params from metadata' do
      params = { 'width' => 205, 'profile' => 55 }
      message = build(:conversation_message, metadata: { 'search_params' => params })
      expect(message.search_params).to eq(params)
    end
  end

  describe '#has_products?' do
    it 'returns true when products exist' do
      message = build(:conversation_message, metadata: { 'products' => [{ id: 1 }] })
      expect(message.has_products?).to be true
    end

    it 'returns false when no products' do
      message = build(:conversation_message, metadata: {})
      expect(message.has_products?).to be false
    end
  end

  describe '#as_api_json' do
    let(:message) do
      create(:conversation_message,
        role: 'assistant',
        content: 'Here are some tires',
        metadata: { 'products' => [{ 'id' => 1 }], 'search_params' => { 'width' => 205 } }
      )
    end

    it 'returns formatted hash' do
      json = message.as_api_json
      expect(json[:id]).to eq(message.id)
      expect(json[:role]).to eq('assistant')
      expect(json[:content]).to eq('Here are some tires')
      expect(json[:products]).to eq([{ 'id' => 1 }])
      expect(json[:search_params]).to eq({ 'width' => 205 })
      expect(json[:created_at]).to be_present
    end
  end
end
