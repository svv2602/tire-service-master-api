# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate Limiting", type: :request do
  before do
    # Enable Rack::Attack for testing
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.enabled = false
    Rack::Attack.reset!
  end

  describe "Login throttling" do
    let(:login_path) { "/api/v1/auth/login" }
    let(:valid_params) { { email: "test@example.com", password: "password123" } }

    context "when exceeding rate limit" do
      it "throttles after 5 requests per minute per IP" do
        # Note: In test environment, localhost is safelisted by default
        # So we need to temporarily remove the safelist for this test
        Rack::Attack.safelists.clear

        6.times do |i|
          post login_path, params: valid_params, as: :json
        end

        expect(response).to have_http_status(:too_many_requests)
        expect(response.content_type).to include("application/json")

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Too Many Requests")
        expect(json["message"]).to include("Rate limit exceeded")
        expect(json["retry_after"]).to be_present
        expect(response.headers["Retry-After"]).to be_present
      end
    end
  end

  describe "General API throttling" do
    let(:api_path) { "/api/v1/health" }

    context "when within rate limits" do
      it "allows requests within the limit" do
        get api_path, as: :json

        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe "Throttled response format" do
    it "returns proper JSON error response" do
      Rack::Attack.safelists.clear

      6.times do
        post "/api/v1/auth/login", params: { email: "test@example.com", password: "test" }, as: :json
      end

      expect(response).to have_http_status(:too_many_requests)

      json = JSON.parse(response.body)
      expect(json).to have_key("error")
      expect(json).to have_key("message")
      expect(json).to have_key("retry_after")
    end
  end

  describe "Password reset throttling" do
    let(:reset_path) { "/api/v1/auth/password_reset" }

    it "throttles after 3 requests per 5 minutes" do
      Rack::Attack.safelists.clear

      4.times do
        post reset_path, params: { email: "test@example.com" }, as: :json
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "Registration throttling" do
    let(:register_path) { "/api/v1/auth/register" }

    it "throttles after 3 requests per minute" do
      Rack::Attack.safelists.clear

      4.times do |i|
        post register_path, params: {
          email: "user#{i}@example.com",
          password: "password123",
          password_confirmation: "password123"
        }, as: :json
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
