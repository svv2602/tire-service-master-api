# frozen_string_literal: true

module Api
  module V1
    # Controller for AI-powered recommendations
    class AiRecommendationsController < ApplicationController
      before_action :authenticate_user!, except: [:review_summary]

      # GET /api/v1/ai_recommendations/seasonal
      # Get seasonal tire change recommendation for current user
      def seasonal
        unless current_user.client?
          return render json: { error: 'Only clients can access recommendations' }, status: :forbidden
        end

        recommendation = seasonal_service.recommend_tire_change(current_user.client)
        reminders = seasonal_service.get_reminders(current_user.client)

        render json: {
          success: true,
          recommendation: recommendation,
          reminders: reminders,
          current_season: seasonal_service.current_recommended_season,
          is_transition_season: seasonal_service.tire_change_season?
        }
      rescue StandardError => e
        Rails.logger.error("Seasonal recommendation error: #{e.message}")
        render json: { success: false, error: 'Could not generate recommendation' }, status: :service_unavailable
      end

      # GET /api/v1/ai_recommendations/vehicle_tires
      # Get tire recommendations for a specific vehicle
      def vehicle_tires
        required_params = %i[brand model]
        missing = required_params.select { |p| params[p].blank? }

        if missing.any?
          return render json: { error: "Missing parameters: #{missing.join(', ')}" }, status: :bad_request
        end

        vehicle_info = {
          brand: params[:brand],
          model: params[:model],
          year: params[:year]
        }

        recommendations = seasonal_service.recommend_tires_for_vehicle(
          vehicle_info,
          season: params[:season]
        )

        render json: { success: true, recommendations: recommendations }
      rescue StandardError => e
        Rails.logger.error("Vehicle tire recommendation error: #{e.message}")
        render json: { success: false, error: 'Could not generate recommendations' }, status: :service_unavailable
      end

      # GET /api/v1/ai_recommendations/review_summary/:service_point_id
      # Get AI-generated summary of reviews for a service point
      def review_summary
        service_point = ServicePoint.find_by(id: params[:service_point_id])

        unless service_point
          return render json: { error: 'Service point not found' }, status: :not_found
        end

        summary = moderation_service.summarize_reviews(service_point, limit: params[:limit]&.to_i || 50)

        if summary
          render json: { success: true, summary: summary }
        else
          render json: { success: true, summary: nil, message: 'Not enough reviews for summary' }
        end
      rescue StandardError => e
        Rails.logger.error("Review summary error: #{e.message}")
        render json: { success: false, error: 'Could not generate summary' }, status: :service_unavailable
      end

      # POST /api/v1/ai_recommendations/review_response
      # Generate suggested response for a review (for partners)
      def review_response
        unless current_user.partner? || current_user.admin?
          return render json: { error: 'Only partners can generate review responses' }, status: :forbidden
        end

        review = Review.find_by(id: params[:review_id])

        unless review
          return render json: { error: 'Review not found' }, status: :not_found
        end

        # Check authorization for partners
        if current_user.partner? && review.service_point.partner_id != current_user.partner.id
          return render json: { error: 'Not authorized to respond to this review' }, status: :forbidden
        end

        response = moderation_service.generate_response(review)

        render json: { success: true, response: response }
      rescue StandardError => e
        Rails.logger.error("Review response generation error: #{e.message}")
        render json: { success: false, error: 'Could not generate response' }, status: :service_unavailable
      end

      # GET /api/v1/ai_recommendations/review_sentiment/:review_id
      # Get sentiment analysis for a specific review
      def review_sentiment
        unless current_user.partner? || current_user.admin?
          return render json: { error: 'Only partners and admins can access sentiment analysis' }, status: :forbidden
        end

        review = Review.find_by(id: params[:review_id])

        unless review
          return render json: { error: 'Review not found' }, status: :not_found
        end

        sentiment = moderation_service.analyze_sentiment(review)

        render json: { success: true, sentiment: sentiment }
      rescue StandardError => e
        Rails.logger.error("Sentiment analysis error: #{e.message}")
        render json: { success: false, error: 'Could not analyze sentiment' }, status: :service_unavailable
      end

      # POST /api/v1/ai_recommendations/moderate_review
      # Moderate a review (admin only)
      def moderate_review
        unless current_user.admin?
          return render json: { error: 'Only admins can moderate reviews' }, status: :forbidden
        end

        review = Review.find_by(id: params[:review_id])

        unless review
          return render json: { error: 'Review not found' }, status: :not_found
        end

        moderation_result = moderation_service.moderate(review)

        render json: {
          success: true,
          moderation: moderation_result,
          review_id: review.id
        }
      rescue StandardError => e
        Rails.logger.error("Review moderation error: #{e.message}")
        render json: { success: false, error: 'Could not moderate review' }, status: :service_unavailable
      end

      private

      def seasonal_service
        @seasonal_service ||= SeasonalRecommendationService.new
      end

      def moderation_service
        @moderation_service ||= ReviewModerationService.new
      end
    end
  end
end
