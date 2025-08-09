# Базовый сериализатор для поставщиков (без избыточной информации)
class SupplierBasicSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :firm_id, :is_active, :priority
  
  attribute :sync_status do |supplier|
    supplier.sync_status
  end
  
  attribute :products_count do |supplier|
    supplier.products_count
  end
  
  attribute :in_stock_products_count do |supplier|
    supplier.in_stock_products_count
  end
  
  attribute :last_sync_info do |supplier|
    {
      last_sync_at: supplier.last_sync_at&.strftime('%d.%m.%Y %H:%M'),
      sync_status: supplier.sync_status,
      has_recent_sync: supplier.last_sync_at && supplier.last_sync_at > 1.day.ago
    }
  end
end