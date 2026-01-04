# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TireChat::Service, 'fallback behavior', type: :service do
  let(:session_id) { SecureRandom.uuid }
  let(:service) { described_class.new(session_id: session_id) }
  let(:ai_client) { instance_double(TireChat::AIClient) }

  before do
    allow(TireChat::AIClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:available?).and_return(true)
    allow(TireChat::AnalyticsService).to receive(:track_message)
    allow(TireChat::AnalyticsService).to receive(:track_ai_failure)
  end

  describe '#generate_rule_based_fallback' do
    context 'when message contains winter keywords' do
      it 'generates winter tire fallback for Russian winter query' do
        result = service.send(:generate_rule_based_fallback, 'хочу зимние шины', nil)

        # Without products, returns no_results action
        expect(result[:action]).to eq('fallback_seasonal_no_results')
        expect(result[:is_fallback]).to be true
      end

      it 'generates winter tire fallback for English winter query' do
        result = service.send(:generate_rule_based_fallback, 'I need winter tires', nil)

        expect(result[:action]).to eq('fallback_seasonal_no_results')
        expect(result[:is_fallback]).to be true
      end

      it 'generates winter tire fallback for snow-related query' do
        result = service.send(:generate_rule_based_fallback, 'шины для снега', nil)

        expect(result[:action]).to eq('fallback_seasonal_no_results')
      end
    end

    context 'when message contains summer keywords' do
      it 'generates summer tire fallback' do
        result = service.send(:generate_rule_based_fallback, 'нужны летние шины', nil)

        expect(result[:action]).to eq('fallback_seasonal_no_results')
        expect(result[:is_fallback]).to be true
      end
    end

    context 'when message contains all-season keywords' do
      it 'generates all-season tire fallback' do
        result = service.send(:generate_rule_based_fallback, 'всесезонные шины', nil)

        expect(result[:action]).to eq('fallback_seasonal_no_results')
        expect(result[:is_fallback]).to be true
      end
    end

    context 'when message contains brand comparison keywords' do
      it 'generates brand comparison fallback for Russian query' do
        result = service.send(:generate_rule_based_fallback, 'сравни бренды шин', nil)

        expect(result[:action]).to eq('fallback_brand_comparison')
        expect(result[:message]).to include('Michelin')
        expect(result[:message]).to include('Continental')
        expect(result[:is_fallback]).to be true
      end

      it 'generates brand comparison fallback for vs query' do
        result = service.send(:generate_rule_based_fallback, 'Michelin vs Continental', nil)

        expect(result[:action]).to eq('fallback_brand_comparison')
      end
    end

    context 'when message does not match any pattern' do
      it 'generates default fallback' do
        result = service.send(:generate_rule_based_fallback, 'random message', nil)

        expect(result[:action]).to eq('fallback')
        expect(result[:message]).to include('AI-консультант')
        expect(result[:is_fallback]).to be true
      end
    end

    context 'with Ukrainian locale' do
      let(:service) { described_class.new(session_id: session_id, locale: 'uk') }

      it 'generates fallback in Ukrainian' do
        result = service.send(:generate_rule_based_fallback, 'random message', nil)

        expect(result[:message]).to include('Вибачте')
      end
    end
  end

  describe '#with_ai_fallback' do
    context 'when AI returns nil' do
      it 'uses rule-based fallback' do
        # Use a message that triggers default fallback
        result = service.send(:with_ai_fallback, 'random query', nil) { nil }

        expect(result[:is_fallback]).to be true
        expect(result[:action]).to eq('fallback')
      end

      it 'logs the fallback' do
        expect(Rails.logger).to receive(:warn).with(/AI returned nil/)

        service.send(:with_ai_fallback, 'test message', nil) { nil }
      end
    end

    context 'when AI raises RateLimitError' do
      it 'uses rule-based fallback' do
        # Use a message that triggers default fallback
        result = service.send(:with_ai_fallback, 'random query', nil) do
          raise TireChat::AIClient::RateLimitError, 'Rate limit exceeded'
        end

        expect(result[:is_fallback]).to be true
        expect(result[:action]).to eq('fallback')
      end

      it 'logs the AI failure' do
        expect(TireChat::AnalyticsService).to receive(:track_ai_failure).with(
          hash_including(failure_type: 'rate_limit')
        )

        service.send(:with_ai_fallback, 'test', nil) do
          raise TireChat::AIClient::RateLimitError, 'Rate limit exceeded'
        end
      end
    end

    context 'when AI raises TimeoutError' do
      it 'uses rule-based fallback' do
        # Use a message that triggers default fallback
        result = service.send(:with_ai_fallback, 'random query', nil) do
          raise TireChat::AIClient::TimeoutError, 'Request timeout'
        end

        expect(result[:is_fallback]).to be true
        expect(result[:action]).to eq('fallback')
      end

      it 'logs the AI failure' do
        expect(TireChat::AnalyticsService).to receive(:track_ai_failure).with(
          hash_including(failure_type: 'timeout')
        )

        service.send(:with_ai_fallback, 'test', nil) do
          raise TireChat::AIClient::TimeoutError, 'Request timeout'
        end
      end
    end

    context 'when AI raises unknown error' do
      it 'uses rule-based fallback' do
        result = service.send(:with_ai_fallback, 'test', nil) do
          raise StandardError, 'Unknown error'
        end

        expect(result[:is_fallback]).to be true
      end

      it 'logs the AI failure as unknown' do
        expect(TireChat::AnalyticsService).to receive(:track_ai_failure).with(
          hash_including(failure_type: 'unknown')
        )

        service.send(:with_ai_fallback, 'test', nil) do
          raise StandardError, 'Unknown error'
        end
      end
    end

    context 'when AI returns valid response' do
      it 'returns the AI response' do
        ai_response = { message: 'AI response', action: 'openai_response' }

        result = service.send(:with_ai_fallback, 'test', nil) { ai_response }

        expect(result).to eq(ai_response)
        expect(result[:is_fallback]).to be_nil
      end
    end
  end

  describe '#log_ai_failure' do
    it 'logs error to Rails logger' do
      error = StandardError.new('Test error')

      expect(Rails.logger).to receive(:error).with(/AI Failure.*rate_limit.*Test error/)

      service.send(:log_ai_failure, 'rate_limit', 'test message', error)
    end

    it 'tracks failure in analytics' do
      error = StandardError.new('Test error')

      expect(TireChat::AnalyticsService).to receive(:track_ai_failure).with(
        failure_type: 'timeout',
        session_id: session_id,
        error_message: 'Test error',
        user_query: 'test message'
      )

      service.send(:log_ai_failure, 'timeout', 'test message', error)
    end

    it 'truncates long messages' do
      error = StandardError.new('Test error')
      long_message = 'a' * 1000

      expect(TireChat::AnalyticsService).to receive(:track_ai_failure) do |args|
        expect(args[:user_query].length).to eq(500)
        expect(args[:user_query]).to start_with('a' * 100)
      end

      service.send(:log_ai_failure, 'unknown', long_message, error)
    end
  end

  describe '#generate_seasonal_fallback' do
    context 'with available products' do
      let!(:supplier) { create(:supplier) }
      let!(:winter_tire) do
        create(:supplier_tire_product, :winter,
               supplier: supplier,
               in_stock: true,
               optimality_score: 85)
      end

      it 'returns recommendations for winter' do
        # Mock the response_formatter to avoid format issues
        allow(service.response_formatter).to receive(:format_recommendations).and_return('Mock recommendations')

        result = service.send(:generate_seasonal_fallback, 'winter', SupplierTireProduct.where(season: 'winter'))

        expect(result[:action]).to eq('fallback_seasonal_recommendations')
        expect(result[:recommendations]).to be_present
        expect(result[:is_fallback]).to be true
      end
    end

    context 'without available products' do
      it 'returns no results message' do
        result = service.send(:generate_seasonal_fallback, 'winter', SupplierTireProduct.none)

        expect(result[:action]).to eq('fallback_seasonal_no_results')
        expect(result[:is_fallback]).to be true
      end
    end
  end

  describe '#fallback_default_text' do
    context 'Russian locale' do
      let(:service) { described_class.new(session_id: session_id, locale: 'ru') }

      it 'returns Russian fallback text' do
        text = service.send(:fallback_default_text)

        expect(text).to include('Извините')
        expect(text).to include('AI-консультант')
        expect(text).to include('Воспользоваться поиском')
      end
    end

    context 'Ukrainian locale' do
      let(:service) { described_class.new(session_id: session_id, locale: 'uk') }

      it 'returns Ukrainian fallback text' do
        text = service.send(:fallback_default_text)

        expect(text).to include('Вибачте')
        expect(text).to include('AI-консультант')
        expect(text).to include('Скористатися пошуком')
      end
    end
  end

  describe '#fallback_brand_comparison_text' do
    it 'includes popular brands' do
      text = service.send(:fallback_brand_comparison_text)

      expect(text).to include('Michelin')
      expect(text).to include('Continental')
      expect(text).to include('Bridgestone')
      expect(text).to include('Nokian')
      expect(text).to include('Hankook')
    end
  end
end
