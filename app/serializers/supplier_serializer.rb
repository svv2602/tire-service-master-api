# Основной сериализатор для поставщиков
class SupplierSerializer
  include JSONAPI::Serializer
  
  attributes :id, :name, :firm_id, :is_active, :priority, :created_at, :updated_at
  
  attribute :sync_status do |supplier|
    'synced' # Статус синхронизации по умолчанию
  end
  
  attribute :products_count do |supplier|
    supplier.supplier_tire_products.count
  end
  
  attribute :in_stock_products_count do |supplier|
    supplier.supplier_tire_products.where('stock_quantity > 0').count
  end
  
  attribute :last_sync_info do |supplier|
    {
      last_sync_at: supplier.updated_at&.strftime('%d.%m.%Y %H:%M'),
      sync_status: 'synced',
      has_recent_sync: supplier.updated_at && supplier.updated_at > 1.day.ago
    }
  end
end