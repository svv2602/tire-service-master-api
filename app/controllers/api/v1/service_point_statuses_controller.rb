module Api
  module V1
    class ServicePointStatusesController < ApplicationController
      def index
        @statuses = ServicePointStatus.active.sorted
        render json: @statuses
      end
    end
  end
end 