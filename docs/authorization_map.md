# Authorization Map

## Overview

This document maps all controllers that use `skip_after_action :verify_authorized` or
`skip_authorization` and documents the alternative protection mechanism for each.

The application uses Pundit for authorization with `after_action :verify_authorized`
defined in `ApplicationController`. Controllers that skip this check must have
alternative protection documented here.

**Last audit:** 2026-03-04

---

## Admin Controllers

| Controller | File | Parent Class | Protection | Status |
|-----------|------|-------------|-----------|--------|
| `AdminController` | `admin_controller.rb` | `ApiController` | `before_action :authenticate_request`, `before_action :ensure_admin!` | OK |
| `Admin::SystemSettingsController` | `admin/system_settings_controller.rb` | `AdminController` | Inherits `ensure_admin!` from `AdminController` | OK |
| `Admin::TireDataController` | `admin/tire_data_controller.rb` | `AdminController` | Inherits `ensure_admin!` from `AdminController` | OK |
| `Admin::ChatAnalyticsController` | `admin/chat_analytics_controller.rb` | `AdminController` | Inherits `ensure_admin!` from `AdminController` | OK (fixed: was BaseController) |
| `DebugController` | `debug_controller.rb` | `ApiController` | `before_action :require_admin!` + `Rails.env` check | OK |
| `EmailTestController` | `email_test_controller.rb` | `ApiController` | `before_action :authorize_admin!` | OK |
| `NormalizationController` | `normalization_controller.rb` | `ApplicationController` | `before_action :ensure_admin!` | OK |
| `SettingsController` | `settings_controller.rb` | `ApplicationController` | `before_action :authenticate_request`, `before_action :authorize_admin!` | OK |
| `SettingsDiagnosticsController` | `settings_diagnostics_controller.rb` | `ApplicationController` | `before_action :authenticate_request`, `before_action :ensure_admin` | OK |
| `TireModelsController` | `tire_models_controller.rb` | `ApiController` | `before_action :authenticate_request!`, `before_action :authorize_admin_or_manager!` | OK |

---

## Supplier Controllers (role-protected)

| Controller | File | Protection | Scope Check | Status |
|-----------|------|-----------|-------------|--------|
| `SupplierAnalyticsController` | `supplier_analytics_controller.rb` | `ensure_supplier_access!` (admin or supplier) | `set_supplier` scopes to `current_user.supplier` for non-admins | OK |
| `SupplierDashboardController` | `supplier_dashboard_controller.rb` | `ensure_supplier_access!` (admin or supplier) | `set_supplier` scopes to `current_user.supplier` for non-admins | OK |
| `SupplierProductsController` | `supplier_products_controller.rb` | `ensure_supplier_access!` (admin or supplier) | `set_supplier` scopes to `current_user.supplier`; products scoped to `@supplier` | OK |
| `SupplierClientsController` | `supplier_clients_controller.rb` | `ensure_supplier_access!` (admin or supplier) | `set_supplier` scopes to `current_user.supplier`; data scoped to `@supplier` | OK |
| `SupplierProfileController` | `supplier_profile_controller.rb` | `authorize_supplier!` (admin or supplier) | Compares `current_user.supplier.id` to requested supplier ID | OK |
| `BulkSupplierOrdersController` | `bulk_supplier_orders_controller.rb` | `ensure_supplier_access!` (admin or supplier) | `set_supplier` scopes; orders via `@supplier.tire_orders` | OK |
| `SuppliersController` | `suppliers_controller.rb` | `ensure_admin!` (except upload_price, all_products) | `upload_price` uses API key auth; `all_products` is public (product catalog) | OK |
| `SupplierReportsController` | `supplier_reports_controller.rb` | Token-based download; `skip_before_action :authenticate_request` for download | Token validated from cache with expiration; file path from cache, not user input | OK (acceptable for file download pattern) |

---

## Partner Controllers (role-protected)

