class ServicePointSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :address, :latitude, :longitude, :contact_phone, 
             :status, :post_count, :default_slot_duration, :rating, :total_clients_served,
             :average_rating, :cancellation_rate, :created_at, :updated_at
  
  belongs_to :partner
  belongs_to :city
  has_many :photos
  has_many :amenities
  
  def status
    {
      id: object.status.id,
      name: object.status.name,
      color: object.status.color
    }
  end
  
  def photos
    object.photos.sorted.map do |photo|
      {
        id: photo.id,
        url: photo.photo_url,
        sort_order: photo.sort_order
      }
    end
  end
  
  def amenities
    object.amenities.map do |amenity|
      {
        id: amenity.id,
        name: amenity.name,
        icon: amenity.icon
      }
    end
  end
end
