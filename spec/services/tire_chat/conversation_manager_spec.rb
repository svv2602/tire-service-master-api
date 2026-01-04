# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::ConversationManager do
  let(:session_id) { SecureRandom.uuid }
  let(:manager) { described_class.new(session_id: session_id, locale: 'ru') }

  describe '#initialize' do
    it 'sets default locale' do
      expect(manager.locale).to eq('ru')
    end

    it 'initializes empty history' do
      expect(manager.history).to eq([])
    end

    it 'initializes default filters' do
      expect(manager.filters).to include(
        size: nil,
        season: nil,
        budget_min: nil,
        budget_max: nil
      )
    end

    it 'creates a conversation in database' do
      expect(manager.conversation).to be_a(Conversation)
      expect(manager.conversation.session_id).to eq(session_id)
    end

    it 'accepts initial filters and preferences' do
      manager = described_class.new(
        session_id: session_id,
        current_filters: { size: { width: 205 } },
        user_preferences: { priority_type: 'prestige' },
        locale: 'uk'
      )

      expect(manager.filters[:size]).to eq({ width: 205 })
      expect(manager.preferences[:priority_type]).to eq('prestige')
      expect(manager.locale).to eq('uk')
    end
  end

  describe '.from_history (legacy compatibility)' do
    it 'creates manager with imported history' do
      legacy_history = [
        { role: :user, message: 'test message' },
        { role: :assistant, message: 'response' }
      ]

      manager = described_class.from_history(
        conversation_history: legacy_history,
        current_filters: { size: { width: 205 } },
        locale: 'uk'
      )

      expect(manager.history.length).to eq(2)
      expect(manager.locale).to eq('uk')
    end
  end

  describe '.get_or_create' do
    it 'creates new conversation' do
      manager = described_class.get_or_create(session_id, locale: 'ru')
      expect(manager.conversation).to be_persisted
    end

    it 'returns same conversation for same session_id' do
      manager1 = described_class.get_or_create(session_id)
      manager2 = described_class.get_or_create(session_id)

      expect(manager1.conversation_id).to eq(manager2.conversation_id)
    end
  end

  describe '#add_message' do
    it 'adds message to database' do
      expect {
        manager.add_message(:user, 'Hello')
      }.to change(ConversationMessage, :count).by(1)
    end

    it 'stores message with correct role' do
      manager.add_message(:user, 'Hello')

      message = manager.conversation.messages.last
      expect(message.role).to eq('user')
      expect(message.content).to eq('Hello')
    end
  end

  describe '#add_user_message and #add_assistant_message' do
    it 'adds user message' do
      message = manager.add_user_message('Hello')
      expect(message.role).to eq('user')
    end

    it 'adds assistant message with metadata' do
      metadata = { 'products' => [{ 'id' => 1 }] }
      message = manager.add_assistant_message('Here are tires', metadata: metadata)

      expect(message.role).to eq('assistant')
      expect(message.metadata).to eq(metadata)
    end
  end

  describe '#history' do
    before do
      manager.add_message(:user, 'Hello')
      manager.add_message(:assistant, 'Hi there!')
    end

    it 'returns messages in chronological order' do
      expect(manager.history.length).to eq(2)
      expect(manager.history.first[:role]).to eq(:user)
      expect(manager.history.first[:message]).to eq('Hello')
    end
  end

  describe '#context_for_ai' do
    before do
      manager.add_message(:user, 'Hello')
      manager.add_message(:assistant, 'Hi!')
    end

    it 'returns messages formatted for OpenAI' do
      context = manager.context_for_ai
      expect(context).to eq([
        { role: 'user', content: 'Hello' },
        { role: 'assistant', content: 'Hi!' }
      ])
    end
  end

  describe '#update_filters' do
    it 'updates size filter' do
      manager.update_filters(size: '205/55R16')

      expect(manager.filters[:size]).to eq({
        width: 205,
        height: 55,
        diameter: 16,
        full_size: '205/55R16'
      })
    end

    it 'normalizes season filter' do
      manager.update_filters(season: 'зимние')

      expect(manager.filters[:season]).to eq('winter')
    end

    it 'saves filters to conversation metadata' do
      manager.update_filters(size: '205/55R16')
      manager.conversation.reload

      expect(manager.conversation.metadata['filters']).to be_present
    end
  end

  describe '#update_preferences' do
    it 'updates priority_type' do
      manager.update_preferences(priority_type: 'цена/качество')

      expect(manager.preferences[:priority_type]).to eq('price_quality')
    end

    it 'saves preferences to conversation metadata' do
      manager.update_preferences(price_segment: 'premium')
      manager.conversation.reload

      expect(manager.conversation.metadata['preferences']).to be_present
    end
  end

  describe '#ready_for_recommendations?' do
    it 'returns false without size' do
      manager.update_filters(season: 'winter')

      expect(manager.ready_for_recommendations?).to be false
    end

    it 'returns true with size and season' do
      manager.update_filters(size: '205/55R16', season: 'winter')

      expect(manager.ready_for_recommendations?).to be true
    end
  end

  describe '#clear' do
    it 'closes current conversation and creates new one' do
      old_conversation = manager.conversation
      manager.add_message(:user, 'Hello')
      manager.update_filters(size: '205/55R16')

      manager.clear

      expect(old_conversation.reload.status).to eq('closed')
      expect(manager.conversation.id).not_to eq(old_conversation.id)
      expect(manager.history).to eq([])
      expect(manager.filters[:size]).to be_nil
    end
  end

  describe '#reset_filters' do
    it 'resets only filters and preferences, keeps history' do
      manager.add_message(:user, 'Hello')
      manager.update_filters(size: '205/55R16', season: 'winter')
      manager.update_preferences(priority_type: 'prestige')

      manager.reset_filters

      expect(manager.history.length).to eq(1) # History preserved
      expect(manager.filters[:size]).to be_nil
      expect(manager.filters[:season]).to be_nil
      expect(manager.preferences).to eq({})
    end
  end

  describe '#determine_next_step' do
    it 'returns size_request when size is missing' do
      expect(manager.determine_next_step).to eq('size_request')
    end

    it 'returns season_request when size is set but season is missing' do
      manager.update_filters(size: '205/55R16')

      expect(manager.determine_next_step).to eq('season_request')
    end

    it 'returns recommendation_request when all required data is set' do
      manager.update_filters(size: '205/55R16', season: 'winter')

      expect(manager.determine_next_step).to eq('recommendation_request')
    end
  end

  describe '#get_next_question' do
    context 'in Russian locale' do
      it 'asks for size when missing' do
        result = manager.get_next_question

        expect(result).to include('Размер шин')
      end

      it 'indicates ready when all data is set' do
        manager.update_filters(size: '205/55R16', season: 'winter')
        result = manager.get_next_question

        expect(result).to include('все необходимые данные')
      end
    end

    context 'in Ukrainian locale' do
      let(:manager_uk) { described_class.new(session_id: session_id, locale: 'uk') }

      it 'asks for size in Ukrainian' do
        result = manager_uk.get_next_question

        expect(result).to include('Розмір шин')
      end
    end
  end

  describe '#format_for_prompt' do
    before do
      manager.add_message(:user, 'First message')
      manager.add_message(:assistant, 'First response')
      manager.add_message(:user, 'Second message')
    end

    it 'formats messages for AI prompt' do
      result = manager.format_for_prompt

      expect(result).to include('Пользователь: First message')
      expect(result).to include('Ассистент: First response')
      expect(result).to include('Пользователь: Second message')
    end

    it 'respects limit parameter' do
      result = manager.format_for_prompt(limit: 2)

      expect(result).not_to include('First message')
      expect(result).to include('First response')
      expect(result).to include('Second message')
    end
  end

  describe '#conversation_id and #session_id' do
    it 'returns conversation id' do
      expect(manager.conversation_id).to eq(manager.conversation.id)
    end

    it 'returns session id' do
      expect(manager.session_id).to eq(session_id)
    end
  end
end
