# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  # Passwords
  :passw, :password, :password_confirmation,

  # Tokens and authentication
  :token, :access_token, :refresh_token,
  :secret, :api_key, :authorization,
  :bearer, :jwt, :auth, :credential, :private_key,

  # Personal data
  :email, :ssn, :cvv, :cvc,

  # Encryption
  :_key, :crypt, :salt, :certificate, :otp
]
