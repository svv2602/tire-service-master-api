# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tire Chat API', type: :request do
  let(:session_id) { SecureRandom.uuid }
  let(:headers) { { 'Content-Type' => 'application/json', 'X-Session-ID' => session_id } }

  describe 'POST /api/v1/tire_chat/message' do
    let(:params) { { message: 'Нужны зимние шины 205/55R16', locale: 'ru' } }

    it 'processes message and returns response' do
      post '/api/v1/tire_chat/message', params: params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['response']).to be_present
      expect(json['session_id']).to eq(session_id)
    end

    it 'creates conversation in database' do
      expect {
        post '/api/v1/tire_chat/message', params: params.to_json, headers: headers
      }.to change(Conversation, :count).by(1)
    end

    it 'creates messages in database' do
      expect {
        post '/api/v1/tire_chat/message', params: params.to_json, headers: headers
      }.to change(ConversationMessage, :count).by(2) # user + assistant
    end

    it 'returns conversation_id' do
      post '/api/v1/tire_chat/message', params: params.to_json, headers: headers

      json = JSON.parse(response.body)
      expect(json['conversation_id']).to be_present
      expect(Conversation.find(json['conversation_id'])).to be_present
    end

    it 'reuses same conversation for same session_id' do
      post '/api/v1/tire_chat/message', params: params.to_json, headers: headers
      first_conversation_id = JSON.parse(response.body)['conversation_id']

      post '/api/v1/tire_chat/message',
        params: { message: 'Second message', locale: 'ru' }.to_json,
        headers: headers

      second_conversation_id = JSON.parse(response.body)['conversation_id']
      expect(second_conversation_id).to eq(first_conversation_id)
    end
  end

  describe 'GET /api/v1/tire_chat/status' do
    context 'without existing conversation' do
      it 'returns empty status' do
        get '/api/v1/tire_chat/status', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['session_id']).to eq(session_id)
        expect(json['history_count']).to eq(0)
        expect(json['status']).to eq('new')
      end
    end

    context 'with existing conversation' do
      before do
        post '/api/v1/tire_chat/message',
          params: { message: 'Hello', locale: 'ru' }.to_json,
          headers: headers
      end

      it 'returns conversation status' do
        get '/api/v1/tire_chat/status', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['conversation_id']).to be_present
        expect(json['history_count']).to eq(2)
        expect(json['status']).to eq('active')
      end
    end
  end

  describe 'POST /api/v1/tire_chat/reset' do
    before do
      post '/api/v1/tire_chat/message',
        params: { message: 'Hello', locale: 'ru' }.to_json,
        headers: headers
    end

    it 'closes current conversation' do
      conversation = Conversation.find_by(session_id: session_id)

      post '/api/v1/tire_chat/reset', headers: headers

      expect(response).to have_http_status(:ok)
      expect(conversation.reload.status).to eq('closed')
    end

    it 'returns new session_id' do
      post '/api/v1/tire_chat/reset', headers: headers

      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['session_id']).to be_present
      expect(json['session_id']).not_to eq(session_id)
    end
  end

  describe 'GET /api/v1/tire_chat/history' do
    context 'without conversation' do
      it 'returns empty history' do
        get '/api/v1/tire_chat/history', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['messages']).to eq([])
        expect(json['pagination']['total']).to eq(0)
      end
    end

    context 'with conversation' do
      before do
        post '/api/v1/tire_chat/message',
          params: { message: 'First message', locale: 'ru' }.to_json,
          headers: headers
        post '/api/v1/tire_chat/message',
          params: { message: 'Second message', locale: 'ru' }.to_json,
          headers: headers
      end

      it 'returns message history' do
        get '/api/v1/tire_chat/history', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['messages'].length).to eq(4) # 2 user + 2 assistant
        expect(json['conversation_id']).to be_present
      end

      it 'returns messages in chronological order' do
        get '/api/v1/tire_chat/history', headers: headers

        json = JSON.parse(response.body)
        messages = json['messages']
        expect(messages.first['role']).to eq('user')
        expect(messages.first['content']).to include('First message')
      end

      it 'supports pagination' do
        get '/api/v1/tire_chat/history', params: { page: 1, per_page: 2 }, headers: headers

        json = JSON.parse(response.body)
        expect(json['messages'].length).to eq(2)
        expect(json['pagination']['total']).to eq(4)
        expect(json['pagination']['page']).to eq(1)
        expect(json['pagination']['per_page']).to eq(2)
        expect(json['pagination']['total_pages']).to eq(2)
      end
    end
  end

  describe 'GET /api/v1/tire_chat/conversations' do
    let(:user) { create(:user) }
    let(:user_session_id) { SecureRandom.uuid }
    let(:auth_headers) { headers.merge(auth_headers_for(user)).merge('X-Session-ID' => user_session_id) }

    context 'without authentication' do
      before do
        # Create conversation via message
        post '/api/v1/tire_chat/message',
          params: { message: 'Hello', locale: 'ru' }.to_json,
          headers: headers
      end

      it 'returns conversations for session' do
        get '/api/v1/tire_chat/conversations', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['conversations'].length).to eq(1)
      end
    end

    context 'with authentication' do
      let!(:user_conversations) do
        3.times.map do |i|
          create(:conversation, user: user, session_id: SecureRandom.uuid).tap do |conv|
            create(:conversation_message, conversation: conv, role: 'user', content: "Message #{i}")
          end
        end
      end

      it 'returns user conversations' do
        get '/api/v1/tire_chat/conversations', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['conversations'].length).to eq(3)
      end

      it 'includes conversation summary' do
        get '/api/v1/tire_chat/conversations', headers: auth_headers

        json = JSON.parse(response.body)
        conversation = json['conversations'].first
        expect(conversation).to include('id', 'session_id', 'status', 'messages_count', 'last_message')
      end
    end
  end

  describe 'POST /api/v1/tire_chat/conversations/:id/resume' do
    context 'with valid conversation' do
      let!(:conversation) do
        create(:conversation, session_id: session_id, status: 'active').tap do |conv|
          create(:conversation_message, conversation: conv, role: 'user', content: 'Previous message')
          create(:conversation_message, conversation: conv, role: 'assistant', content: 'Previous response')
        end
      end

      it 'resumes conversation' do
        # Use same session headers to have access to conversation
        post "/api/v1/tire_chat/conversations/#{conversation.id}/resume", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['conversation_id']).to eq(conversation.id)
      end

      it 'returns conversation messages' do
        post "/api/v1/tire_chat/conversations/#{conversation.id}/resume", headers: headers

        json = JSON.parse(response.body)
        expect(json['messages']).to be_present
        expect(json['messages'].length).to eq(2)
      end

      it 'returns filters and preferences' do
        conversation.update!(metadata: {
          'filters' => { 'size' => { 'width' => 205 } },
          'preferences' => { 'priority_type' => 'price_quality' }
        })

        post "/api/v1/tire_chat/conversations/#{conversation.id}/resume", headers: headers

        json = JSON.parse(response.body)
        expect(json['filters']).to eq({ 'size' => { 'width' => 205 } })
        expect(json['preferences']).to eq({ 'priority_type' => 'price_quality' })
      end
    end

    context 'with invalid conversation' do
      it 'returns not found' do
        post '/api/v1/tire_chat/conversations/99999/resume', headers: headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end

    context 'with conversation from different session' do
      let(:other_conversation) { create(:conversation, session_id: SecureRandom.uuid) }

      it 'returns not found' do
        post "/api/v1/tire_chat/conversations/#{other_conversation.id}/resume", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'response suggestions' do
    it 'includes suggestions in response' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Зимние шины 205/55R16', locale: 'ru' }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['response']).to have_key('suggestions')
      expect(json['response']['suggestions']).to be_an(Array)
    end

    it 'suggestions have required structure' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Расскажи о брендах шин', locale: 'ru' }.to_json,
           headers: headers

      json = JSON.parse(response.body)
      suggestions = json['response']['suggestions']

      if suggestions.present?
        suggestion = suggestions.first
        expect(suggestion).to have_key('id')
        expect(suggestion).to have_key('text')
        expect(suggestion).to have_key('type')
        expect(%w[filter comparison detail action]).to include(suggestion['type'])
      end
    end

    it 'limits suggestions to 4' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Зимние шины 205/55R16', locale: 'ru' }.to_json,
           headers: headers

      json = JSON.parse(response.body)
      suggestions = json['response']['suggestions']
      expect(suggestions.length).to be <= 4
    end
  end

  describe 'GET /api/v1/tire_chat/stream' do
    it 'returns event stream content type' do
      get '/api/v1/tire_chat/stream', params: { message: 'Зимние шины', locale: 'ru' }, headers: headers

      expect(response.content_type).to include('text/event-stream')
    end
  end

  describe 'analytics tracking' do
    it 'creates chat analytics record' do
      expect {
        post '/api/v1/tire_chat/message',
             params: { message: 'Зимние шины', locale: 'ru' }.to_json,
             headers: headers
      }.to change(ChatAnalytic, :count).by(1)
    end

    it 'tracks quick questions' do
      post '/api/v1/tire_chat/message',
           params: { message: 'Зимние шины', locale: 'ru', is_quick_question: true }.to_json,
           headers: headers

      analytic = ChatAnalytic.last
      expect(analytic.metadata['is_quick_question']).to be true
    end
  end

  # Helper method for authenticated requests
  def auth_headers_for(user)
    token = JsonWebToken.encode(user_id: user.id)
    { 'Authorization' => "Bearer #{token}" }
  end
end
