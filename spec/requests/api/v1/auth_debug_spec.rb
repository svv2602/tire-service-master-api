
require 'rails_helper'

RSpec.describe 'Auth Debugging', type: :request do
  include RequestSpecHelper
  include ServicePointsTestHelper

  describe 'Debug authentication' do
    it 'creates users with roles and authenticates' do
      # 1. Create roles
      admin_role = create(:user_role, name: 'administrator', description: 'Admin role')
      partner_role = create(:user_role, name: 'partner', description: 'Partner role')
      
      puts "Created admin role: #{admin_role.inspect}"
      puts "Created partner role: #{partner_role.inspect}"
      
      # 2. Create users with those roles
      admin_user = create(:user, 
        email: 'admin.debug@example.com', 
        password: 'password123', 
        role_id: admin_role.id
      )
      
      partner_user = create(:user, 
        email: 'partner.debug@example.com', 
        password: 'password123', 
        role_id: partner_role.id
      )
      
      puts "Created admin user: #{admin_user.inspect}, role_id: #{admin_user.role_id}"
      puts "Created partner user: #{partner_user.inspect}, role_id: #{partner_user.role_id}"
      
      # 3. Create partner
      partner = create(:partner, user: partner_user)
      puts "Created partner: #{partner.inspect}"
      
      # 4. Create auth token for admin
      admin_token = Auth::JsonWebToken.encode(user_id: admin_user.id)
      puts "Admin token: #{admin_token}"
      
      # 5. Create auth token for partner
      partner_token = Auth::JsonWebToken.encode(user_id: partner_user.id)
      puts "Partner token: #{partner_token}"
      
      # 6. Try to make authenticated request with admin token
      get '/api/v1/users', headers: { 'Authorization' => "Bearer #{admin_token}" }
      puts "Admin request status: #{response.status}"
      puts "Admin response body: #{response.body}"
      
      # 7. Try to make authenticated request with partner token
      get '/api/v1/partners', headers: { 'Authorization' => "Bearer #{partner_token}" }
      puts "Partner request status: #{response.status}"
      puts "Partner response body: #{response.body}"
    end
  end
end
