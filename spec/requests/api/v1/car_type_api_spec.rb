require 'rails_helper'

RSpec.describe "Car Type API", type: :request do
  # Вместо создания новых объектов, используем find_or_create_by для большей гибкости
  before(:all) do
    @suv = CarType.find_or_create_by(name: 'SUV') do |ct|
      ct.description = 'Sport utility vehicle'
      ct.is_active = true
    end
    
    @sedan = CarType.find_or_create_by(name: 'Sedan') do |ct|
      ct.description = 'Standard sedan car'
      ct.is_active = true
    end
  end
  
  let(:client) { create(:client) }
  let(:suv) { @suv }
  let(:sedan) { @sedan }
  
  let(:auth_token) do
    user = client.user
    Auth::JsonWebToken.encode_access_token(user_id: user.id)
  end
  
  it "returns the list of car types" do
    # Request API to get list of car types
    get "/api/v1/car_types",
         headers: { 'Authorization': "Bearer #{auth_token}" }
         
    expect(response).to have_http_status(200)
    
    json = JSON.parse(response.body)
    expect(json.size).to be >= 2
    
    # Check that our car types are in the response
    suv_type = json.find { |t| t["name"] == "SUV" }
    sedan_type = json.find { |t| t["name"] == "Sedan" }
    
    expect(suv_type).not_to be_nil
    expect(sedan_type).not_to be_nil
    expect(suv_type["description"]).to eq("Sport utility vehicle")
    expect(sedan_type["description"]).to eq("Standard sedan car")
  end
  
  it "returns a specific car type" do
    # Request API to get specific car type
    get "/api/v1/car_types/#{suv.id}",
         headers: { 'Authorization': "Bearer #{auth_token}" }
         
    expect(response).to have_http_status(200)
    
    json = JSON.parse(response.body)
    expect(json["id"].to_s).to eq(suv.id.to_s)
    expect(json["name"]).to eq("SUV")
    expect(json["description"]).to eq("Sport utility vehicle")
  end
end
