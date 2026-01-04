# frozen_string_literal: true

module Api
  module V1
    # SupplierReportsController - handles report downloads via token
    class SupplierReportsController < ApplicationController
      # Skip authentication - tokens are self-validating
      skip_before_action :authenticate_request, only: [:download]

      # GET /api/v1/supplier_reports/download/:token
      def download
        token = params[:token]

        # Fetch report data from cache
        report_data = Rails.cache.read("supplier_report:#{token}")

        unless report_data
          return render json: { error: 'Отчёт не найден или ссылка устарела' }, status: :not_found
        end

        # Check expiration
        if report_data[:expires_at] && Time.current > report_data[:expires_at]
          Rails.cache.delete("supplier_report:#{token}")
          return render json: { error: 'Срок действия ссылки истёк' }, status: :gone
        end

        filepath = report_data[:filepath]
        filename = report_data[:filename]

        # Verify file exists
        unless File.exist?(filepath)
          Rails.cache.delete("supplier_report:#{token}")
          return render json: { error: 'Файл отчёта не найден' }, status: :not_found
        end

        # Determine content type
        content_type = case File.extname(filename).downcase
                       when '.csv' then 'text/csv; charset=utf-8'
                       when '.xlsx' then 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                       else 'application/octet-stream'
                       end

        # Log download
        Rails.logger.info "Report downloaded: #{filename} by supplier #{report_data[:supplier_id]}"

        # Send file
        send_file filepath,
                  filename: filename,
                  type: content_type,
                  disposition: 'attachment'
      end
    end
  end
end
