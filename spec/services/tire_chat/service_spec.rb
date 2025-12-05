# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::Service do
  let(:service) { described_class.new(locale: 'ru') }

  before do
    allow(OpenaiService).to receive(:available?).and_return(false)
  end

  describe '#initialize' do
    it 'creates all required components' do
      expect(service.ai_client).to be_a(TireChat::AIClient)
      expect(service.message_processor).to be_a(TireChat::MessageProcessor)
      expect(service.conversation_manager).to be_a(TireChat::ConversationManager)
      expect(service.response_formatter).to be_a(TireChat::ResponseFormatter)
      expect(service.search_adapter).to be_a(TireChat::SearchAdapter)
    end

    it 'accepts initial parameters' do
      service = described_class.new(
        conversation_history: [{ role: :user, message: 'test' }],
        current_filters: { size: { width: 205, height: 55, diameter: 16 } },
        user_preferences: { priority_type: 'prestige' },
        locale: 'uk'
      )

      expect(service.conversation_history).to eq([{ role: :user, message: 'test' }])
      expect(service.current_filters[:size][:width]).to eq(205)
      expect(service.user_preferences[:priority_type]).to eq('prestige')
      expect(service.locale).to eq('uk')
    end
  end

  describe '#process_message' do
    context 'with size request' do
      it 'extracts and stores tire size' do
        result = service.process_message('Нужны шины 205/55R16')

        expect(service.current_filters[:size]).to include(
          width: 205,
          height: 55,
          diameter: 16
        )
        expect(result[:filters_updated]).to be_present
      end

      it 'asks for season after size' do
        result = service.process_message('205/55R16')

        expect(result[:message]).to include('сезон') | include('Сезон')
      end
    end

    context 'with season preference' do
      before do
        service.process_message('205/55R16')
      end

      it 'extracts and stores season' do
        result = service.process_message('Зимние')

        expect(service.current_filters[:season]).to eq('winter')
        expect(result[:filters_updated]).to be_present
      end
    end

    context 'with complex request' do
      it 'handles size and season together' do
        result = service.process_message('Нужны зимние шины 205/55R16')

        expect(service.current_filters[:size]).to be_present
        expect(service.current_filters[:season]).to eq('winter')
      end
    end

    context 'with price segment request' do
      before do
        service.process_message('205/55R16')
        service.process_message('Зимние')
      end

      it 'handles budget segment' do
        result = service.process_message('Покажи недорогие варианты')

        expect(service.user_preferences[:price_segment]).to eq('budget')
      end

      it 'handles premium segment' do
        result = service.process_message('Хочу премиум шины')

        expect(service.user_preferences[:price_segment]).to eq('premium')
      end
    end

    context 'with new search request' do
      before do
        service.process_message('205/55R16')
        service.process_message('Зимние')
      end

      it 'resets filters' do
        result = service.process_message('Начать новый поиск')

        expect(service.current_filters[:size]).to be_nil
        expect(service.current_filters[:season]).to be_nil
        expect(result[:action]).to eq('new_search_started')
      end
    end

    context 'with car model request' do
      it 'recognizes car brand and suggests search' do
        result = service.process_message('Шины для тигуана')

        expect(result[:action]).to eq('show_car_search_button')
        expect(result[:car_search_query]).to be_present
      end
    end

    context 'with size guide request' do
      it 'returns size guide message' do
        result = service.process_message('Как выбрать размер шин?')

        expect(result[:action]).to eq('size_guide_shown')
        expect(result[:message]).to include('195/65R15')
      end
    end

    context 'with brand comparison request' do
      it 'returns brand comparison message' do
        result = service.process_message('Сравни бренды шин')

        expect(result[:action]).to eq('brand_comparison_shown')
        expect(result[:message]).to include('Michelin')
        expect(result[:message]).to include('Continental')
      end
    end

    context 'with quick question flag' do
      before do
        service.process_message('205/55R16')
        service.process_message('Зимние')
      end

      it 'resets context for quick question' do
        result = service.process_message('Какой размер для тигуана?', nil, is_quick_question: true)

        expect(service.current_filters[:size]).to be_nil
        expect(service.current_filters[:season]).to be_nil
      end
    end

    context 'error handling' do
      it 'returns fallback response on error' do
        allow(service.message_processor).to receive(:analyze).and_raise(StandardError, 'Test error')

        result = service.process_message('test')

        expect(result[:action]).to eq('fallback')
        expect(result[:message]).to include('Извините')
      end
    end
  end

  describe '#conversation_history' do
    it 'tracks all messages' do
      service.process_message('Привет')
      service.process_message('205/55R16')

      expect(service.conversation_history.length).to eq(4) # 2 user + 2 assistant
    end
  end

  describe '#clear_conversation' do
    it 'clears all state' do
      service.process_message('205/55R16')
      service.process_message('Зимние')

      service.clear_conversation

      expect(service.conversation_history).to eq([])
      expect(service.current_filters[:size]).to be_nil
    end
  end
end
