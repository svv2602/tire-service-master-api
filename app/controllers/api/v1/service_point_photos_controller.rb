module Api
  module V1
    class ServicePointPhotosController < ApiController
      before_action :set_service_point
      before_action :set_photo, only: [:show, :update, :destroy]
      
      # GET /api/v1/service_points/:service_point_id/photos
      def index
        authorize @service_point, :show?
        @photos = @service_point.photos.sorted
        
        render json: @photos.map { |photo| photo_json(photo) }
      end
      
      # GET /api/v1/service_points/:service_point_id/photos/:id
      def show
        authorize @service_point, :show?
        render json: photo_json(@photo)
      end
      
      # POST /api/v1/service_points/:service_point_id/photos
      def create
        authorize @service_point, :update?
        
        @photo = @service_point.photos.new(photo_params)
        
        if params[:file].present?
          @photo.file.attach(params[:file])
        end
        
        if @photo.save
          render json: photo_json(@photo), status: :created
        else
          render json: { errors: @photo.errors }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/service_points/:service_point_id/photos/:id
      def update
        authorize @service_point, :update?
        
        if params[:file].present?
          @photo.file.purge
          @photo.file.attach(params[:file])
        end
        
        if @photo.update(photo_update_params)
          render json: photo_json(@photo)
        else
          render json: { errors: @photo.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/service_points/:service_point_id/photos/:id
      def destroy
        authorize @service_point, :update?
        
        if @photo.destroy
          render json: { message: 'Photo was successfully deleted' }
        else
          render json: { errors: @photo.errors }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_service_point
        @service_point = ServicePoint.find(params[:service_point_id])
      end
      
      def set_photo
        @photo = @service_point.photos.find(params[:id])
      end
      
      def photo_params
        params.permit(:sort_order, :description, :is_main)
      end
      
      def photo_update_params
        params.permit(:sort_order, :description, :is_main)
      end
      
      def photo_json(photo)
        {
          id: photo.id,
          url: photo.file.attached? ? url_for(photo.file) : nil,
          description: photo.description,
          is_main: photo.is_main,
          sort_order: photo.sort_order,
          created_at: photo.created_at,
          updated_at: photo.updated_at
        }
      end
    end
  end
end
