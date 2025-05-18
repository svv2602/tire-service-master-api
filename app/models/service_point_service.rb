class ServicePointService < ApplicationRecord
  belongs_to :service_point
  belongs_to :service
  
  validates :service_point_id, presence: true
  validates :service_id, presence: true
  validates :service_id, uniqueness: { scope: :service_point_id }
end 