# Phase-03: Add composite indexes for frequently used query patterns.
# These indexes cover the most common filter combinations identified in the codebase:
#   - bookings: filtered by service_point + date + status
#   - tire_orders: filtered by supplier + status
#   - supplier_tire_products: filtered by supplier + stock + brand
class AddCompositeIndexesForCommonQueries < ActiveRecord::Migration[8.0]
  def change
    # Bookings: common filter — service_point + booking_date + status
    # Used in partner dashboards, schedule views, conflict checks
    unless index_exists?(:bookings, [:service_point_id, :booking_date, :status], name: 'idx_bookings_point_date_status')
      add_index :bookings, [:service_point_id, :booking_date, :status],
                name: 'idx_bookings_point_date_status'
    end

    # Tire orders: supplier dashboard filters by status
    # Already exists as index_tire_orders_on_supplier_id_and_status — skip if present
    unless index_exists?(:tire_orders, [:supplier_id, :status])
      add_index :tire_orders, [:supplier_id, :status],
                name: 'idx_tire_orders_supplier_status'
    end

    # Supplier tire products: catalog browsing — supplier + in_stock + brand
    # The existing idx_supplier_products_normalized_search covers (tire_brand_id, width, height, diameter, season, in_stock)
    # but not supplier_id + in_stock + tire_brand_id for supplier-specific catalog views
    unless index_exists?(:supplier_tire_products, [:supplier_id, :in_stock, :tire_brand_id], name: 'idx_stp_supplier_stock_brand')
      add_index :supplier_tire_products, [:supplier_id, :in_stock, :tire_brand_id],
                name: 'idx_stp_supplier_stock_brand'
    end

    # Additional: bookings by client_id + booking_date for client history views
    unless index_exists?(:bookings, [:client_id, :booking_date], name: 'idx_bookings_client_date')
      add_index :bookings, [:client_id, :booking_date],
                name: 'idx_bookings_client_date'
    end

    # Additional: reviews by service_point_id + created_at for recent reviews queries
    unless index_exists?(:reviews, [:service_point_id, :created_at], name: 'idx_reviews_point_created')
      add_index :reviews, [:service_point_id, :created_at],
                name: 'idx_reviews_point_created'
    end

    # Additional: orders by service_point_id + order_date for partner order history
    unless index_exists?(:orders, [:service_point_id, :order_date], name: 'idx_orders_point_date')
      add_index :orders, [:service_point_id, :order_date],
                name: 'idx_orders_point_date'
    end
  end
end
