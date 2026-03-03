# frozen_string_literal: true

module Api
  module V1
    class TireChatController < BaseController
      skip_after_action :verify_authorized
      # Public endpoints - no auth required (but try optional auth)
      skip_before_action :authenticate_request, only: [:message, :stream, :reset, :status, :history, :conversations, :resume]
      before_action :authenticate_optional, only: [:message, :conversations, :resume]

      # Pagination defaults
      DEFAULT_PAGE_SIZE = 20
      MAX_PAGE_SIZE = 100

      # Process user message
      def message
        locale = params[:locale] || 'ru'
        I18n.with_locale(locale.to_sym) do
          chat_service = initialize_chat_service(locale)

          response_data = chat_service.process_message(
            params[:message],
            current_available_products,
            is_quick_question: params[:is_quick_question]
          )

          render json: {
            success: true,
            response: response_data,
            conversation_id: chat_service.conversation_id,
            session_id: session_id,
            timestamp: Time.current.iso8601
          }
        end
      rescue StandardError => e
        Rails.logger.error "❌ Ошибка в tire chat: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        render json: {
          success: false,
          error: "Онлайн-консультант временно недоступен",
          fallback_message: "Попробуйте использовать стандартные фильтры поиска"
        }, status: :internal_server_error
      end

      # Server-Sent Events streaming
      def stream
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['Connection'] = 'keep-alive'

        begin
          locale = params[:locale] || 'ru'
          chat_service = initialize_chat_service(locale)

          send_sse_event('processing', { message: 'Анализирую ваш запрос...' })

          response_data = chat_service.process_message(
            params[:message],
            current_available_products
          )

          stream_response_chunks(response_data[:message])

          send_sse_event('complete', {
            response: response_data,
            conversation_id: chat_service.conversation_id,
            session_id: session_id
          })
        rescue StandardError => e
          Rails.logger.error "❌ Ошибка в tire chat stream: #{e.message}"
          send_sse_event('error', {
            message: 'Онлайн-консультант временно недоступен'
          })
        ensure
          response.stream.close
        end
      end

      # Reset conversation
      def reset
        conversation = current_conversation
        if conversation
          conversation.close!
        end

        # Generate new session
        new_session_id = SecureRandom.uuid
        session[:tire_chat_session_id] = new_session_id

        render json: {
          success: true,
          message: 'Разговор сброшен',
          session_id: new_session_id
        }
      end

      # Get current chat status
      def status
        conversation = current_conversation

        render json: {
          session_id: session_id,
          conversation_id: conversation&.id,
          history_count: conversation&.messages&.count || 0,
          current_filters: conversation&.metadata&.dig('filters') || {},
          user_preferences: conversation&.metadata&.dig('preferences') || {},
          status: conversation&.status || 'new',
          timestamp: Time.current.iso8601
        }
      end

      # Get conversation history with pagination
      def history
        conversation = current_conversation

        unless conversation
          return render json: {
            success: true,
            messages: [],
            pagination: { total: 0, page: 1, per_page: page_size, total_pages: 0 }
          }
        end

        messages = conversation.messages.chronological
        total = messages.count

        # Pagination (use helper methods)
        page = current_page
        per_page = page_size
        offset = pagination_offset

        paginated_messages = messages.offset(offset).limit(per_page)

        render json: {
          success: true,
          conversation_id: conversation.id,
          session_id: session_id,
          messages: paginated_messages.map(&:as_api_json),
          filters: conversation.metadata&.dig('filters') || {},
          preferences: conversation.metadata&.dig('preferences') || {},
          pagination: {
            total: total,
            page: page,
            per_page: per_page,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end

      # List user's conversations (authenticated only)
      def conversations
        conversations = current_user_conversations
          .order(updated_at: :desc)
          .limit(page_size)
          .offset(pagination_offset)

        total = current_user_conversations.count

        render json: {
          success: true,
          conversations: conversations.map { |c| conversation_summary(c) },
          pagination: {
            total: total,
            page: current_page,
            per_page: page_size,
            total_pages: (total.to_f / page_size).ceil
          }
        }
      end

      # Resume specific conversation
      def resume
        conversation = find_conversation_to_resume

        unless conversation
          return render json: {
            success: false,
            error: 'Разговор не найден'
          }, status: :not_found
        end

        # Update session to use this conversation
        session[:tire_chat_session_id] = conversation.session_id

        render json: {
          success: true,
          conversation_id: conversation.id,
          session_id: conversation.session_id,
          messages: conversation.messages.chronological.last(20).map(&:as_api_json),
          filters: conversation.metadata&.dig('filters') || {},
          preferences: conversation.metadata&.dig('preferences') || {}
        }
      end

      private

      # Try to authenticate without failing if no token
      def authenticate_optional
        header = request.headers['Authorization']
        token = header&.split(' ')&.last

        return if token.blank?

        begin
          decoded = Auth::JsonWebToken.decode(token)
          @current_user = User.find(decoded['user_id'])
        rescue StandardError
          # Ignore auth errors - user can proceed unauthenticated
        end
      end

      def initialize_chat_service(locale = 'ru')
        TireChat::Service.new(
          session_id: session_id,
          user: current_user,
          locale: locale
        )
      end

      def session_id
        # Allow passing session_id as parameter (for API clients without cookie support)
        # or via header X-Session-ID
        params[:session_id] ||
          request.headers['X-Session-ID'] ||
          (session[:tire_chat_session_id] ||= SecureRandom.uuid)
      end

      def current_conversation
        return nil if session_id.blank?

        Conversation.active.find_by(session_id: session_id)
      end

      def current_user_conversations
        if current_user
          Conversation.where(user: current_user)
        else
          Conversation.where(session_id: session_id)
        end
      end

      def find_conversation_to_resume
        conversation_id = params[:conversation_id] || params[:id]

        if current_user
          Conversation.where(user: current_user).find_by(id: conversation_id)
        else
          Conversation.where(session_id: session_id).find_by(id: conversation_id)
        end
      end

      def conversation_summary(conversation)
        last_message = conversation.messages.chronological.last
        {
          id: conversation.id,
          session_id: conversation.session_id,
          status: conversation.status,
          messages_count: conversation.messages.count,
          last_message: last_message&.content&.truncate(100),
          last_message_at: last_message&.created_at,
          filters: conversation.metadata&.dig('filters'),
          created_at: conversation.created_at,
          updated_at: conversation.updated_at
        }
      end

      def current_available_products
        nil
      end

      def current_page
        [params[:page].to_i, 1].max
      end

      def page_size
        per_page = params[:per_page].to_i
        per_page = DEFAULT_PAGE_SIZE if per_page <= 0
        [per_page, MAX_PAGE_SIZE].min
      end

      def pagination_offset
        (current_page - 1) * page_size
      end

      # SSE helpers
      def send_sse_event(event_type, data)
        response.stream.write("event: #{event_type}\n")
        response.stream.write("data: #{data.to_json}\n\n")
      rescue IOError
        Rails.logger.info "🔌 Клиент отключился от SSE"
      end

      def stream_response_chunks(message)
        return if message.blank?

        sentences = message.split(/(?<=[.!?])\s+/)

        sentences.each_with_index do |sentence, index|
          send_sse_event('chunk', {
            text: sentence + (index < sentences.length - 1 ? ' ' : ''),
            chunk_index: index,
            is_final: index == sentences.length - 1
          })

          sleep(0.1) unless Rails.env.test?
        end
      end
    end
  end
end
