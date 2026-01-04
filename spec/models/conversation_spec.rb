# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should have_many(:messages).class_name('ConversationMessage').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:session_id) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[active closed archived]) }
  end

  describe 'scopes' do
    let!(:active_conversation) { create(:conversation, status: 'active') }
    let!(:closed_conversation) { create(:conversation, status: 'closed') }

    describe '.active' do
      it 'returns only active conversations' do
        expect(described_class.active).to include(active_conversation)
        expect(described_class.active).not_to include(closed_conversation)
      end
    end
  end

  describe '.find_or_create_for' do
    let(:session_id) { SecureRandom.uuid }
    let(:user) { create(:user) }

    context 'when no existing conversation' do
      it 'creates a new conversation' do
        expect {
          described_class.find_or_create_for(session_id: session_id)
        }.to change(described_class, :count).by(1)
      end

      it 'sets the session_id' do
        conversation = described_class.find_or_create_for(session_id: session_id)
        expect(conversation.session_id).to eq(session_id)
      end
    end

    context 'when active conversation exists for session' do
      let!(:existing) { create(:conversation, session_id: session_id, status: 'active') }

      it 'returns existing conversation' do
        conversation = described_class.find_or_create_for(session_id: session_id)
        expect(conversation).to eq(existing)
      end

      it 'does not create new conversation' do
        expect {
          described_class.find_or_create_for(session_id: session_id)
        }.not_to change(described_class, :count)
      end
    end

    context 'when user is provided' do
      let!(:user_conversation) do
        create(:conversation, user: user, session_id: 'old-session', status: 'active', updated_at: 30.minutes.ago)
      end

      it 'returns users recent conversation' do
        conversation = described_class.find_or_create_for(session_id: session_id, user: user)
        expect(conversation).to eq(user_conversation)
      end
    end
  end

  describe '#context_for_ai' do
    let(:conversation) { create(:conversation) }

    before do
      create(:conversation_message, conversation: conversation, role: 'user', content: 'Hello')
      create(:conversation_message, conversation: conversation, role: 'assistant', content: 'Hi there!')
      create(:conversation_message, conversation: conversation, role: 'user', content: 'Need tires')
    end

    it 'returns messages in correct format' do
      context = conversation.context_for_ai
      expect(context.length).to eq(3)
      expect(context.first).to eq({ role: 'user', content: 'Hello' })
    end

    it 'respects limit parameter' do
      context = conversation.context_for_ai(limit: 2)
      expect(context.length).to eq(2)
    end
  end

  describe '#add_user_message' do
    let(:conversation) { create(:conversation) }

    it 'creates a user message' do
      expect {
        conversation.add_user_message('Test message')
      }.to change(ConversationMessage, :count).by(1)
    end

    it 'sets correct role' do
      message = conversation.add_user_message('Test message')
      expect(message.role).to eq('user')
    end

    it 'updates conversation timestamp' do
      conversation.update!(updated_at: 1.hour.ago)
      conversation.add_user_message('Test')
      expect(conversation.reload.updated_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#add_assistant_message' do
    let(:conversation) { create(:conversation) }
    let(:metadata) { { 'products' => [{ 'id' => 1, 'name' => 'Tire' }] } }

    it 'creates an assistant message with metadata' do
      message = conversation.add_assistant_message('Response', metadata: metadata)
      expect(message.role).to eq('assistant')
      expect(message.metadata).to eq(metadata)
    end
  end

  describe '#close!' do
    let(:conversation) { create(:conversation, status: 'active') }

    it 'changes status to closed' do
      conversation.close!
      expect(conversation.status).to eq('closed')
    end
  end

  describe '#active?' do
    it 'returns true for active conversation' do
      conversation = build(:conversation, status: 'active')
      expect(conversation.active?).to be true
    end

    it 'returns false for closed conversation' do
      conversation = build(:conversation, status: 'closed')
      expect(conversation.active?).to be false
    end
  end
end