| Controller | File | Protection | Scope Check | Status |
|-----------|------|-----------|-------------|--------|
| `PartnerDashboardController` | `partner_dashboard_controller.rb` | `ensure_partner_access!` (admin, partner, manager, operator) | `set_partner` scopes to user's partner | OK |
| `PartnerAnalyticsController` | `partner_analytics_controller.rb` | `ensure_partner_access` (admin or partner) | `set_partner` checks `partner_id` matches `current_user.partner.id` | OK |
| `PartnerOrdersController` | `partner_orders_controller.rb` | `ensure_partner_access` (admin or partner) | `set_partner` checks `partner_id` matches; orders via `@partner.orders` | OK |
| `BulkBookingsController` | `bulk_bookings_controller.rb` | `ensure_partner_access` (admin, partner, manager, operator) | `set_partner` checks `partner_id`; bookings scoped to partner's service points | OK |
| `ForecastsController` | `forecasts_controller.rb` | `ensure_partner_access` (admin or partner) | `set_partner` checks `partner_id` matches | OK |

---

## Authenticated User Controllers (any role)

| Controller | File | Protection | Scope Check | Status |
|-----------|------|-----------|-------------|--------|
| `TireOrdersController` | `tire_orders_controller.rb` | `authenticate_request` | `index` scoped to `current_user.tire_orders`; admin-only actions have `ensure_admin!`; `authorize_order_access!` checks ownership | OK |
| `PaymentHistoryController` | `payment_history_controller.rb` | `authenticate_request` | `base_scope` returns `Payment.by_user(current_user.id)` for non-admins | OK |
| `OnboardingController` | `onboarding_controller.rb` | `authenticate_request` | Data scoped to `current_user` via `find_or_create_by!(user: current_user)` | OK |
| `NotificationsController` | `notifications_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `NotificationStatisticsController` | `notification_statistics_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `PushSubscriptionsController` | `push_subscriptions_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `PushSettingsController` | `push_settings_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `NotificationChannelSettingsController` | `notification_channel_settings_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `ClientBookingsController` | `client_bookings_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `ClientFavoritePointsController` | `client_favorite_points_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `ReviewRequestsController` | `review_requests_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `ReviewReplyTemplatesController` | `review_reply_templates_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `QrCodesController` | `qr_codes_controller.rb` | `authenticate_user!`, `authorize_order_access!` | Checks partner/operator ownership of service point | OK |
| `DeliveryController` | `delivery_controller.rb` | `authenticate_user!` (except `track`) | `track` is public (by TTN); `find_order` checks ownership | OK |
| `AiRecommendationsController` | `ai_recommendations_controller.rb` | `authenticate_user!` (except `review_summary`) | Role-based access checks in each action; partner ownership verified for reviews | OK |
| `TireCartsController` | `tire_carts_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `UnifiedTireCartsController` | `unified_tire_carts_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `GoogleCalendarController` | `google_calendar_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `CustomVariablesController` | `custom_variables_controller.rb` | `authenticate_request` | Data scoped to current user | OK |
| `BookingStatusesController` | `booking_statuses_controller.rb` | `authenticate_request` | Read-only reference data | OK |
| `ManagersController` | `managers_controller.rb` | `authenticate_request` (fixed: index now requires auth), `authorize_admin` for CUD | Scoped to partner | OK (fixed: index was public) |
| `OperatorSchedulesController` | `operator_schedules_controller.rb` | `authenticate_request` | Scoped to user's operator | OK |
| `ScheduleSlotsController` | `schedule_slots_controller.rb` | `authenticate_request` | Scoped appropriately | OK |
| `SeasonalSchedulesController` | `seasonal_schedules_controller.rb` | `authenticate_request` | Scoped appropriately | OK |

---

## Public Controllers (no auth required - justified)

