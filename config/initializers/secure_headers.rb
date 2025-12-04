# frozen_string_literal: true

# Security configuration for cookies and SSL

Rails.application.configure do
  # Force SSL in production
  if Rails.env.production?
    config.force_ssl = true
    config.ssl_options = {
      redirect: { exclude: ->(request) { request.path.start_with?('/health') } },
      hsts: { subdomains: true, preload: true, expires: 1.year }
    }
  end

  # Secure cookie defaults
  config.action_dispatch.cookies_same_site_protection = :lax
end

# Content Security Policy for API
# Note: This is minimal CSP for API-only applications
Rails.application.config.content_security_policy do |policy|
  policy.default_src :none
  policy.frame_ancestors :none
  policy.form_action :self
  policy.base_uri :self

  # Report violations (optional - configure endpoint if needed)
  # policy.report_uri "/api/v1/csp_reports"
end

# Generate nonce for CSP (not typically needed for API-only apps)
Rails.application.config.content_security_policy_nonce_generator = nil

# Report CSP violations without enforcing (useful for testing)
# Rails.application.config.content_security_policy_report_only = true
