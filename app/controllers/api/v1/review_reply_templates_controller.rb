# frozen_string_literal: true

module Api
  module V1
    # Controller for managing review reply templates
    class ReviewReplyTemplatesController < ApplicationController
      skip_after_action :verify_authorized
      before_action :authenticate_user!
      before_action :authorize_partner_or_admin!
      before_action :set_template, only: [:show, :update, :destroy]

      # GET /api/v1/review_reply_templates
      def index
        @templates = fetch_templates
        render json: {
          data: @templates.map { |t| template_json(t) },
          total_count: @templates.count,
          categories: ReviewReplyTemplate::CATEGORIES
        }
      end

      # GET /api/v1/review_reply_templates/:id
      def show
        render json: { data: template_json(@template) }
      end

      # POST /api/v1/review_reply_templates
      def create
        @template = ReviewReplyTemplate.new(template_params)

        # Only admins can create global templates
        if @template.partner_id.nil? && !current_user.admin?
          @template.partner_id = current_partner&.id
        end

        if @template.save
          render json: { data: template_json(@template), message: 'Template created successfully' }, status: :created
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/review_reply_templates/:id
      def update
        if @template.update(template_params)
          render json: { data: template_json(@template), message: 'Template updated successfully' }
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/review_reply_templates/:id
      def destroy
        if @template.destroy
          render json: { message: 'Template deleted successfully' }
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/review_reply_templates/:id/use
      # Increment usage counter when a template is used
      def use
        @template = ReviewReplyTemplate.find(params[:id])
        @template.increment_usage!
        render json: {
          data: template_json(@template),
          content: @template.content
        }
      end

      private

      def set_template
        @template = ReviewReplyTemplate.find(params[:id])

        # Check if user can access this template
        unless can_access_template?(@template)
          render json: { error: 'Not authorized to access this template' }, status: :forbidden
        end
      end

      def fetch_templates
        scope = ReviewReplyTemplate.active.ordered

        if current_user.admin?
          # Admins can see all templates
          scope = scope.all
        else
          # Partners can see global templates and their own
          scope = scope.available_for_partner(current_partner&.id)
        end

        # Filter by category if provided
        scope = scope.by_category(params[:category]) if params[:category].present?

        # Filter by search query
        if params[:query].present?
          scope = scope.where('name ILIKE ? OR content ILIKE ?', "%#{params[:query]}%", "%#{params[:query]}%")
        end

        scope
      end

      def can_access_template?(template)
        return true if current_user.admin?
        return true if template.global?
        template.partner_id == current_partner&.id
      end

      def authorize_partner_or_admin!
        unless current_user.admin? || current_user.partner? || current_user.manager?
          render json: { error: 'Not authorized' }, status: :forbidden
        end
      end

      def current_partner
        @current_partner ||= current_user.partner
      end

      def template_params
        params.require(:review_reply_template).permit(
          :name, :content, :category, :is_active, :sort_order, :partner_id
        )
      end

      def template_json(template)
        {
          id: template.id,
          name: template.name,
          content: template.content,
          category: template.category,
          category_display_name: template.category_display_name,
          is_active: template.is_active,
          is_global: template.global?,
          partner_id: template.partner_id,
          sort_order: template.sort_order,
          usage_count: template.usage_count,
          created_at: template.created_at,
          updated_at: template.updated_at
        }
      end
    end
  end
end