| Controller | File | Justification |
|-----------|------|--------------|
| `AuthController` | `auth_controller.rb` | Authentication endpoint - must be accessible before login |
| `AuthenticationController` | `authentication_controller.rb` | Legacy authentication endpoint |
| `ClientAuthController` | `client_auth_controller.rb` | Client authentication/registration |
| `PasswordsController` | `passwords_controller.rb` | Password reset - must be accessible when locked out |
| `CitiesController` | `cities_controller.rb` | Public reference data - cities list for UI |
| `RegionsController` | `regions_controller.rb` | Public reference data - regions list for UI |
| `CountriesController` | `countries_controller.rb` | Public reference data - countries list |
| `CarBrandsController` | `car_brands_controller.rb` | Public reference data - car brands for search |
| `CarModelsController` | `car_models_controller.rb` | Public reference data - car models for search |
| `CarTypesController` | `car_types_controller.rb` | Public reference data - car types for search |
| `TireTypesController` | `tire_types_controller.rb` | Public reference data - tire types |
| `TireBrandsController` | `tire_brands_controller.rb` | Public reference data - tire brands |
| `ServicesController` | `services_controller.rb` | Public reference data - available services |
| `ServiceCategoriesController` | `service_categories_controller.rb` | Public reference data - service categories |
| `ServicePointServicesController` | `service_point_services_controller.rb` | Public - service point services listing |
| `ServicePointStatusesController` | `service_point_statuses_controller.rb` | Public reference data |
| `ArticlesController` | `articles_controller.rb` | Public content - blog/news articles |
| `PageContentsController` | `page_contents_controller.rb` | Public content - static pages |
| `AmenitiesController` | `amenities_controller.rb` | Public reference data - service point amenities |
| `TireSearchController` | `tire_search_controller.rb` | Public tire search - core functionality for clients |
| `TireChatController` | `tire_chat_controller.rb` | Public AI chat - core functionality for clients |
| `CarTireSearchController` | `car_tire_search_controller.rb` | Public - search tires by car |
| `SupplierProductsSearchController` | `supplier_products_search_controller.rb` | Public catalog search - no auth needed for browsing |
| `AvailabilityController` | `availability_controller.rb` | Public - check booking availability |
| `ScheduleController` | `schedule_controller.rb` | Public - view schedules |
| `ServicePostsController` | `service_posts_controller.rb` | Public - view service posts |
| `HealthController` | `health_controller.rb` | Infrastructure health check |
| `CsrfController` | `csrf_controller.rb` | CSRF token endpoint - must be public |
| `LocaleController` | `locale_controller.rb` | Locale/language settings |
| `TelegramWebhookController` | `telegram_webhook_controller.rb` | Telegram webhook - incoming from Telegram servers |
| `ServicePointsController` | `service_points_controller.rb` | Public search and listing (specific actions use `skip_authorization`) |

---

## Test/Development Controllers

| Controller | File | Protection | Status |
|-----------|------|-----------|--------|
| `Tests::DataGeneratorController` | `tests/data_generator_controller.rb` | `before_action :ensure_non_production!` - blocks in production | OK (fixed: added centralized before_action) |

---

## Security Findings & Fixes (Phase 02)

### Fixed Issues

1. **ManagersController `index` action was public** (MEDIUM severity)
   - `skip_before_action :authenticate_request, only: [:index, :create_test]` exposed manager listing without auth
   - **Fix:** Removed `index` from skip list. Now only `create_test` (dev-only) skips auth.

2. **ChatAnalyticsController inherited from BaseController instead of AdminController** (LOW severity)
   - While it had its own `authorize_admin` before_action, inheriting from `AdminController` provides consistent admin protection.
   - **Fix:** Changed parent class to `AdminController`, removed redundant `authorize_admin` method.

3. **DataGeneratorController had duplicated env checks** (LOW severity)
   - Each action repeated the same `Rails.env.development?` check instead of using a centralized before_action.
   - **Fix:** Added `before_action :ensure_non_production!` and removed duplicated checks.

### Acceptable Patterns

1. **SupplierReportsController download via token** - Token-based download without user auth is acceptable for file download links. Token is time-limited and stored in cache.

2. **Public reference data controllers** (cities, regions, car brands, etc.) - Read-only reference data that does not contain sensitive information. No auth needed.

3. **Supplier upload_price via API key** - Separate API key auth mechanism for machine-to-machine integration.

### Recommendations

1. Consider adding rate limiting to public endpoints (tire_search, tire_chat, supplier_products_search) to prevent abuse.
2. Consider adding IP-based rate limiting to authentication endpoints.
3. Review `SupplierReportsController` token TTL to ensure it's sufficiently short (current implementation uses Rails.cache with expiration).
