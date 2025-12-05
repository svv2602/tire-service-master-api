# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::ConversationManager do
  let(:manager) { described_class.new(locale: 'ru') }

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

    it 'accepts initial parameters' do
      manager = described_class.new(
        conversation_history: [{ role: :user, message: 'test' }],
        current_filters: { size: { width: 205 } },
        user_preferences: { priority_type: 'prestige' },
        locale: 'uk'
      )

      expect(manager.history).to eq([{ role: :user, message: 'test' }])
      expect(manager.filters[:size]).to eq({ width: 205 })
      expect(manager.preferences[:priority_type]).to eq('prestige')
      expect(manager.locale).to eq('uk')
    end
  end

  describe '#add_message' do
    it 'adds message to history' do
      manager.add_message(:user, 'Hello')

      expect(manager.history.length).to eq(1)
      expect(manager.history.first[:role]).to eq(:user)
      expect(manager.history.first[:message]).to eq('Hello')
      expect(manager.history.first[:timestamp]).to be_a(Time)
    end

    it 'trims history to MAX_HISTORY_LENGTH' do
      25.times { |i| manager.add_message(:user, "Message #{i}") }

      expect(manager.history.length).to eq(20)
      expect(manager.history.first[:message]).to eq('Message 5')
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

    it 'updates brands filter' do
      manager.update_filters(brands: %w[Michelin Continental])

      expect(manager.filters[:brands]).to eq(%w[michelin continental])
    end
  end

  describe '#update_preferences' do
    it 'updates priority_type' do
      manager.update_preferences(priority_type: 'цена/качество')

      expect(manager.preferences[:priority_type]).to eq('price_quality')
    end

    it 'updates price_segment' do
      manager.update_preferences(price_segment: 'premium')

      expect(manager.preferences[:price_segment]).to eq('premium')
    end

    it 'updates car_model' do
      manager.update_preferences(car_model: 'Volkswagen Tiguan')

      expect(manager.preferences[:car_model]).to eq('Volkswagen Tiguan')
    end
  end

  describe '#ready_for_recommendations?' do
    it 'returns false without size' do
      manager.update_filters(season: 'winter')

      expect(manager.ready_for_recommendations?).to be false
    end

    it 'returns false without season' do
      manager.update_filters(size: '205/55R16')

      expect(manager.ready_for_recommendations?).to be false
    end

    it 'returns true with size and season' do
      manager.update_filters(size: '205/55R16', season: 'winter')

      expect(manager.ready_for_recommendations?).to be true
    end
  end

  describe '#clear' do
    it 'resets all state' do
      manager.add_message(:user, 'Hello')
      manager.update_filters(size: '205/55R16', season: 'winter')
      manager.update_preferences(priority_type: 'prestige')

      manager.clear

      expect(manager.history).to eq([])
      expect(manager.filters[:size]).to be_nil
      expect(manager.filters[:season]).to be_nil
      expect(manager.preferences).to eq({})
    end

    it 'preserves locale' do
      manager_uk = described_class.new(locale: 'uk')
      manager_uk.clear

      expect(manager_uk.locale).to eq('uk')
    end
  end

  describe '#reset_filters' do
    it 'resets only filters and preferences' do
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

      it 'asks for season when size is set' do
        manager.update_filters(size: '205/55R16')
        result = manager.get_next_question

        expect(result).to include('Сезон')
      end

      it 'indicates ready when all data is set' do
        manager.update_filters(size: '205/55R16', season: 'winter')
        result = manager.get_next_question

        expect(result).to include('все необходимые данные')
      end
    end

    context 'in Ukrainian locale' do
      let(:manager_uk) { described_class.new(locale: 'uk') }

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
end
