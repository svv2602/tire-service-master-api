class ChangeBookingIdToOptionalInReviews < ActiveRecord::Migration[8.0]
  def change
    # Изменяем поле booking_id с NOT NULL на NULL
    change_column_null :reviews, :booking_id, true
  end
end
