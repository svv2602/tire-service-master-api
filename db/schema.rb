# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_05_19_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "administrators", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "position"
    t.integer "access_level", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_administrators_on_user_id", unique: true
  end

  create_table "amenities", force: :cascade do |t|
    t.string "name", null: false
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "booking_services", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "service_id", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "quantity", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_booking_services_on_booking_id"
    t.index ["service_id"], name: "index_booking_services_on_service_id"
  end

  create_table "booking_statuses", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "color", limit: 7
    t.boolean "is_active", default: true
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_booking_statuses_on_name", unique: true
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "service_point_id", null: false
    t.bigint "car_id"
    t.bigint "slot_id", null: false
    t.date "booking_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.integer "status_id"
    t.integer "payment_status_id"
    t.bigint "cancellation_reason_id"
    t.text "cancellation_comment"
    t.decimal "total_price", precision: 10, scale: 2
    t.string "payment_method"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "car_type_id", null: false
    t.index ["cancellation_reason_id"], name: "index_bookings_on_cancellation_reason_id"
    t.index ["car_id"], name: "index_bookings_on_car_id"
    t.index ["car_type_id"], name: "index_bookings_on_car_type_id"
    t.index ["client_id"], name: "index_bookings_on_client_id"
    t.index ["payment_status_id"], name: "index_bookings_on_payment_status_id"
    t.index ["service_point_id"], name: "index_bookings_on_service_point_id"
    t.index ["slot_id"], name: "index_bookings_on_slot_id"
    t.index ["status_id"], name: "index_bookings_on_status_id"
  end

  create_table "cancellation_reasons", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "is_for_client", default: true
    t.boolean "is_for_partner", default: true
    t.boolean "is_active", default: true
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "car_brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "logo"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_car_brands_on_name", unique: true
  end

  create_table "car_models", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "name"], name: "index_car_models_on_brand_id_and_name", unique: true
    t.index ["brand_id"], name: "index_car_models_on_brand_id"
  end

  create_table "car_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_car_types_on_name", unique: true
  end

  create_table "cities", force: :cascade do |t|
    t.bigint "region_id", null: false
    t.string "name", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["region_id", "name"], name: "index_cities_on_region_id_and_name", unique: true
    t.index ["region_id"], name: "index_cities_on_region_id"
  end

  create_table "client_cars", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "brand_id", null: false
    t.bigint "model_id", null: false
    t.integer "year"
    t.bigint "tire_type_id"
    t.string "tire_size"
    t.text "notes"
    t.boolean "is_primary", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "car_type_id"
    t.index ["brand_id"], name: "index_client_cars_on_brand_id"
    t.index ["car_type_id"], name: "index_client_cars_on_car_type_id"
    t.index ["client_id"], name: "index_client_cars_on_client_id"
    t.index ["model_id"], name: "index_client_cars_on_model_id"
    t.index ["tire_type_id"], name: "index_client_cars_on_tire_type_id"
  end

  create_table "client_favorite_points", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "service_point_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "service_point_id"], name: "idx_unique_client_favorite_point", unique: true
    t.index ["client_id"], name: "index_client_favorite_points_on_client_id"
    t.index ["service_point_id"], name: "index_client_favorite_points_on_service_point_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "preferred_notification_method", default: "push"
    t.boolean "marketing_consent", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_clients_on_user_id", unique: true
  end

  create_table "manager_service_points", force: :cascade do |t|
    t.bigint "manager_id", null: false
    t.bigint "service_point_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["manager_id", "service_point_id"], name: "idx_unique_manager_service_point", unique: true
    t.index ["manager_id"], name: "index_manager_service_points_on_manager_id"
    t.index ["service_point_id"], name: "index_manager_service_points_on_service_point_id"
  end

  create_table "managers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "partner_id", null: false
    t.integer "access_level", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "position"
    t.index ["partner_id"], name: "index_managers_on_partner_id"
    t.index ["user_id"], name: "index_managers_on_user_id", unique: true
  end

  create_table "notification_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "template"
    t.boolean "is_push", default: false
    t.boolean "is_email", default: false
    t.boolean "is_sms", default: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "notification_type_id", null: false
    t.string "recipient_type", null: false
    t.integer "recipient_id", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "send_via", null: false
    t.datetime "sent_at"
    t.datetime "read_at"
    t.boolean "is_read", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_read"], name: "index_notifications_on_is_read"
    t.index ["notification_type_id"], name: "index_notifications_on_notification_type_id"
    t.index ["recipient_type", "recipient_id"], name: "idx_notifications_recipient"
    t.index ["sent_at"], name: "index_notifications_on_sent_at"
  end

  create_table "partners", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "company_name", null: false
    t.text "company_description"
    t.string "contact_person"
    t.string "logo_url"
    t.string "website"
    t.string "tax_number"
    t.text "legal_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: true
    t.index ["company_name"], name: "index_partners_on_company_name"
    t.index ["is_active"], name: "index_partners_on_is_active"
    t.index ["user_id"], name: "index_partners_on_user_id", unique: true
  end

  create_table "payment_statuses", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "color", limit: 7
    t.boolean "is_active", default: true
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "price_list_items", force: :cascade do |t|
    t.bigint "price_list_id", null: false
    t.bigint "service_id", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "discount_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["price_list_id", "service_id"], name: "index_price_list_items_on_price_list_id_and_service_id", unique: true
    t.index ["price_list_id"], name: "index_price_list_items_on_price_list_id"
    t.index ["service_id"], name: "index_price_list_items_on_service_id"
  end

  create_table "price_lists", force: :cascade do |t|
    t.bigint "partner_id", null: false
    t.bigint "service_point_id"
    t.string "name", null: false
    t.string "season"
    t.date "start_date"
    t.date "end_date"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.index ["partner_id"], name: "index_price_lists_on_partner_id"
    t.index ["service_point_id"], name: "index_price_lists_on_service_point_id"
    t.index ["start_date", "end_date"], name: "idx_price_lists_date_range"
  end

  create_table "promotions", force: :cascade do |t|
    t.bigint "partner_id", null: false
    t.bigint "service_point_id"
    t.string "title", null: false
    t.text "description"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "discount_percent"
    t.decimal "discount_amount", precision: 10, scale: 2
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partner_id"], name: "index_promotions_on_partner_id"
    t.index ["service_point_id"], name: "index_promotions_on_service_point_id"
    t.index ["start_date", "end_date"], name: "idx_promotions_date_range"
  end

  create_table "regions", force: :cascade do |t|
    t.string "name", null: false
    t.string "code"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_regions_on_code", unique: true
    t.index ["name"], name: "index_regions_on_name", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.bigint "client_id", null: false
    t.bigint "service_point_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.text "partner_response"
    t.boolean "is_published", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_reviews_on_booking_id"
    t.index ["client_id"], name: "index_reviews_on_client_id"
    t.index ["service_point_id"], name: "index_reviews_on_service_point_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "check_rating_range"
  end

  create_table "schedule_exceptions", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.date "exception_date", null: false
    t.boolean "is_closed", default: true
    t.time "opening_time"
    t.time "closing_time"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_point_id", "exception_date"], name: "idx_unique_service_point_exception_date", unique: true
    t.index ["service_point_id"], name: "index_schedule_exceptions_on_service_point_id"
  end

  create_table "schedule_slots", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.date "slot_date", null: false
    t.time "start_time", null: false
    t.time "end_time", null: false
    t.integer "post_number", null: false
    t.boolean "is_available", default: true
    t.boolean "is_special", default: false
    t.string "special_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_available"], name: "idx_schedule_slots_availability"
    t.index ["service_point_id", "slot_date", "start_time", "post_number"], name: "idx_unique_slot", unique: true
    t.index ["service_point_id"], name: "index_schedule_slots_on_service_point_id"
  end

  create_table "schedule_templates", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.bigint "weekday_id", null: false
    t.time "opening_time", null: false
    t.time "closing_time", null: false
    t.boolean "is_working_day", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_point_id", "weekday_id"], name: "idx_unique_service_point_weekday", unique: true
    t.index ["service_point_id"], name: "index_schedule_templates_on_service_point_id"
    t.index ["weekday_id"], name: "index_schedule_templates_on_weekday_id"
  end

  create_table "service_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "icon_url"
    t.integer "sort_order", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_service_categories_on_name", unique: true
  end

  create_table "service_point_amenities", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.bigint "amenity_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amenity_id"], name: "index_service_point_amenities_on_amenity_id"
    t.index ["service_point_id", "amenity_id"], name: "idx_unique_service_point_amenity", unique: true
    t.index ["service_point_id"], name: "index_service_point_amenities_on_service_point_id"
  end

  create_table "service_point_photos", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.string "photo_url", null: false
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_point_id"], name: "index_service_point_photos_on_service_point_id"
  end

  create_table "service_point_services", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_service_point_services_on_service_id"
    t.index ["service_point_id", "service_id"], name: "idx_service_point_services_unique", unique: true
    t.index ["service_point_id"], name: "index_service_point_services_on_service_point_id"
  end

  create_table "service_point_statuses", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "color", limit: 7
    t.boolean "is_active", default: true
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_service_point_statuses_on_name", unique: true
  end

  create_table "service_points", force: :cascade do |t|
    t.bigint "partner_id", null: false
    t.string "name", null: false
    t.text "description"
    t.bigint "city_id", null: false
    t.text "address", null: false
    t.decimal "latitude", precision: 10, scale: 8
    t.decimal "longitude", precision: 11, scale: 8
    t.string "contact_phone"
    t.bigint "status_id", default: 1, null: false
    t.integer "post_count", default: 1
    t.integer "default_slot_duration", default: 60
    t.decimal "rating", precision: 3, scale: 2, default: "0.0"
    t.integer "total_clients_served", default: 0
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.decimal "cancellation_rate", precision: 5, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_service_points_on_city_id"
    t.index ["latitude", "longitude"], name: "idx_service_points_location"
    t.index ["partner_id"], name: "index_service_points_on_partner_id"
    t.index ["status_id"], name: "index_service_points_on_status_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "default_duration", default: 60
    t.integer "sort_order", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_services_on_category_id"
  end

  create_table "system_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "entity_type"
    t.integer "entity_id"
    t.jsonb "old_value"
    t.jsonb "new_value"
    t.string "ip_address", limit: 45
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_system_logs_on_action"
    t.index ["created_at"], name: "index_system_logs_on_created_at"
    t.index ["entity_type", "entity_id"], name: "idx_system_logs_entity"
    t.index ["user_id"], name: "index_system_logs_on_user_id"
  end

  create_table "tire_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_roles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_user_roles_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "phone"
    t.string "password_digest", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.bigint "role_id", null: false
    t.datetime "last_login"
    t.boolean "is_active", default: true
    t.boolean "email_verified", default: false
    t.boolean "phone_verified", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "weekdays", force: :cascade do |t|
    t.string "name", null: false
    t.string "short_name", limit: 3, null: false
    t.integer "sort_order", null: false
  end

  add_foreign_key "administrators", "users"
  add_foreign_key "booking_services", "bookings"
  add_foreign_key "booking_services", "services"
  add_foreign_key "bookings", "booking_statuses", column: "status_id", on_delete: :restrict, validate: false
  add_foreign_key "bookings", "cancellation_reasons"
  add_foreign_key "bookings", "car_types"
  add_foreign_key "bookings", "client_cars", column: "car_id"
  add_foreign_key "bookings", "clients"
  add_foreign_key "bookings", "payment_statuses", on_delete: :restrict, validate: false
  add_foreign_key "bookings", "schedule_slots", column: "slot_id"
  add_foreign_key "bookings", "service_points"
  add_foreign_key "car_models", "car_brands", column: "brand_id"
  add_foreign_key "cities", "regions"
  add_foreign_key "client_cars", "car_brands", column: "brand_id"
  add_foreign_key "client_cars", "car_models", column: "model_id"
  add_foreign_key "client_cars", "car_types"
  add_foreign_key "client_cars", "clients"
  add_foreign_key "client_cars", "tire_types"
  add_foreign_key "client_favorite_points", "clients"
  add_foreign_key "client_favorite_points", "service_points"
  add_foreign_key "clients", "users"
  add_foreign_key "manager_service_points", "managers"
  add_foreign_key "manager_service_points", "service_points"
  add_foreign_key "managers", "partners"
  add_foreign_key "managers", "users"
  add_foreign_key "notifications", "notification_types"
  add_foreign_key "partners", "users"
  add_foreign_key "price_list_items", "price_lists"
  add_foreign_key "price_list_items", "services"
  add_foreign_key "price_lists", "partners"
  add_foreign_key "price_lists", "service_points"
  add_foreign_key "promotions", "partners"
  add_foreign_key "promotions", "service_points"
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "clients"
  add_foreign_key "reviews", "service_points"
  add_foreign_key "schedule_exceptions", "service_points"
  add_foreign_key "schedule_slots", "service_points"
  add_foreign_key "schedule_templates", "service_points"
  add_foreign_key "schedule_templates", "weekdays"
  add_foreign_key "service_point_amenities", "amenities"
  add_foreign_key "service_point_amenities", "service_points"
  add_foreign_key "service_point_photos", "service_points"
  add_foreign_key "service_point_services", "service_points"
  add_foreign_key "service_point_services", "services"
  add_foreign_key "service_points", "cities"
  add_foreign_key "service_points", "partners"
  add_foreign_key "service_points", "service_point_statuses", column: "status_id"
  add_foreign_key "services", "service_categories", column: "category_id"
  add_foreign_key "system_logs", "users"
  add_foreign_key "users", "user_roles", column: "role_id"
end
