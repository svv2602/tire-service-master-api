class ServicePointService < ApplicationRecord
  belongs_to :service_point
  belongs_to :service
  
  validates :service_point_id, presence: true
  validates :service_id, presence: true
  validates :service_id, uniqueness: { scope: :service_point_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration, presence: true, numericality: { greater_than: 0 }
  validates :is_available, inclusion: { in: [true, false] }
end 