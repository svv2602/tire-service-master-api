# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenaiService, type: :service do
  let(:openai_client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow_any_instance_of(OpenaiService).to receive(:openai_api_key).and_return('test-api-key')
    allow_any_instance_of(OpenaiService).to receive(:llm_enabled?).and_return(true)
  end

  describe '#initialize' do
    context 'when API key is present' do
      it 'creates a client' do
        service = OpenaiService.new
        expect(service.instance_variable_get(:@client)).to eq(openai_client)
      end
    end

    context 'when API key is missing' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:openai_api_key).and_return(nil)
      end

      it 'sets client to nil' do
        service = OpenaiService.new
        expect(service.instance_variable_get(:@client)).to be_nil
      end
    end
  end

  describe '#chat_completion' do
    let(:service) { OpenaiService.new }
    let(:prompt) { 'Test prompt' }
    let(:mock_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => 'Test response'
            }
          }
        ]
      }
    end

    before do
      allow(openai_client).to receive(:chat).and_return(mock_response)
    end

    it 'sends request to OpenAI API' do
      expect(openai_client).to receive(:chat).with(
        parameters: hash_including(
          :model,
          :messages,
          :max_tokens,
          :temperature
        )
      )

      service.chat_completion(prompt)
    end

    it 'returns the response' do
      result = service.chat_completion(prompt)
      expect(result).to eq(mock_response)
    end

    context 'when prompt is empty' do
      it 'returns nil' do
        result = service.chat_completion('')
        expect(result).to be_nil
      end
    end

    context 'when prompt is nil' do
      it 'returns nil' do
        result = service.chat_completion(nil)
        expect(result).to be_nil
      end
    end

    context 'when API call fails' do
      before do
        allow(openai_client).to receive(:chat).and_raise(StandardError.new('API error'))
      end

      it 'returns nil' do
        result = service.chat_completion(prompt)
        expect(result).to be_nil
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/OpenAI chat completion error/)
        service.chat_completion(prompt)
      end
    end

    context 'with custom options' do
      it 'uses custom model' do
        expect(openai_client).to receive(:chat).with(
          parameters: hash_including(model: 'gpt-4')
        )

        service.chat_completion(prompt, model: 'gpt-4')
      end

      it 'uses custom max_tokens' do
        expect(openai_client).to receive(:chat).with(
          parameters: hash_including(max_tokens: 1000)
        )

        service.chat_completion(prompt, max_tokens: 1000)
      end

      it 'uses custom temperature' do
        expect(openai_client).to receive(:chat).with(
          parameters: hash_including(temperature: 0.5)
        )

        service.chat_completion(prompt, temperature: 0.5)
      end
    end
  end

  describe '#parse_tire_search_query' do
    let(:service) { OpenaiService.new }
    let(:query) { 'BMW X5 2020' }
    let(:json_response) do
      {
        'brand' => 'BMW',
        'model' => 'X5',
        'year' => 2020
      }.to_json
    end
    let(:mock_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => json_response
            }
          }
        ]
      }
    end

    before do
      allow(openai_client).to receive(:chat).and_return(mock_response)
    end

    it 'parses car brand from response' do
      result = service.parse_tire_search_query(query)
      expect(result[:brand]).to eq('BMW')
    end

    it 'parses car model from response' do
      result = service.parse_tire_search_query(query)
      expect(result[:model]).to eq('X5')
    end

    it 'parses year from response' do
      result = service.parse_tire_search_query(query)
      expect(result[:year]).to eq(2020)
    end

    context 'with tire size in response' do
      let(:json_response) do
        {
          'brand' => 'BMW',
          'tire_size' => {
            'width' => 225,
            'height' => 50,
            'diameter' => 17
          }
        }.to_json
      end

      it 'parses tire size' do
        result = service.parse_tire_search_query(query)
        expect(result[:tire_size]).to include(
          width: 225,
          height: 50,
          diameter: 17
        )
      end

      it 'builds full_size string' do
        result = service.parse_tire_search_query(query)
        expect(result[:tire_size][:full_size]).to eq('225/50R17')
      end
    end

    context 'with seasonality in response' do
      let(:json_response) do
        {
          'seasonality' => 'winter'
        }.to_json
      end

      it 'parses seasonality' do
        result = service.parse_tire_search_query(query)
        expect(result[:seasonality]).to eq('winter')
      end
    end

    context 'with tire brands in response' do
      let(:json_response) do
        {
          'tire_brands' => ['Michelin', 'Continental']
        }.to_json
      end

      it 'parses tire brands' do
        result = service.parse_tire_search_query(query)
        expect(result[:tire_brands]).to eq(['Michelin', 'Continental'])
      end
    end

    context 'when response is wrapped in markdown' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => "```json\n#{json_response}\n```"
              }
            }
          ]
        }
      end

      it 'strips markdown wrapper' do
        result = service.parse_tire_search_query(query)
        expect(result[:brand]).to eq('BMW')
      end
    end

    context 'when query is empty' do
      it 'returns empty hash' do
        result = service.parse_tire_search_query('')
        expect(result).to eq({})
      end
    end

    context 'when JSON parse fails' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => 'Not valid JSON'
              }
            }
          ]
        }
      end

      it 'returns empty hash' do
        result = service.parse_tire_search_query(query)
        expect(result).to eq({})
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        service.parse_tire_search_query(query)
        expect(Rails.logger).to have_received(:error).with(/JSON parse error/)
      end
    end

    context 'when API call fails' do
      before do
        allow(openai_client).to receive(:chat).and_raise(StandardError.new('API error'))
      end

      it 'returns empty hash' do
        result = service.parse_tire_search_query(query)
        expect(result).to eq({})
      end
    end
  end

  describe '#generate_tire_chat_response' do
    let(:service) { OpenaiService.new }
    let(:message) { 'Расскажи о зимних шинах' }
    let(:mock_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => 'Зимние шины - это специальные шины...'
            }
          }
        ]
      }
    end

    before do
      allow(openai_client).to receive(:chat).and_return(mock_response)
    end

    it 'returns chat response' do
      result = service.generate_tire_chat_response(message)
      expect(result).to eq('Зимние шины - это специальные шины...')
    end

    it 'uses Russian system prompt by default' do
      expect(openai_client).to receive(:chat).with(
        parameters: hash_including(
          messages: array_including(
            hash_including(role: 'system', content: /профессионально и дружелюбно/)
          )
        )
      )

      service.generate_tire_chat_response(message)
    end

    context 'with Ukrainian locale' do
      it 'uses Ukrainian system prompt' do
        expect(openai_client).to receive(:chat).with(
          parameters: hash_including(
            messages: array_including(
              hash_including(role: 'system', content: /професійно та дружньо/)
            )
          )
        )

        service.generate_tire_chat_response(message, {}, 'uk')
      end
    end

    context 'with current filters' do
      let(:filters) { { size: '225/50R17', season: 'winter' } }

      it 'includes filter context in message' do
        expect(openai_client).to receive(:chat).with(
          parameters: hash_including(
            messages: array_including(
              hash_including(role: 'user', content: /size: 225\/50R17/)
            )
          )
        )

        service.generate_tire_chat_response(message, filters)
      end
    end

    context 'when message is empty' do
      it 'returns nil' do
        result = service.generate_tire_chat_response('')
        expect(result).to be_nil
      end
    end

    context 'when API call fails' do
      before do
        allow(openai_client).to receive(:chat).and_raise(StandardError.new('API error'))
      end

      it 'returns nil' do
        result = service.generate_tire_chat_response(message)
        expect(result).to be_nil
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/OpenAI chat error/)
        service.generate_tire_chat_response(message)
      end
    end
  end

  describe '#test_connection' do
    let(:service) { OpenaiService.new }

    context 'when connection is successful' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => 'OK'
              }
            }
          ]
        }
      end

      before do
        allow(openai_client).to receive(:chat).and_return(mock_response)
      end

      it 'returns success true' do
        result = service.test_connection
        expect(result[:success]).to be true
      end

      it 'returns success message' do
        result = service.test_connection
        expect(result[:message]).to include('успешно')
      end
    end

    context 'when connection fails' do
      before do
        allow(openai_client).to receive(:chat).and_raise(StandardError.new('Connection failed'))
      end

      it 'returns success false' do
        result = service.test_connection
        expect(result[:success]).to be false
      end

      it 'returns error message' do
        result = service.test_connection
        expect(result[:message]).to include('Connection failed')
      end
    end

    context 'when client is nil' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:openai_api_key).and_return(nil)
      end

      it 'returns success false' do
        service = OpenaiService.new
        result = service.test_connection
        expect(result[:success]).to be false
      end

      it 'returns not configured message' do
        service = OpenaiService.new
        result = service.test_connection
        expect(result[:message]).to include('не настроен')
      end
    end
  end

  describe '.available?' do
    context 'when LLM is enabled and client is configured' do
      it 'returns true' do
        expect(OpenaiService.available?).to be true
      end
    end

    context 'when LLM is disabled' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:llm_enabled?).and_return(false)
      end

      it 'returns false' do
        expect(OpenaiService.available?).to be false
      end
    end

    context 'when API key is missing' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:openai_api_key).and_return(nil)
      end

      it 'returns false' do
        expect(OpenaiService.available?).to be false
      end
    end
  end

  describe '.configured?' do
    context 'when API key is present' do
      it 'returns true' do
        expect(OpenaiService.configured?).to be true
      end
    end

    context 'when API key is missing' do
      before do
        allow_any_instance_of(OpenaiService).to receive(:openai_api_key).and_return(nil)
      end

      it 'returns false' do
        expect(OpenaiService.configured?).to be false
      end
    end
  end

  describe 'constants' do
    describe 'TIRE_SEARCH_PROMPT' do
      it 'is defined' do
        expect(OpenaiService::TIRE_SEARCH_PROMPT).to be_a(String)
      end

      it 'includes JSON format instructions' do
        expect(OpenaiService::TIRE_SEARCH_PROMPT).to include('JSON')
      end

      it 'includes tire size information' do
        expect(OpenaiService::TIRE_SEARCH_PROMPT).to include('Размер шин')
      end
    end

    describe 'TIRE_CHAT_SYSTEM_PROMPT_RU' do
      it 'is defined' do
        expect(OpenaiService::TIRE_CHAT_SYSTEM_PROMPT_RU).to be_a(String)
      end

      it 'is in Russian' do
        expect(OpenaiService::TIRE_CHAT_SYSTEM_PROMPT_RU).to include('эксперт')
      end
    end

    describe 'TIRE_CHAT_SYSTEM_PROMPT_UK' do
      it 'is defined' do
        expect(OpenaiService::TIRE_CHAT_SYSTEM_PROMPT_UK).to be_a(String)
      end

      it 'is in Ukrainian' do
        expect(OpenaiService::TIRE_CHAT_SYSTEM_PROMPT_UK).to include('експерт')
      end
    end
  end

  describe 'result validation' do
    let(:service) { OpenaiService.new }

    describe 'year validation' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => { 'year' => year }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(openai_client).to receive(:chat).and_return(mock_response)
      end

      context 'with valid year' do
        let(:year) { 2020 }

        it 'includes year in result' do
          result = service.parse_tire_search_query('test')
          expect(result[:year]).to eq(2020)
        end
      end

      context 'with year too old' do
        let(:year) { 1980 }

        it 'excludes year from result' do
          result = service.parse_tire_search_query('test')
          expect(result[:year]).to be_nil
        end
      end

      context 'with year too new' do
        let(:year) { 2050 }

        it 'excludes year from result' do
          result = service.parse_tire_search_query('test')
          expect(result[:year]).to be_nil
        end
      end
    end

    describe 'tire size validation' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => {
                  'tire_size' => {
                    'width' => width,
                    'height' => height,
                    'diameter' => diameter
                  }
                }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(openai_client).to receive(:chat).and_return(mock_response)
      end

      context 'with valid tire size' do
        let(:width) { 225 }
        let(:height) { 50 }
        let(:diameter) { 17 }

        it 'includes tire size in result' do
          result = service.parse_tire_search_query('test')
          expect(result[:tire_size]).to be_present
        end
      end

      context 'with invalid width' do
        let(:width) { 100 }
        let(:height) { 50 }
        let(:diameter) { 17 }

        it 'excludes tire size from result' do
          result = service.parse_tire_search_query('test')
          expect(result[:tire_size]).to be_nil
        end
      end

      context 'with invalid height' do
        let(:width) { 225 }
        let(:height) { 10 }
        let(:diameter) { 17 }

        it 'excludes tire size from result' do
          result = service.parse_tire_search_query('test')
          expect(result[:tire_size]).to be_nil
        end
      end

      context 'with invalid diameter' do
        let(:width) { 225 }
        let(:height) { 50 }
        let(:diameter) { 30 }

        it 'excludes tire size from result' do
          result = service.parse_tire_search_query('test')
          expect(result[:tire_size]).to be_nil
        end
      end
    end

    describe 'seasonality validation' do
      let(:mock_response) do
        {
          'choices' => [
            {
              'message' => {
                'content' => { 'seasonality' => seasonality }.to_json
              }
            }
          ]
        }
      end

      before do
        allow(openai_client).to receive(:chat).and_return(mock_response)
      end

      context 'with valid seasonality' do
        let(:seasonality) { 'winter' }

        it 'includes seasonality in result' do
          result = service.parse_tire_search_query('test')
          expect(result[:seasonality]).to eq('winter')
        end
      end

      context 'with summer seasonality' do
        let(:seasonality) { 'summer' }

        it 'includes seasonality in result' do
          result = service.parse_tire_search_query('test')
          expect(result[:seasonality]).to eq('summer')
        end
      end

      context 'with all_season seasonality' do
        let(:seasonality) { 'all_season' }

        it 'includes seasonality in result' do
          result = service.parse_tire_search_query('test')
          expect(result[:seasonality]).to eq('all_season')
        end
      end

      context 'with invalid seasonality' do
        let(:seasonality) { 'spring' }

        it 'excludes seasonality from result' do
          result = service.parse_tire_search_query('test')
          expect(result[:seasonality]).to be_nil
        end
      end
    end
  end
end
