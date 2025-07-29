class PartnerApplicationSerializer < ActiveModel::Serializer
  attributes :id, :company_name, :business_description, :contact_person, 
             :email, :phone, :city, :address, :website, :additional_info,
             :expected_service_points, :status, :admin_notes, :created_at, 
             :updated_at, :processed_at

  # Связанные объекты
  belongs_to :region, serializer: RegionSerializer, if: -> { object.region.present? }
  belongs_to :city_record, serializer: CitySerializer, if: -> { object.city_record.present? }
  belongs_to :processed_by, serializer: UserSerializer, if: -> { object.processed_by.present? }

  # Дополнительные вычисляемые поля
  attribute :status_label
  attribute :status_color
  attribute :full_address
  attribute :region_name
  attribute :city_name
  attribute :processed
  attribute :processing_duration

  def status_label
    object.status_label
  end

  def status_color
    object.status_color
  end

  def full_address
    object.full_address
  end

  def region_name
    object.region_name
  end

  def city_name
    object.city_name
  end

  def processed
    object.processed?
  end

  def processing_duration
    return nil unless object.processed?
    duration = object.processing_duration
    return nil unless duration
    
    # Возвращаем длительность в часах с точностью до 1 знака
    (duration / 1.hour).round(1)
  end

  # Форматирование дат
  def created_at
    object.created_at&.strftime('%d.%m.%Y %H:%M')
  end

  def updated_at
    object.updated_at&.strftime('%d.%m.%Y %H:%M')
  end

  def processed_at
    object.processed_at&.strftime('%d.%m.%Y %H:%M')
  end
end 