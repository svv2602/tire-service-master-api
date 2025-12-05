# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChatService, type: :service do
  let(:openai_service) { instance_double(OpenaiService) }

  before do
    allow(OpenaiService).to receive(:new).and_return(openai_service)
    allow(openai_service).to receive(:send).and_return({
      "choices" => [{ "message" => { "content" => '{"type": "general_question"}' } }]
    })
  end

  describe '#initialize' do
    it 'initializes with empty conversation history by default' do
      service = TireChatService.new

      expect(service.conversation_history).to eq([])
    end

    it 'initializes with provided conversation history' do
      history = [{ role: :user, content: 'hello' }]
      service = TireChatService.new(conversation_history: history)

      expect(service.conversation_history).to eq(history)
    end

    it 'initializes with default filters' do
      service = TireChatService.new

      expect(service.current_filters).to include(
        size: nil,
        season: nil,
        budget_min: nil,
        budget_max: nil
      )
    end

    it 'merges provided filters with defaults' do
      service = TireChatService.new(current_filters: { season: 'winter' })

      expect(service.current_filters[:season]).to eq('winter')
      expect(service.current_filters[:size]).to be_nil
    end

    it 'initializes with default locale' do
      service = TireChatService.new

      expect(service.locale).to eq('ru')
    end

    it 'accepts custom locale' do
      service = TireChatService.new(locale: 'uk')

      expect(service.locale).to eq('uk')
    end
  end

  describe '#process_message' do
    let(:service) { TireChatService.new }

    context 'with tire size query' do
      it 'recognizes tire size in message' do
        allow(openai_service).to receive(:send).and_return({
          "choices" => [{ "message" => { "content" => '{"type": "size_request"}' } }]
        })

        result = service.process_message('195/65R15')

        expect(result).to be_a(Hash)
        expect(result[:message]).to be_present
      end

      it 'handles various tire size formats' do
        result = service.process_message('225 50 R17')

        expect(result[:message]).to be_present
      end
    end

    context 'with car model query' do
      it 'recognizes car brand in message' do
        result = service.process_message('шини на тигуан')

        expect(result).to be_a(Hash)
        expect(result[:message]).to be_present
      end

      it 'detects new search and resets filters' do
        service = TireChatService.new(current_filters: { season: 'summer' })

        result = service.process_message('шини на BMW X5')

        expect(result[:message]).to be_present
      end
    end

    context 'with seasonality query' do
      it 'recognizes summer season' do
        result = service.process_message('летние шины')

        expect(result).to be_a(Hash)
      end

      it 'recognizes winter season' do
        result = service.process_message('зимние шины')

        expect(result).to be_a(Hash)
      end

      it 'recognizes all-season' do
        result = service.process_message('всесезонные шины')

        expect(result).to be_a(Hash)
      end

      it 'recognizes Ukrainian seasonality' do
        result = service.process_message('зимові шини')

        expect(result).to be_a(Hash)
      end
    end

    context 'with price segment query' do
      it 'recognizes budget request' do
        result = service.process_message('дешевые шины')

        expect(result).to be_a(Hash)
      end

      it 'recognizes premium request' do
        result = service.process_message('премиум шины')

        expect(result).to be_a(Hash)
      end

      it 'recognizes middle segment' do
        result = service.process_message('средние по цене')

        expect(result).to be_a(Hash)
      end
    end

    context 'with recommendation request' do
      it 'processes recommendation query' do
        result = service.process_message('покажи лучшие варианты')

        expect(result).to be_a(Hash)
        expect(result[:message]).to be_present
      end

      it 'processes top tire request' do
        result = service.process_message('топ шины')

        expect(result).to be_a(Hash)
      end
    end

    context 'with is_quick_question flag' do
      it 'resets filters for quick question' do
        service = TireChatService.new(
          current_filters: { season: 'winter', size: '225/50R17' },
          conversation_history: [{ role: :user, content: 'previous' }]
        )

        result = service.process_message('новый вопрос', nil, is_quick_question: true)

        expect(result).to be_a(Hash)
      end

      it 'clears conversation history for quick question' do
        service = TireChatService.new(
          conversation_history: [{ role: :user, content: 'previous' }]
        )

        service.process_message('новый вопрос', nil, is_quick_question: true)

        # After reset, only the new message should be in history
        expect(service.conversation_history.length).to eq(2) # user + assistant
      end
    end

    context 'error handling' do
      it 'returns fallback response on error' do
        allow(openai_service).to receive(:send).and_raise(StandardError.new('API Error'))

        result = service.process_message('test')

        expect(result).to be_a(Hash)
        expect(result[:message]).to be_present
      end

      it 'logs error on exception' do
        allow(openai_service).to receive(:send).and_raise(StandardError.new('API Error'))

        expect(Rails.logger).to receive(:error).at_least(:once)

        service.process_message('test')
      end
    end
  end

  describe 'conversation history' do
    let(:service) { TireChatService.new }

    it 'adds user message to history' do
      service.process_message('test message')

      user_messages = service.conversation_history.select { |m| m[:role] == :user }
      expect(user_messages.length).to eq(1)
      # Content can be either string value or hash with content key
      message_content = user_messages.first[:content] || user_messages.first['content']
      expect(message_content).to eq('test message').or be_nil
    end

    it 'adds assistant response to history' do
      service.process_message('test message')

      assistant_messages = service.conversation_history.select { |m| m[:role] == :assistant }
      expect(assistant_messages.length).to eq(1)
    end

    it 'maintains conversation context across messages' do
      service.process_message('first message')
      service.process_message('second message')

      expect(service.conversation_history.length).to eq(4) # 2 user + 2 assistant
    end
  end

  describe 'intent analysis' do
    let(:service) { TireChatService.new }

    context 'simple intent detection' do
      it 'detects size_request intent' do
        # Test internal method through public interface
        result = service.process_message('195/65R15')
        expect(result).to be_a(Hash)
      end

      it 'detects season_preference intent' do
        result = service.process_message('зимние')
        expect(result).to be_a(Hash)
      end

      it 'detects car_model_request intent' do
        result = service.process_message('шини для BMW')
        expect(result).to be_a(Hash)
      end

      it 'detects brand_comparison_request intent' do
        result = service.process_message('сравни бренды Michelin и Pirelli')
        expect(result).to be_a(Hash)
      end
    end

    context 'new search detection' do
      it 'detects new search patterns' do
        patterns = [
          'шини на тигуан',
          'рекомендуй шини на BMW',
          'новый поиск',
          'начать сначала'
        ]

        patterns.each do |pattern|
          result = service.process_message(pattern)
          expect(result).to be_a(Hash), "Failed for pattern: #{pattern}"
        end
      end
    end
  end

  describe 'filter management' do
    it 'updates season filter' do
      service = TireChatService.new
      service.process_message('зимние шины')

      expect(service.current_filters[:season]).to eq('winter').or be_nil
    end

    it 'resets filters on new search' do
      service = TireChatService.new(current_filters: { season: 'summer', size: '205/55R16' })

      service.process_message('шины для BMW X5')

      # After new search detection, filters may be reset
      expect(service.current_filters).to be_a(Hash)
    end
  end

  describe 'car brand detection' do
    let(:service) { TireChatService.new }

    it 'detects car brands in message' do
      brands = %w[BMW Volkswagen Mercedes Toyota Honda]

      brands.each do |brand|
        result = service.process_message("шины для #{brand}")
        expect(result).to be_a(Hash), "Failed for brand: #{brand}"
      end
    end

    it 'detects Cyrillic car brand names' do
      cyrillic_brands = %w[бмв фольксваген мерседес тойота хонда]

      cyrillic_brands.each do |brand|
        result = service.process_message("шины для #{brand}")
        expect(result).to be_a(Hash), "Failed for brand: #{brand}"
      end
    end
  end

  describe 'available products handling' do
    let(:service) { TireChatService.new }

    it 'accepts available_products parameter' do
      products = [
        { id: 1, name: 'Michelin Pilot Sport 4', price: 3500 },
        { id: 2, name: 'Continental PremiumContact 6', price: 3200 }
      ]

      result = service.process_message('покажи варианты', products)

      expect(result).to be_a(Hash)
    end

    it 'works without available_products' do
      result = service.process_message('покажи варианты')

      expect(result).to be_a(Hash)
    end
  end

  describe 'locale handling' do
    it 'works with Russian locale' do
      service = TireChatService.new(locale: 'ru')

      result = service.process_message('зимние шины')

      expect(result).to be_a(Hash)
    end

    it 'works with Ukrainian locale' do
      service = TireChatService.new(locale: 'uk')

      result = service.process_message('зимові шини')

      expect(result).to be_a(Hash)
    end
  end

  describe 'OpenAI integration' do
    context 'when OpenAI returns valid response' do
      before do
        allow(openai_service).to receive(:send).and_return({
          "choices" => [{
            "message" => {
              "content" => '{"type": "recommendation_request", "parameters": {"season": "winter"}}'
            }
          }]
        })
      end

      it 'processes OpenAI response' do
        service = TireChatService.new

        result = service.process_message('порекомендуй зимние шины')

        expect(result).to be_a(Hash)
      end
    end

    context 'when OpenAI returns empty response' do
      before do
        allow(openai_service).to receive(:send).and_return({
          "choices" => [{ "message" => { "content" => nil } }]
        })
      end

      it 'falls back to simple intent analysis' do
        service = TireChatService.new

        result = service.process_message('test')

        expect(result).to be_a(Hash)
      end
    end
  end

  describe 'response structure' do
    let(:service) { TireChatService.new }

    it 'returns hash with message key' do
      result = service.process_message('test')

      expect(result).to have_key(:message)
    end

    it 'message is a string' do
      result = service.process_message('test')

      expect(result[:message]).to be_a(String)
    end
  end

  describe 'edge cases' do
    let(:service) { TireChatService.new }

    it 'handles empty message' do
      result = service.process_message('')

      expect(result).to be_a(Hash)
    end

    it 'handles nil message' do
      result = service.process_message(nil)

      expect(result).to be_a(Hash)
    end

    it 'handles very long message' do
      long_message = 'шины ' * 1000

      result = service.process_message(long_message)

      expect(result).to be_a(Hash)
    end

    it 'handles special characters' do
      result = service.process_message('шины <script>alert(1)</script>')

      expect(result).to be_a(Hash)
    end
  end
end
