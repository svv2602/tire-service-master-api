class ServicePointSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :address, :latitude, :longitude, :contact_phone, 
             :is_active, :work_status, :status_display, :post_count, :default_slot_duration, 
             :rating, :total_clients_served, :average_rating, :cancellation_rate, :created_at, :updated_at,
             :posts_count, :service_posts_summary, :service_posts, :services, :working_hours,
             :partner_id, :city_id, :category_confirmation_settings,
             # Локализованные поля
             :name_ru, :name_uk, :description_ru, :description_uk, :address_ru, :address_uk,
             :localized_name, :localized_description, :localized_address
  
  belongs_to :partner
  belongs_to :city
  has_many :photos
  has_many :amenities
  
  def status_display
    object.display_status
  end
  
  def posts_count
    cached_active_posts.size
  end

  def service_posts_summary
    cached_active_posts.map do |post|
      {
        id: post.id,
        post_number: post.post_number,
        name: post.name,
        slot_duration: post.slot_duration,
        is_active: post.is_active
      }
    end
  end

  def service_posts
    locale = instance_options[:locale]
    object.service_posts.order(:post_number).map do |post|
      ServicePostSerializer.new(post, locale: locale).as_json
    end
  end

  private

  # Memoized collection of active posts — avoids 3 duplicate queries per service point.
  def cached_active_posts
    @cached_active_posts ||= object.service_posts.active.order(:post_number)
  end
  
  def services
    object.service_point_services.includes(:service).map do |service_point_service|
      {
        id: service_point_service.id,
        service_id: service_point_service.service_id,
        price: service_point_service.price,
        duration: service_point_service.duration,
        is_available: service_point_service.is_available,
        service: {
          id: service_point_service.service.id,
          name: service_point_service.service.name,
          category: service_point_service.service.category ? {
            id: service_point_service.service.category.id,
            name: service_point_service.service.category.name
          } : nil
        }
      }
    end
  end
  
  def photos
    object.photos.sorted.map do |photo|
      {
        id: photo.id,
        url: photo.file.attached? ? Rails.application.routes.url_helpers.url_for(photo.file) : nil,
        description: photo.description,
        is_main: photo.is_main,
        sort_order: photo.sort_order,
        created_at: photo.created_at,
        updated_at: photo.updated_at
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
  
  def working_hours
    return {} unless object.working_hours
    
    normalized = {}
    object.working_hours.each do |day, hours|
      if hours.is_a?(Hash)
        normalized[day] = {
          start: hours['start'],
          end: hours['end'],
          is_working_day: hours['is_working_day'] == true || hours['is_working_day'] == 'true'
        }
      end
    end
    normalized
  end
  
  # Методы локализации согласно TABLE_LOCALIZATION_RULES.md
  def localized_name
    locale = instance_options[:locale] || 'ru'
    object.localized_name(locale)
  end
  
  def localized_description
    locale = instance_options[:locale] || 'ru'
    object.localized_description(locale)
  end
  
  def localized_address
    locale = instance_options[:locale] || 'ru'
    object.localized_address(locale)
  end
  
  # Настройки автоподтверждения по категориям
  def category_confirmation_settings
    object.category_auto_confirmation_settings
  end
end
