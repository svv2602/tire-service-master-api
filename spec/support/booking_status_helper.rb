module BookingStatusHelper
  def ensure_booking_statuses_exist
    %w[pending confirmed completed canceled_by_client canceled_by_partner no_show].each do |status|
      BookingStatus.find_or_create_by!(name: status)
    end
  end

  def create_booking_with_status(status, service_point:)
    client = create(:client)
    booking_status = BookingStatus.find_by!(name: status)
    create(:booking, 
      client: client,
      service_point: service_point,
      booking_status: booking_status,
      start_time: Time.current,
      end_time: Time.current + 1.hour
    )
  end
end

RSpec.configure do |config|
  config.include BookingStatusHelper
end 