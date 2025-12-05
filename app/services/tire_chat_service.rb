# frozen_string_literal: true

# Backward-compatible facade for TireChat::Service
# This class delegates to the new modular TireChat::Service while maintaining
# the original API for existing code.
#
# Original: 2107 lines (monolithic)
# New: 6 modules (AIClient, ResponseFormatter, SearchAdapter, MessageProcessor,
#      ConversationManager, Service) < 500 lines each
#
# @see TireChat::Service for the new implementation
class TireChatService
  include ActionView::Helpers::TextHelper

  delegate :conversation_history, :current_filters, :user_preferences, :locale, to: :@service

  # Backward-compatible attribute readers that return the underlying hashes
  attr_reader :conversation_history, :current_filters, :user_preferences, :locale

  def initialize(conversation_history: [], current_filters: {}, user_preferences: {}, locale: 'ru')
    @service = TireChat::Service.new(
      conversation_history: conversation_history,
      current_filters: current_filters,
      user_preferences: user_preferences,
      locale: locale
    )

    # Keep references for backward compatibility
    @conversation_history = @service.conversation_history
    @current_filters = @service.current_filters
    @user_preferences = @service.user_preferences
    @locale = @service.locale
  end

  # Main method to process user message
  # @param user_message [String] User's message
  # @param available_products [ActiveRecord::Relation, nil] Optional products scope
  # @param is_quick_question [Boolean] True if this is a standalone quick question
  # @return [Hash] Response with message, filters, recommendations, etc.
  def process_message(user_message, available_products = nil, is_quick_question: false)
    result = @service.process_message(user_message, available_products, is_quick_question: is_quick_question)

    # Update local references after processing
    @conversation_history = @service.conversation_history
    @current_filters = @service.current_filters
    @user_preferences = @service.user_preferences

    result
  end

  # Clear conversation
  def clear_conversation
    @service.clear_conversation

    # Update local references
    @conversation_history = @service.conversation_history
    @current_filters = @service.current_filters
    @user_preferences = @service.user_preferences
  end

  # Delegate any missing methods to the underlying service
  def method_missing(method_name, *args, **kwargs, &block)
    if @service.respond_to?(method_name)
      @service.send(method_name, *args, **kwargs, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @service.respond_to?(method_name) || super
  end
end
