# frozen_string_literal: true

module Api
  module V1
    class TireChatController < BaseController
      # Отключаем авторизацию для чата (публичный доступ)
      skip_before_action :authenticate_request, only: [:message, :stream, :reset, :status]
      
      # Обработка сообщения пользователя
      def message
        chat_service = initialize_chat_service
        
        response_data = chat_service.process_message(
          params[:message],
          current_available_products
        )
        
        # Сохраняем обновленное состояние в сессии
        save_chat_state(chat_service)
        
        render json: {
          success: true,
          response: response_data,
          conversation_id: session[:conversation_id],
          timestamp: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "❌ Ошибка в tire chat: #{e.message}"
        render json: {
          success: false,
          error: "Онлайн-консультант временно недоступен",
          fallback_message: "Попробуйте использовать стандартные фильтры поиска"
        }, status: 500
      end

      # Стриминг ответа (Server-Sent Events)
      def stream
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['Connection'] = 'keep-alive'
        
        begin
          chat_service = initialize_chat_service
          
          # Отправляем событие начала обработки
          send_sse_event('processing', { message: 'Анализирую ваш запрос...' })
          
          # Обрабатываем сообщение
          response_data = chat_service.process_message(
            params[:message],
            current_available_products
          )
          
          # Стримим ответ по частям
          stream_response_chunks(response_data[:message])
          
          # Отправляем финальные данные
          send_sse_event('complete', {
            response: response_data,
            conversation_id: session[:conversation_id]
          })
          
          # Сохраняем состояние
          save_chat_state(chat_service)
          
        rescue => e
          Rails.logger.error "❌ Ошибка в tire chat stream: #{e.message}"
          send_sse_event('error', {
            message: 'Онлайн-консультант временно недоступен'
          })
        ensure
          response.stream.close
        end
      end

      # Сброс разговора
      def reset
        session[:conversation_history] = []
        session[:current_filters] = {}
        session[:user_preferences] = {}
        session[:conversation_id] = SecureRandom.uuid
        
        render json: {
          success: true,
          message: 'Разговор сброшен',
          conversation_id: session[:conversation_id]
        }
      end

      # Получение текущего состояния чата
      def status
        render json: {
          conversation_id: session[:conversation_id],
          history_count: (session[:conversation_history] || []).length,
          current_filters: session[:current_filters] || {},
          user_preferences: session[:user_preferences] || {},
          timestamp: Time.current.iso8601
        }
      end

      private

      # Инициализация сервиса чата с данными из сессии
      def initialize_chat_service
        # Создаем ID разговора если его нет
        session[:conversation_id] ||= SecureRandom.uuid
        
        TireChatService.new(
          conversation_history: session[:conversation_history] || [],
          current_filters: session[:current_filters] || {},
          user_preferences: session[:user_preferences] || {}
        )
      end

      # Получение доступных товаров (можно кэшировать)
      def current_available_products
        # Возвращаем nil, чтобы сервис сам делал запрос к БД
        # В будущем здесь можно добавить кэширование или фильтрацию
        nil
      end

      # Сохранение состояния чата в сессии (оптимизированное)
      def save_chat_state(chat_service)
        # Ограничиваем историю до 5 последних сообщений для экономии места
        history = chat_service.conversation_history.last(5).map do |entry|
          {
            role: entry[:role],
            message: entry[:message].to_s[0..200], # Обрезаем длинные сообщения
            timestamp: entry[:timestamp]
          }
        end
        
        session[:conversation_history] = history
        session[:current_filters] = chat_service.current_filters
        session[:user_preferences] = chat_service.user_preferences
      end

      # Отправка Server-Sent Event
      def send_sse_event(event_type, data)
        response.stream.write("event: #{event_type}\n")
        response.stream.write("data: #{data.to_json}\n\n")
      rescue IOError
        # Клиент отключился
        Rails.logger.info "🔌 Клиент отключился от SSE"
      end

      # Стриминг ответа по частям для эффекта печати
      def stream_response_chunks(message)
        return if message.blank?
        
        # Разбиваем сообщение на предложения
        sentences = message.split(/(?<=[.!?])\s+/)
        
        sentences.each_with_index do |sentence, index|
          send_sse_event('chunk', {
            text: sentence + (index < sentences.length - 1 ? ' ' : ''),
            chunk_index: index,
            is_final: index == sentences.length - 1
          })
          
          # Небольшая задержка для эффекта печати
          sleep(0.1) unless Rails.env.test?
        end
      end
    end
  end
end