# frozen_string_literal: true

# GenerateSupplierReportJob - generates large supplier reports in background
class GenerateSupplierReportJob < ApplicationJob
  queue_as :reports

  # Handle permanently failed jobs
  sidekiq_retries_exhausted do |msg, _ex|
    Rails.logger.error "[GenerateSupplierReportJob] Permanently failed: #{msg['error_message']}"
    SystemLog.create(
      action: 'job_permanently_failed',
      resource_type: 'GenerateSupplierReportJob',
      resource_id: msg['args']&.first,
      additional_data: { error: msg['error_message'], job_id: msg['jid'], args: msg['args'] }
    ) rescue nil
    AdminNotificationService.notify_job_permanently_failed(
      job_class: 'GenerateSupplierReportJob',
      error_message: msg['error_message'],
      job_id: msg['jid']
    ) if defined?(AdminNotificationService)
  end

  # Download links expire after 24 hours
  LINK_EXPIRATION = 24.hours

  def perform(supplier_id, params)
    supplier = Supplier.find(supplier_id)

    report_service = SupplierReportService.new(supplier, params.symbolize_keys)
    report_data = report_service.generate

    # Store report temporarily
    filename = "supplier_report_#{supplier.firm_id}_#{Date.current.strftime('%Y%m%d')}.#{params['format'] || params[:format]}"
    filepath = Rails.root.join('tmp', 'reports', filename)

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(filepath))

    # Write report file
    File.open(filepath, 'wb') do |file|
      file.write(report_data)
    end

    # Create download token
    token = SecureRandom.urlsafe_base64(32)
    expires_at = Time.current + LINK_EXPIRATION

    # Store token in cache
    Rails.cache.write(
      "supplier_report:#{token}",
      {
        filepath: filepath.to_s,
        filename: filename,
        supplier_id: supplier_id,
        expires_at: expires_at
      },
      expires_in: LINK_EXPIRATION
    )

    # Notify supplier
    download_url = Rails.application.routes.url_helpers.download_supplier_report_url(
      token: token,
      host: ENV.fetch('APP_HOST', 'localhost:8000')
    )

    SupplierNotificationService.new(supplier).notify_report_ready(download_url, filename)

    Rails.logger.info "Report generated for supplier #{supplier_id}: #{filename}"

    { success: true, token: token, expires_at: expires_at }
  rescue StandardError => e
    Rails.logger.error "Failed to generate report for supplier #{supplier_id}: #{e.message}"

    # Notify about failure
    supplier = Supplier.find_by(id: supplier_id)
    SupplierNotificationService.new(supplier).notify_price_upload_failed("Ошибка генерации отчёта: #{e.message}") if supplier

    raise e
  end
end
