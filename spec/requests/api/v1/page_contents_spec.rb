require 'rails_helper'

RSpec.describe "Api::V1::PageContents", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/page_contents/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/api/v1/page_contents/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/api/v1/page_contents/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/api/v1/page_contents/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/api/v1/page_contents/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
