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

ActiveRecord::Schema[8.0].define(version: 2025_08_05_103803) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.string "name_uk"
    t.index ["name_uk"], name: "index_amenities_on_name_uk"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", limit: 255, null: false, comment: "Заголовок статьи на русском языке"
    t.text "content", null: false, comment: "Содержимое статьи на русском языке"
    t.text "excerpt", comment: "Краткое описание статьи на русском языке"
    t.string "category", limit: 50, default: "tips", null: false
    t.string "status", limit: 20, default: "draft", null: false
    t.boolean "featured", default: false
    t.string "meta_title", limit: 60, comment: "SEO заголовок на русском языке"
    t.text "meta_description", comment: "SEO описание на русском языке"
    t.string "slug", limit: 255
    t.bigint "author_id", null: false
    t.datetime "published_at"
    t.integer "views_count", default: 0
    t.integer "reading_time", default: 1
    t.string "featured_image_url"
    t.json "gallery_images"
    t.boolean "allow_comments", default: true
    t.json "tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title_uk", limit: 255, comment: "Заголовок статьи на украинском языке"
    t.text "content_uk", comment: "Содержимое статьи на украинском языке"
    t.text "excerpt_uk", comment: "Краткое описание статьи на украинском языке"
    t.string "meta_title_uk", limit: 60, comment: "SEO заголовок на украинском языке"
    t.text "meta_description_uk", comment: "SEO описание на украинском языке"
    t.index ["author_id"], name: "index_articles_on_author_id"
    t.index ["category", "status"], name: "index_articles_on_category_and_status"
    t.index ["category"], name: "index_articles_on_category"
    t.index ["featured"], name: "index_articles_on_featured"
    t.index ["published_at"], name: "index_articles_on_published_at"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
    t.index ["status", "published_at"], name: "index_articles_on_status_and_published_at"
    t.index ["status"], name: "index_articles_on_status"
    t.index ["title", "title_uk"], name: "index_articles_on_localized_titles"
    t.index ["title_uk"], name: "index_articles_on_title_uk"
  end

  create_table "booking_conflicts", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.string "conflict_type", null: false
    t.text "conflict_reason", null: false
    t.datetime "detected_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "resolved_at"
    t.string "resolution_type"
    t.text "resolution_notes"
    t.bigint "resolved_by_id"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "status"], name: "index_booking_conflicts_on_booking_id_and_status"
    t.index ["booking_id"], name: "index_booking_conflicts_on_booking_id"
    t.index ["conflict_type"], name: "index_booking_conflicts_on_conflict_type"
    t.index ["detected_at"], name: "index_booking_conflicts_on_detected_at"
    t.index ["resolved_by_id"], name: "index_booking_conflicts_on_resolved_by_id"
    t.index ["status"], name: "index_booking_conflicts_on_status"
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
    t.bigint "client_id"
    t.bigint "service_point_id", null: false
    t.bigint "car_id"
    t.date "booking_date", null: false
    t.time "start_time", null: false
    t.time "end_time", comment: "Время окончания бронирования. NULL в слотовой архитектуре - заполняется при назначении поста"
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
    t.string "service_recipient_first_name", comment: "Имя получателя услуги"
    t.string "service_recipient_last_name", comment: "Фамилия получателя услуги"
    t.string "service_recipient_phone", comment: "Телефон получателя услуги для связи"
    t.string "service_recipient_email", comment: "Email получателя услуги (опционально)"
    t.bigint "service_category_id"
    t.string "car_brand", comment: "Марка автомобиля для гостевых бронирований"
    t.string "car_model", comment: "Модель автомобиля для гостевых бронирований"
    t.string "license_plate", comment: "Номер автомобиля для гостевых бронирований"
    t.string "status", default: "pending", null: false
    t.boolean "is_service_booking", default: false, null: false
    t.index ["booking_date", "start_time", "end_time"], name: "idx_bookings_time_range"
    t.index ["cancellation_reason_id"], name: "index_bookings_on_cancellation_reason_id"
    t.index ["car_brand", "car_model"], name: "index_bookings_on_car_brand_model"
    t.index ["car_id"], name: "index_bookings_on_car_id"
    t.index ["car_type_id"], name: "index_bookings_on_car_type_id"
    t.index ["client_id", "status", "booking_date"], name: "idx_bookings_client_status_date"
    t.index ["client_id"], name: "index_bookings_guest_only", where: "(client_id IS NULL)"
    t.index ["client_id"], name: "index_bookings_on_client_id"
    t.index ["is_service_booking"], name: "index_bookings_on_is_service_booking"
    t.index ["license_plate"], name: "index_bookings_on_license_plate"
    t.index ["payment_status_id"], name: "index_bookings_on_payment_status_id"
    t.index ["service_category_id"], name: "index_bookings_on_service_category_id"
    t.index ["service_point_id", "booking_date", "start_time"], name: "idx_bookings_service_point_date_time"
    t.index ["service_point_id", "booking_date"], name: "idx_bookings_point_date"
    t.index ["service_point_id", "status", "booking_date", "start_time"], name: "idx_bookings_complex_filter"
    t.index ["service_point_id", "status"], name: "idx_bookings_point_status"
    t.index ["service_point_id"], name: "index_bookings_on_service_point_id"
    t.index ["service_recipient_phone"], name: "index_bookings_on_guest_phone"
    t.index ["service_recipient_phone"], name: "index_bookings_on_service_recipient_phone"
    t.index ["status"], name: "index_bookings_on_status"
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
    t.string "name_uk"
    t.index ["name"], name: "index_car_brands_on_name", unique: true
    t.index ["name_uk"], name: "index_car_brands_on_name_uk"
  end

  create_table "car_models", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_uk"
    t.index ["brand_id", "name"], name: "index_car_models_on_brand_id_and_name", unique: true
    t.index ["brand_id"], name: "index_car_models_on_brand_id"
    t.index ["name_uk"], name: "index_car_models_on_name_uk"
  end

  create_table "car_tire_configurations", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "model_id", null: false
    t.integer "year_from"
    t.integer "year_to"
    t.jsonb "tire_sizes"
    t.jsonb "search_aliases"
    t.text "search_tokens"
    t.string "data_version", default: "2025.1"
    t.string "source_file"
    t.datetime "last_updated"
    t.boolean "is_deprecated", default: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('russian'::regconfig, search_tokens)", name: "index_car_tire_configurations_on_search_tokens_fulltext", using: :gin
    t.index ["brand_id", "model_id"], name: "index_car_tire_configurations_on_brand_id_and_model_id"
    t.index ["brand_id"], name: "index_car_tire_configurations_on_brand_id"
    t.index ["data_version"], name: "index_car_tire_configurations_on_data_version"
    t.index ["is_active"], name: "index_car_tire_configurations_on_is_active"
    t.index ["is_deprecated"], name: "index_car_tire_configurations_on_is_deprecated"
    t.index ["model_id"], name: "index_car_tire_configurations_on_model_id"
    t.index ["search_aliases"], name: "index_car_tire_configurations_on_search_aliases", opclass: :jsonb_path_ops, using: :gin
    t.index ["tire_sizes"], name: "index_car_tire_configurations_on_tire_sizes", opclass: :jsonb_path_ops, using: :gin
  end

  create_table "car_types", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_uk"
    t.text "description_uk"
    t.index ["name"], name: "index_car_types_on_name", unique: true
  end

  create_table "cars", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "car_type_id", null: false
    t.string "brand"
    t.string "model"
    t.integer "year"
    t.string "license_plate"
    t.string "vin"
    t.string "color"
    t.text "notes"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["car_type_id"], name: "index_cars_on_car_type_id"
    t.index ["client_id"], name: "index_cars_on_client_id"
  end

  create_table "cities", force: :cascade do |t|
    t.bigint "region_id", null: false
    t.string "name", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_uk"
    t.string "name_ru"
    t.index ["name_ru"], name: "index_cities_on_name_ru"
    t.index ["name_uk"], name: "index_cities_on_name_uk"
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
    t.string "license_plate"
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

  create_table "countries", force: :cascade do |t|
    t.string "name", limit: 100, null: false, comment: "Каноничное название страны"
    t.string "normalized_name", limit: 100, null: false, comment: "Нормализованное название для поиска"
    t.string "iso_code", limit: 3, comment: "ISO код страны (DE, CN, JP)"
    t.integer "rating_score", default: 5, comment: "Рейтинг качества производства (1-10)"
    t.text "aliases", default: [], comment: "Альтернативные названия", array: true
    t.boolean "is_active", default: true, comment: "Активность справочника"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_countries_on_aliases", using: :gin
    t.index ["iso_code"], name: "index_countries_on_iso_code"
    t.index ["normalized_name"], name: "index_countries_on_normalized_name", unique: true
    t.index ["rating_score"], name: "index_countries_on_rating_score"
  end

  create_table "custom_variables", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.text "description"
    t.string "example_value", limit: 255
    t.string "category", limit: 50, null: false
    t.boolean "is_active", default: true, null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "is_active"], name: "index_custom_variables_on_category_and_is_active"
    t.index ["category"], name: "index_custom_variables_on_category"
    t.index ["created_by_id"], name: "index_custom_variables_on_created_by_id"
    t.index ["is_active"], name: "index_custom_variables_on_is_active"
    t.index ["name"], name: "index_custom_variables_on_name", unique: true
  end

  create_table "email_settings", force: :cascade do |t|
    t.string "smtp_host"
    t.integer "smtp_port", default: 587
    t.string "smtp_username"
    t.string "smtp_password"
    t.string "smtp_authentication", default: "plain"
    t.boolean "smtp_starttls_auto", default: true, null: false
    t.boolean "smtp_tls", default: false, null: false
    t.string "from_email"
    t.string "from_name"
    t.boolean "enabled", default: false, null: false
    t.boolean "test_mode", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "openssl_verify_mode", default: "none"
  end

  create_table "email_template_custom_variables", force: :cascade do |t|
    t.bigint "email_template_id", null: false
    t.bigint "custom_variable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_variable_id"], name: "index_email_template_custom_variables_on_custom_variable_id"
    t.index ["email_template_id", "custom_variable_id"], name: "index_template_custom_vars_unique", unique: true
    t.index ["email_template_id"], name: "index_email_template_custom_variables_on_email_template_id"
  end

  create_table "email_templates", force: :cascade do |t|
    t.string "name"
    t.string "subject"
    t.text "body"
    t.string "template_type"
    t.string "language"
    t.boolean "is_active"
    t.text "variables"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "channel_type", default: "email", null: false
    t.index ["channel_type"], name: "index_email_templates_on_channel_type"
    t.index ["template_type", "language", "channel_type"], name: "index_email_templates_newsletter_only", where: "((template_type)::text = 'newsletter'::text)"
    t.index ["template_type", "language", "channel_type"], name: "index_email_templates_on_type_language_channel_excl_newsletter", unique: true, where: "((template_type)::text <> 'newsletter'::text)"
    t.check_constraint "channel_type::text = ANY (ARRAY['email'::character varying::text, 'telegram'::character varying::text, 'push'::character varying::text])", name: "check_channel_type"
  end

  create_table "google_oauth_settings", force: :cascade do |t|
    t.string "client_id"
    t.string "client_secret"
    t.string "redirect_uri"
    t.boolean "enabled", default: false, null: false
    t.boolean "allow_registration", default: true, null: false
    t.boolean "auto_verify_email", default: true, null: false
    t.text "scopes_list", default: "email,profile"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.bigint "partner_id"
    t.integer "access_level", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "position"
    t.index ["partner_id"], name: "index_managers_on_partner_id"
    t.index ["user_id"], name: "index_managers_on_user_id", unique: true
  end

  create_table "notification_channel_settings", force: :cascade do |t|
    t.string "channel_type", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "priority", default: 1, null: false
    t.integer "retry_attempts", default: 3, null: false
    t.integer "retry_delay", default: 15, null: false
    t.integer "daily_limit", default: 1000, null: false
    t.integer "rate_limit_per_minute", default: 60, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_type"], name: "index_notification_channel_settings_on_channel_type", unique: true
    t.index ["enabled"], name: "index_notification_channel_settings_on_enabled"
    t.index ["priority"], name: "index_notification_channel_settings_on_priority"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.string "notification_type"
    t.string "recipient_type"
    t.integer "recipient_id"
    t.string "recipient_email"
    t.string "template_type"
    t.integer "template_id"
    t.string "status"
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.datetime "opened_at"
    t.datetime "clicked_at"
    t.text "error_message"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "priority", default: "normal", null: false
    t.string "category", default: "general", null: false
    t.index ["category"], name: "index_notifications_on_category"
    t.index ["is_read"], name: "index_notifications_on_is_read"
    t.index ["notification_type_id"], name: "index_notifications_on_notification_type_id"
    t.index ["priority"], name: "index_notifications_on_priority"
    t.index ["recipient_type", "recipient_id"], name: "idx_notifications_recipient"
    t.index ["sent_at"], name: "index_notifications_on_sent_at"
  end

  create_table "operator_service_points", force: :cascade do |t|
    t.bigint "operator_id", null: false, comment: "Ссылка на оператора"
    t.bigint "service_point_id", null: false, comment: "Ссылка на сервисную точку"
    t.datetime "assigned_at", default: -> { "CURRENT_TIMESTAMP" }, null: false, comment: "Дата и время назначения"
    t.boolean "is_active", default: true, null: false, comment: "Активность привязки"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_operator_service_points_on_is_active"
    t.index ["operator_id", "service_point_id"], name: "idx_operator_service_points_operator_point", unique: true
    t.index ["operator_id", "service_point_id"], name: "index_operator_service_points_unique", unique: true
    t.index ["operator_id"], name: "index_operator_service_points_on_operator_id"
    t.index ["service_point_id", "is_active"], name: "idx_operator_service_points_point_active"
    t.index ["service_point_id"], name: "index_operator_service_points_on_service_point_id"
  end

  create_table "operators", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "position"
    t.integer "access_level"
    t.boolean "is_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "partner_id"
    t.index ["partner_id"], name: "index_operators_on_partner_id"
    t.index ["user_id"], name: "index_operators_on_user_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false, comment: "Заказ, к которому относится товар"
    t.string "artikul", null: false, comment: "Артикул товара"
    t.integer "quantity", null: false, comment: "Количество товара"
    t.decimal "price", precision: 10, scale: 2, null: false, comment: "Цена за единицу товара"
    t.decimal "sum", precision: 10, scale: 2, null: false, comment: "Общая стоимость (quantity * price)"
    t.string "bas_id", null: false, comment: "ID товара в системе 1С/BAS"
    t.string "name", comment: "Название товара"
    t.text "description", comment: "Описание товара"
    t.string "category", comment: "Категория товара"
    t.string "brand", comment: "Бренд товара"
    t.string "model", comment: "Модель товара"
    t.json "item_attributes", comment: "Дополнительные атрибуты товара в JSON"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artikul"], name: "index_order_items_on_artikul"
    t.index ["bas_id"], name: "index_order_items_on_bas_id"
    t.index ["order_id", "artikul"], name: "index_order_items_on_order_id_and_artikul"
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "service_point_id", null: false, comment: "Сервисная точка для выдачи заказа"
    t.string "status", default: "received", null: false, comment: "Статус заказа"
    t.datetime "order_date", null: false, comment: "Дата создания заказа"
    t.string "ttn", null: false, comment: "ТТН (номер накладной)"
    t.string "number", comment: "Номер заказа (может быть пустым)"
    t.string "status_kod", null: false, comment: "Код статуса из внешней системы"
    t.string "bas_id", null: false, comment: "ID заказа в системе 1С/BAS"
    t.integer "separate", default: 1, comment: "Признак разделения заказа"
    t.string "customer_name", null: false, comment: "ФИО клиента"
    t.string "customer_phone", null: false, comment: "Телефон клиента"
    t.string "point_name", null: false, comment: "Название точки выдачи"
    t.string "point_id", null: false, comment: "ID точки выдачи во внешней системе"
    t.boolean "third_party_point", default: false, comment: "Является ли точка сторонней"
    t.string "ttn_status", comment: "Статус ТТН"
    t.string "ttn_status_kod", comment: "Код статуса ТТН"
    t.decimal "total_amount", precision: 10, scale: 2, null: false, comment: "Общая сумма заказа"
    t.integer "total_quantity", null: false, comment: "Общее количество товаров"
    t.datetime "processed_at", comment: "Время начала обработки"
    t.datetime "ready_at", comment: "Время готовности к выдаче"
    t.datetime "delivered_at", comment: "Время выдачи клиенту"
    t.datetime "canceled_at", comment: "Время отмены"
    t.text "cancellation_reason", comment: "Причина отмены"
    t.text "notes", comment: "Дополнительные заметки"
    t.json "metadata", comment: "Дополнительные данные в JSON формате"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "to_tsvector('russian'::regconfig, (customer_name)::text)", name: "idx_orders_customer_search", using: :gin
    t.index ["bas_id"], name: "index_orders_on_bas_id"
    t.index ["customer_phone"], name: "index_orders_on_customer_phone"
    t.index ["order_date"], name: "index_orders_on_order_date"
    t.index ["point_id"], name: "index_orders_on_point_id"
    t.index ["service_point_id", "status"], name: "index_orders_on_service_point_id_and_status"
    t.index ["service_point_id"], name: "index_orders_on_service_point_id"
    t.index ["ttn"], name: "index_orders_on_ttn", unique: true
  end

  create_table "page_contents", force: :cascade do |t|
    t.string "section"
    t.string "content_type"
    t.text "title"
    t.text "content"
    t.text "image_url"
    t.text "settings"
    t.integer "position"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "language", default: "uk", null: false
    t.index ["content_type", "language"], name: "index_page_contents_on_content_type_and_language"
    t.index ["language"], name: "index_page_contents_on_language"
    t.index ["section", "language"], name: "index_page_contents_on_section_and_language"
  end

  create_table "partner_applications", force: :cascade do |t|
    t.string "company_name", null: false
    t.text "business_description", null: false
    t.string "contact_person", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.string "city", null: false
    t.string "address"
    t.bigint "region_id"
    t.bigint "city_record_id"
    t.string "website"
    t.text "additional_info"
    t.integer "expected_service_points", default: 1, null: false
    t.string "status", default: "new", null: false
    t.bigint "processed_by_id"
    t.text "admin_notes"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_record_id"], name: "index_partner_applications_on_city_record_id"
    t.index ["company_name"], name: "index_partner_applications_on_company_name"
    t.index ["created_at"], name: "index_partner_applications_on_created_at"
    t.index ["email"], name: "index_partner_applications_on_email"
    t.index ["processed_by_id"], name: "index_partner_applications_on_processed_by_id"
    t.index ["region_id"], name: "index_partner_applications_on_region_id"
    t.index ["status"], name: "index_partner_applications_on_status"
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
    t.bigint "region_id"
    t.bigint "city_id"
    t.index ["city_id"], name: "index_partners_on_city_id"
    t.index ["company_name"], name: "index_partners_on_company_name"
    t.index ["id", "is_active"], name: "idx_partners_id_active"
    t.index ["is_active"], name: "index_partners_on_is_active"
    t.index ["region_id"], name: "index_partners_on_region_id"
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

  create_table "push_settings", force: :cascade do |t|
    t.string "vapid_public_key"
    t.string "vapid_private_key"
    t.string "firebase_api_key"
    t.string "firebase_project_id"
    t.string "firebase_app_id"
    t.boolean "enabled", default: false, null: false
    t.boolean "test_mode", default: false, null: false
    t.integer "daily_limit", default: 1000, null: false
    t.integer "rate_limit", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.text "p256dh_key", null: false
    t.text "auth_key", null: false
    t.text "user_agent"
    t.boolean "is_active", default: true, null: false
    t.datetime "last_used_at"
    t.integer "notifications_sent", default: 0
    t.integer "notifications_failed", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["is_active"], name: "index_push_subscriptions_on_is_active"
    t.index ["user_id", "is_active"], name: "index_push_subscriptions_on_user_id_and_is_active"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "regions", force: :cascade do |t|
    t.string "name", null: false
    t.string "code"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_uk"
    t.string "name_ru"
    t.index ["code"], name: "index_regions_on_code", unique: true
    t.index ["name"], name: "index_regions_on_name", unique: true
    t.index ["name_ru"], name: "index_regions_on_name_ru"
    t.index ["name_uk"], name: "index_regions_on_name_uk"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "booking_id"
    t.bigint "client_id", null: false
    t.bigint "service_point_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.text "partner_response"
    t.boolean "is_published", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "recommend", default: true, null: false
    t.string "status", default: "published", null: false
    t.index "to_tsvector('russian'::regconfig, COALESCE(comment, ''::text))", name: "idx_reviews_search_text", using: :gin
    t.index ["booking_id"], name: "index_reviews_on_booking_id"
    t.index ["client_id", "created_at"], name: "idx_reviews_client_created"
    t.index ["client_id"], name: "index_reviews_on_client_id"
    t.index ["recommend"], name: "index_reviews_on_recommend"
    t.index ["service_point_id", "is_published"], name: "idx_reviews_point_published"
    t.index ["service_point_id"], name: "index_reviews_on_service_point_id"
    t.index ["status"], name: "index_reviews_on_status"
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
    t.bigint "service_post_id", null: false
    t.index ["is_available"], name: "idx_schedule_slots_availability"
    t.index ["service_point_id", "slot_date", "start_time", "post_number"], name: "idx_unique_slot", unique: true
    t.index ["service_point_id"], name: "index_schedule_slots_on_service_point_id"
    t.index ["service_post_id"], name: "index_schedule_slots_on_service_post_id"
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

  create_table "seasonal_schedules", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.string "name", limit: 255, null: false, comment: "Название сезонного расписания (например, \"Летнее расписание\", \"Новогодние каникулы\")"
    t.text "description", comment: "Описание сезонного расписания"
    t.date "start_date", null: false, comment: "Дата начала действия сезонного расписания"
    t.date "end_date", null: false, comment: "Дата окончания действия сезонного расписания"
    t.json "working_hours", null: false, comment: "JSON с расписанием работы по дням недели в формате {monday: {is_working_day: true, start: \"09:00\", end: \"18:00\"}}"
    t.boolean "is_active", default: true, null: false, comment: "Активно ли сезонное расписание"
    t.integer "priority", default: 0, null: false, comment: "Приоритет расписания (чем выше число, тем выше приоритет)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority"], name: "idx_seasonal_schedules_priority"
    t.index ["service_point_id", "is_active"], name: "idx_seasonal_schedules_active"
    t.index ["service_point_id", "start_date", "end_date"], name: "idx_seasonal_schedules_period"
    t.index ["service_point_id"], name: "index_seasonal_schedules_on_service_point_id"
    t.check_constraint "end_date >= start_date", name: "check_seasonal_schedules_date_range"
  end

  create_table "seo_metatags", force: :cascade do |t|
    t.string "page_type", null: false
    t.text "title", null: false
    t.text "description", null: false
    t.text "keywords"
    t.string "image_url"
    t.string "canonical_url"
    t.boolean "no_index", default: false, null: false
    t.string "language", default: "uk", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_seo_metatags_on_active"
    t.index ["language"], name: "index_seo_metatags_on_language"
    t.index ["page_type", "language"], name: "index_seo_metatags_on_page_type_and_language", unique: true
    t.index ["page_type"], name: "index_seo_metatags_on_page_type"
  end

  create_table "service_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "icon_url"
    t.integer "sort_order", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_uk"
    t.text "description_uk"
    t.index ["name"], name: "index_service_categories_on_name", unique: true
    t.index ["name_uk"], name: "index_service_categories_on_name_uk"
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

  create_table "service_point_category_settings", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.bigint "service_category_id", null: false
    t.boolean "auto_confirmation", default: false, null: false, comment: "Автоматическое подтверждение бронирований для данной категории услуг"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auto_confirmation"], name: "index_service_point_category_settings_on_auto_confirmation"
    t.index ["service_category_id"], name: "index_service_point_category_settings_on_service_category_id"
    t.index ["service_point_id", "service_category_id"], name: "index_sp_category_settings_unique", unique: true
    t.index ["service_point_id"], name: "index_service_point_category_settings_on_service_point_id"
  end

  create_table "service_point_photos", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "is_main", default: false, null: false
    t.index ["service_point_id"], name: "index_service_point_photos_on_service_point_id"
  end

  create_table "service_point_services", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "duration", default: 60, null: false
    t.boolean "is_available", default: true, null: false
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
    t.integer "post_count", default: 1
    t.integer "default_slot_duration", default: 60
    t.decimal "rating", precision: 3, scale: 2, default: "0.0"
    t.integer "total_clients_served", default: 0
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.decimal "cancellation_rate", precision: 5, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "work_status", default: "working", null: false
    t.json "working_hours"
    t.jsonb "category_contacts", default: {}
    t.string "name_ru", null: false
    t.string "name_uk", null: false
    t.text "description_ru", null: false
    t.text "description_uk", null: false
    t.string "address_ru", null: false
    t.string "address_uk", null: false
    t.index "to_tsvector('russian'::regconfig, (((name)::text || ' '::text) || COALESCE(description, ''::text)))", name: "idx_service_points_search_text", using: :gin
    t.index ["category_contacts"], name: "index_service_points_on_category_contacts", using: :gin
    t.index ["city_id"], name: "index_service_points_on_city_id"
    t.index ["is_active", "work_status"], name: "index_service_points_on_is_active_and_work_status"
    t.index ["is_active"], name: "index_service_points_on_is_active"
    t.index ["latitude", "longitude"], name: "idx_service_points_location"
    t.index ["name_ru"], name: "index_service_points_on_name_ru"
    t.index ["name_uk"], name: "index_service_points_on_name_uk"
    t.index ["partner_id", "city_id"], name: "idx_service_points_partner_city"
    t.index ["partner_id", "is_active", "city_id", "created_at"], name: "idx_service_points_complex_filter"
    t.index ["partner_id", "is_active"], name: "idx_service_points_partner_active"
    t.index ["partner_id"], name: "index_service_points_on_partner_id"
    t.index ["work_status"], name: "index_service_points_on_work_status"
  end

  create_table "service_posts", force: :cascade do |t|
    t.bigint "service_point_id", null: false
    t.integer "post_number", null: false
    t.string "name", limit: 255
    t.integer "slot_duration", default: 60, null: false
    t.boolean "is_active", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_custom_schedule", default: false, null: false, comment: "Использует ли пост индивидуальное расписание"
    t.json "working_days", comment: "JSON с настройками рабочих дней поста (monday, tuesday, etc.)"
    t.json "custom_hours", comment: "JSON с индивидуальным временем работы поста (start, end)"
    t.bigint "service_category_id", null: false
    t.index ["service_category_id"], name: "index_service_posts_on_service_category_id"
    t.index ["service_point_id", "is_active"], name: "index_service_posts_on_service_point_and_active"
    t.index ["service_point_id", "post_number"], name: "index_service_posts_on_service_point_and_post_number", unique: true
    t.index ["service_point_id", "service_category_id"], name: "idx_on_service_point_id_service_category_id_59ee909e4d"
    t.index ["service_point_id"], name: "index_service_posts_on_service_point_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "sort_order", default: 0
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name_uk"
    t.text "description_uk"
    t.index ["category_id"], name: "index_services_on_category_id"
    t.index ["name_uk"], name: "index_services_on_name_uk"
  end

  create_table "supplier_price_versions", force: :cascade do |t|
    t.bigint "supplier_id", null: false
    t.string "version", limit: 100, null: false
    t.string "file_checksum", limit: 64
    t.integer "products_count", default: 0
    t.integer "processed_count", default: 0
    t.integer "errors_count", default: 0
    t.integer "processing_time_ms"
    t.datetime "uploaded_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_id", "version"], name: "index_supplier_price_versions_on_supplier_id_and_version", unique: true
    t.index ["supplier_id"], name: "index_supplier_price_versions_on_supplier_id"
    t.index ["uploaded_at"], name: "index_supplier_price_versions_on_uploaded_at"
  end

  create_table "supplier_tire_products", force: :cascade do |t|
    t.bigint "supplier_id", null: false
    t.string "external_id", limit: 255, null: false
    t.string "original_brand", limit: 100, null: false
    t.string "brand_normalized", limit: 100, null: false
    t.string "original_model", limit: 255, null: false
    t.string "name", limit: 500, null: false
    t.integer "width", null: false
    t.integer "height", null: false
    t.string "diameter", limit: 10, null: false
    t.string "load_index", limit: 10
    t.string "speed_index", limit: 10
    t.string "season", limit: 20, null: false
    t.decimal "price_uah", precision: 10, scale: 2
    t.string "stock_status", limit: 50
    t.boolean "in_stock", default: false
    t.text "description"
    t.string "image_url", limit: 1000
    t.string "product_url", limit: 1000
    t.string "original_country", limit: 100
    t.string "year_week", limit: 20
    t.text "search_tokens"
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tire_brand_id", comment: "Нормализованный бренд"
    t.bigint "tire_model_id", comment: "Нормализованная модель"
    t.bigint "country_id", comment: "Нормализованная страна производства"
    t.integer "production_year", comment: "Год производства (извлеченный из year_week)"
    t.decimal "optimality_score", precision: 5, scale: 2, comment: "Рассчитанный рейтинг оптимальности"
    t.index "to_tsvector('russian'::regconfig, search_tokens)", name: "idx_supplier_tire_products_tokens", using: :gin
    t.index ["country_id"], name: "index_supplier_tire_products_on_country_id"
    t.index ["in_stock"], name: "index_supplier_tire_products_on_in_stock"
    t.index ["optimality_score"], name: "index_supplier_tire_products_on_optimality_score"
    t.index ["production_year"], name: "index_supplier_tire_products_on_production_year"
    t.index ["season"], name: "index_supplier_tire_products_on_season"
    t.index ["supplier_id", "external_id"], name: "index_supplier_tire_products_on_supplier_id_and_external_id", unique: true
    t.index ["supplier_id"], name: "index_supplier_tire_products_on_supplier_id"
    t.index ["tire_brand_id", "tire_model_id"], name: "idx_on_tire_brand_id_tire_model_id_7823a23358"
    t.index ["tire_brand_id", "width", "height", "diameter", "season", "in_stock"], name: "idx_supplier_products_normalized_search"
    t.index ["tire_brand_id"], name: "index_supplier_tire_products_on_tire_brand_id"
    t.index ["tire_model_id"], name: "index_supplier_tire_products_on_tire_model_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "firm_id", limit: 50, null: false
    t.string "name", limit: 255, null: false
    t.string "api_key", limit: 255, null: false
    t.boolean "is_active", default: true
    t.integer "priority", default: 0
    t.datetime "last_sync_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_suppliers_on_api_key", unique: true
    t.index ["firm_id"], name: "index_suppliers_on_firm_id", unique: true
    t.index ["is_active"], name: "index_suppliers_on_is_active"
  end

  create_table "system_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false, comment: "Тип действия (created/updated/deleted/suspended/assigned)"
    t.string "resource_type", comment: "Тип ресурса (User/Booking/ServicePoint/Operator)"
    t.integer "resource_id", comment: "ID ресурса"
    t.jsonb "old_value"
    t.jsonb "new_value"
    t.string "ip_address", limit: 45, comment: "IP адрес пользователя"
    t.text "user_agent", comment: "User-Agent браузера"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "record_changes", comment: "Детальные изменения записи в JSON формате"
    t.jsonb "additional_data", comment: "Дополнительная контекстная информация"
    t.index ["action", "created_at"], name: "idx_system_logs_action_created"
    t.index ["action"], name: "index_system_logs_on_action"
    t.index ["additional_data"], name: "idx_system_logs_additional_data_gin", using: :gin
    t.index ["additional_data"], name: "index_system_logs_on_additional_data", using: :gin
    t.index ["created_at"], name: "index_system_logs_on_created_at"
    t.index ["ip_address", "created_at"], name: "idx_system_logs_ip_created"
    t.index ["record_changes"], name: "idx_system_logs_changes_gin", using: :gin
    t.index ["record_changes"], name: "idx_system_logs_record_changes_gin", using: :gin
    t.index ["record_changes"], name: "index_system_logs_on_record_changes", using: :gin
    t.index ["resource_type", "action"], name: "index_system_logs_on_resource_type_and_action"
    t.index ["resource_type", "resource_id", "created_at"], name: "idx_system_logs_resource_created"
    t.index ["resource_type", "resource_id"], name: "idx_system_logs_resource"
    t.index ["user_id", "created_at"], name: "idx_system_logs_user_created"
    t.index ["user_id", "created_at"], name: "index_system_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_system_logs_on_user_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.text "description"
    t.string "category", default: "general"
    t.string "setting_type", default: "string"
    t.text "default_value"
    t.string "updated_by"
    t.boolean "is_encrypted", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "setting_type"], name: "index_system_settings_on_category_and_setting_type"
    t.index ["category"], name: "index_system_settings_on_category"
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "telegram_booking_sessions", force: :cascade do |t|
    t.string "chat_id", null: false
    t.string "current_step", default: "city_selection", null: false
    t.json "session_data", default: {}
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_telegram_booking_sessions_on_chat_id", unique: true
    t.index ["expires_at"], name: "index_telegram_booking_sessions_on_expires_at"
  end

  create_table "telegram_notifications", force: :cascade do |t|
    t.text "message", null: false
    t.string "chat_id", null: false
    t.bigint "user_id", null: false
    t.bigint "booking_id"
    t.string "notification_type", default: "general"
    t.string "status", default: "pending"
    t.datetime "sent_at"
    t.text "error_message"
    t.integer "retry_count", default: 0
    t.json "telegram_response"
    t.integer "message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_telegram_notifications_on_booking_id"
    t.index ["chat_id"], name: "index_telegram_notifications_on_chat_id"
    t.index ["notification_type"], name: "index_telegram_notifications_on_notification_type"
    t.index ["sent_at"], name: "index_telegram_notifications_on_sent_at"
    t.index ["status"], name: "index_telegram_notifications_on_status"
    t.index ["user_id"], name: "index_telegram_notifications_on_user_id"
  end

  create_table "telegram_settings", force: :cascade do |t|
    t.string "bot_token"
    t.string "webhook_url"
    t.string "admin_chat_id"
    t.boolean "enabled", default: false, null: false
    t.boolean "test_mode", default: false, null: false
    t.boolean "auto_subscription", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bot_username"
    t.datetime "webhook_last_updated_at"
    t.index ["webhook_last_updated_at"], name: "index_telegram_settings_on_webhook_last_updated_at"
  end

  create_table "telegram_subscriptions", force: :cascade do |t|
    t.string "chat_id", null: false
    t.bigint "user_id", null: false
    t.boolean "is_active", default: true, null: false
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.string "language_code", default: "ru"
    t.text "notification_preferences"
    t.datetime "last_interaction_at"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_telegram_subscriptions_on_chat_id", unique: true
    t.index ["user_id"], name: "index_telegram_subscriptions_on_user_id"
  end

  create_table "tire_brands", force: :cascade do |t|
    t.string "name", limit: 100, null: false, comment: "Каноничное название бренда"
    t.string "normalized_name", limit: 100, null: false, comment: "Нормализованное название для поиска"
    t.integer "rating_score", default: 5, comment: "Рейтинг бренда (1-10)"
    t.text "aliases", default: [], comment: "Альтернативные названия и алиасы", array: true
    t.bigint "country_id", comment: "Страна происхождения бренда"
    t.boolean "is_premium", default: false, comment: "Премиум сегмент"
    t.boolean "is_active", default: true, comment: "Активность справочника"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_tire_brands_on_aliases", using: :gin
    t.index ["country_id", "is_premium"], name: "index_tire_brands_on_country_id_and_is_premium"
    t.index ["country_id"], name: "index_tire_brands_on_country_id"
    t.index ["is_premium"], name: "index_tire_brands_on_is_premium"
    t.index ["normalized_name"], name: "index_tire_brands_on_normalized_name", unique: true
    t.index ["rating_score"], name: "index_tire_brands_on_rating_score"
  end

  create_table "tire_cart_items", force: :cascade do |t|
    t.bigint "tire_cart_id", null: false
    t.bigint "supplier_tire_product_id", null: false
    t.integer "quantity", null: false
    t.decimal "price_at_add", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_tire_product_id"], name: "index_tire_cart_items_on_supplier_tire_product_id"
    t.index ["tire_cart_id", "supplier_tire_product_id"], name: "index_tire_cart_items_unique", unique: true
    t.index ["tire_cart_id"], name: "index_tire_cart_items_on_tire_cart_id"
  end

  create_table "tire_carts", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_tire_carts_on_user_id", unique: true, where: "(user_id IS NOT NULL)"
  end

  create_table "tire_data_versions", force: :cascade do |t|
    t.string "version", null: false
    t.text "source_description"
    t.jsonb "file_checksums"
    t.jsonb "statistics"
    t.datetime "imported_at"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["imported_at"], name: "index_tire_data_versions_on_imported_at"
    t.index ["is_active"], name: "index_tire_data_versions_on_is_active"
    t.index ["version"], name: "index_tire_data_versions_on_version", unique: true
  end

  create_table "tire_models", force: :cascade do |t|
    t.bigint "tire_brand_id", null: false, comment: "Бренд шины"
    t.string "name", limit: 255, null: false, comment: "Каноничное название модели"
    t.string "normalized_name", limit: 255, null: false, comment: "Нормализованное название для поиска"
    t.integer "rating_score", default: 5, comment: "Рейтинг модели (1-10)"
    t.text "aliases", default: [], comment: "Альтернативные названия модели", array: true
    t.string "season_type", limit: 20, comment: "Тип сезонности (summer, winter, all_season)"
    t.boolean "is_active", default: true, comment: "Активность справочника"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_tire_models_on_aliases", using: :gin
    t.index ["rating_score"], name: "index_tire_models_on_rating_score"
    t.index ["season_type"], name: "index_tire_models_on_season_type"
    t.index ["tire_brand_id", "normalized_name"], name: "index_tire_models_on_tire_brand_id_and_normalized_name", unique: true
    t.index ["tire_brand_id", "season_type"], name: "index_tire_models_on_tire_brand_id_and_season_type"
    t.index ["tire_brand_id"], name: "index_tire_models_on_tire_brand_id"
  end

  create_table "tire_order_items", force: :cascade do |t|
    t.bigint "tire_order_id", null: false
    t.bigint "supplier_tire_product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price_at_order", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_tire_product_id"], name: "index_tire_order_items_on_supplier_tire_product_id"
    t.index ["tire_order_id", "supplier_tire_product_id"], name: "index_tire_order_items_unique", unique: true
    t.index ["tire_order_id"], name: "index_tire_order_items_on_tire_order_id"
  end

  create_table "tire_orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "supplier_id", null: false
    t.string "status", default: "draft", null: false
    t.string "client_name", null: false
    t.string "client_phone", null: false
    t.text "comment"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_tire_orders_on_status"
    t.index ["supplier_id", "status"], name: "index_tire_orders_on_supplier_id_and_status"
    t.index ["supplier_id"], name: "index_tire_orders_on_supplier_id"
    t.index ["user_id", "status"], name: "index_tire_orders_on_user_id_and_status"
    t.index ["user_id"], name: "index_tire_orders_on_user_id"
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
    t.string "name_uk"
    t.text "description_uk"
    t.index ["name", "is_active"], name: "idx_user_roles_name_active"
    t.index ["name"], name: "index_user_roles_on_name", unique: true
    t.index ["name_uk"], name: "index_user_roles_on_name_uk"
  end

  create_table "user_social_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "provider_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_user_id"], name: "index_user_social_accounts_on_provider_and_provider_user_id", unique: true
    t.index ["user_id"], name: "index_user_social_accounts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", comment: "Email пользователя (необязательное поле)"
    t.string "phone", comment: "Номер телефона (один из email/phone обязателен)"
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
    t.string "password_reset_token", comment: "Токен для восстановления пароля"
    t.datetime "password_reset_sent_at", comment: "Время истечения токена восстановления пароля"
    t.string "preferred_locale", limit: 2, default: "uk"
    t.boolean "is_suspended", default: false, null: false, comment: "Флаг блокировки пользователя"
    t.datetime "suspended_until", comment: "Дата окончания блокировки (null = бессрочно)"
    t.text "suspension_reason", comment: "Причина блокировки"
    t.bigint "suspended_by_id", comment: "Кто заблокировал пользователя"
    t.datetime "suspended_at", comment: "Дата и время блокировки"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["id", "is_active"], name: "idx_users_id_active"
    t.index ["is_suspended"], name: "index_users_on_is_suspended"
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["role_id", "is_active"], name: "idx_users_role_active"
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["suspended_by_id"], name: "index_users_on_suspended_by_id"
    t.index ["suspended_until"], name: "index_users_on_suspended_until"
  end

  create_table "weekdays", force: :cascade do |t|
    t.string "name", null: false
    t.string "short_name", limit: 3, null: false
    t.integer "sort_order", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "administrators", "users"
  add_foreign_key "articles", "users", column: "author_id"
  add_foreign_key "booking_conflicts", "bookings"
  add_foreign_key "booking_conflicts", "users", column: "resolved_by_id"
  add_foreign_key "booking_services", "bookings"
  add_foreign_key "booking_services", "services"
  add_foreign_key "bookings", "booking_statuses", column: "status_id", on_delete: :restrict, validate: false
  add_foreign_key "bookings", "cancellation_reasons"
  add_foreign_key "bookings", "car_types"
  add_foreign_key "bookings", "client_cars", column: "car_id"
  add_foreign_key "bookings", "clients"
  add_foreign_key "bookings", "payment_statuses", on_delete: :restrict, validate: false
  add_foreign_key "bookings", "service_categories"
  add_foreign_key "bookings", "service_points"
  add_foreign_key "car_models", "car_brands", column: "brand_id"
  add_foreign_key "car_tire_configurations", "car_brands", column: "brand_id"
  add_foreign_key "car_tire_configurations", "car_models", column: "model_id"
  add_foreign_key "cars", "car_types"
  add_foreign_key "cars", "clients"
  add_foreign_key "cities", "regions"
  add_foreign_key "client_cars", "car_brands", column: "brand_id"
  add_foreign_key "client_cars", "car_models", column: "model_id"
  add_foreign_key "client_cars", "car_types"
  add_foreign_key "client_cars", "clients"
  add_foreign_key "client_cars", "tire_types"
  add_foreign_key "client_favorite_points", "clients"
  add_foreign_key "client_favorite_points", "service_points"
  add_foreign_key "clients", "users"
  add_foreign_key "custom_variables", "users", column: "created_by_id"
  add_foreign_key "email_template_custom_variables", "custom_variables"
  add_foreign_key "email_template_custom_variables", "email_templates"
  add_foreign_key "manager_service_points", "managers"
  add_foreign_key "manager_service_points", "service_points"
  add_foreign_key "managers", "partners"
  add_foreign_key "managers", "users"
  add_foreign_key "notifications", "notification_types"
  add_foreign_key "operator_service_points", "operators"
  add_foreign_key "operator_service_points", "service_points"
  add_foreign_key "operators", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "service_points"
  add_foreign_key "partner_applications", "cities", column: "city_record_id"
  add_foreign_key "partner_applications", "regions"
  add_foreign_key "partner_applications", "users", column: "processed_by_id"
  add_foreign_key "partners", "cities"
  add_foreign_key "partners", "regions"
  add_foreign_key "partners", "users"
  add_foreign_key "price_list_items", "price_lists"
  add_foreign_key "price_list_items", "services"
  add_foreign_key "price_lists", "partners"
  add_foreign_key "price_lists", "service_points"
  add_foreign_key "promotions", "partners"
  add_foreign_key "promotions", "service_points"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "reviews", "bookings"
  add_foreign_key "reviews", "clients"
  add_foreign_key "reviews", "service_points"
  add_foreign_key "schedule_exceptions", "service_points"
  add_foreign_key "schedule_slots", "service_points"
  add_foreign_key "schedule_slots", "service_posts"
  add_foreign_key "schedule_templates", "service_points"
  add_foreign_key "schedule_templates", "weekdays"
  add_foreign_key "seasonal_schedules", "service_points"
  add_foreign_key "service_point_amenities", "amenities"
  add_foreign_key "service_point_amenities", "service_points"
  add_foreign_key "service_point_category_settings", "service_categories"
  add_foreign_key "service_point_category_settings", "service_points"
  add_foreign_key "service_point_photos", "service_points"
  add_foreign_key "service_point_services", "service_points"
  add_foreign_key "service_point_services", "services"
  add_foreign_key "service_points", "cities"
  add_foreign_key "service_points", "partners"
  add_foreign_key "service_posts", "service_categories"
  add_foreign_key "service_posts", "service_points"
  add_foreign_key "services", "service_categories", column: "category_id"
  add_foreign_key "supplier_price_versions", "suppliers"
  add_foreign_key "supplier_tire_products", "countries"
  add_foreign_key "supplier_tire_products", "suppliers"
  add_foreign_key "supplier_tire_products", "tire_brands"
  add_foreign_key "supplier_tire_products", "tire_models"
  add_foreign_key "system_logs", "users"
  add_foreign_key "telegram_notifications", "bookings"
  add_foreign_key "telegram_notifications", "users"
  add_foreign_key "telegram_subscriptions", "users"
  add_foreign_key "tire_brands", "countries"
  add_foreign_key "tire_cart_items", "supplier_tire_products"
  add_foreign_key "tire_cart_items", "tire_carts"
  add_foreign_key "tire_carts", "users"
  add_foreign_key "tire_models", "tire_brands"
  add_foreign_key "tire_order_items", "supplier_tire_products"
  add_foreign_key "tire_order_items", "tire_orders"
  add_foreign_key "tire_orders", "suppliers"
  add_foreign_key "tire_orders", "users"
  add_foreign_key "user_social_accounts", "users"
  add_foreign_key "users", "user_roles", column: "role_id"
  add_foreign_key "users", "users", column: "suspended_by_id"
end
