class ServicePointSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :address, :latitude, :longitude, :contact_phone, 
             :is_active, :work_status, :status_display, :post_count, :default_slot_duration, 
             :rating, :total_clients_served, :average_rating, :cancellation_rate, :created_at, :updated_at,
             :posts_count, :service_posts_summary
  
  belongs_to :partner
  belongs_to :city
  has_many :photos
  has_many :amenities
  
  def status_display
    object.display_status
  end
  
  def posts_count
    object.service_posts.active.count
  end
  
  def service_posts_summary
    object.service_posts.active.order(:post_number).map do |post|
      {
        id: post.id,
        post_number: post.post_number,
        name: post.name,
        slot_duration: post.slot_duration,
        is_active: post.is_active
      }
    end
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
