require 'rails_helper'

RSpec.describe 'API::V1::ServicePoints с индивидуальными расписаниями постов', type: :request do
  let(:user) { create(:user, :admin) }
  let(:partner) { create(:partner, user: user) }
  let(:service_point) { create(:service_point, partner: partner) }
  let(:headers) { generate_auth_headers(user).merge('Content-Type' => 'application/json') }

  describe 'POST /api/v1/partners/:partner_id/service_points' do
    let(:valid_attributes) do
      {
        service_point: {
          name: 'Тестовая точка',
          address: 'ул. Тестовая, 1',
          city_id: create(:city).id,
          contact_phone: '+380501234567',
          service_posts_attributes: [
            {
              name: 'Обычный пост',
              post_number: 1,
              slot_duration: 60,
              has_custom_schedule: false
            },
            {
              name: 'Пост с индивидуальным расписанием',
              post_number: 2,
              slot_duration: 30,
              has_custom_schedule: true,
              working_days: {
                monday: true,
                tuesday: false,
                wednesday: true,
                thursday: true,
                friday: false,
                saturday: false,
                sunday: false
              },
              custom_hours: {
                start: '10:00',
                end: '19:00'
              }
            }
          ]
        }
      }
    end

    it 'создает точку обслуживания с постами с индивидуальными расписаниями' do
      expect {
        post "/api/v1/partners/#{partner.id}/service_points", 
             params: valid_attributes.to_json, 
             headers: headers
      }.to change(ServicePoint, :count).by(1)
       .and change(ServicePost, :count).by(2)

      expect(response).to have_http_status(:created)
      
      service_point = ServicePoint.last
      expect(service_point.service_posts.count).to eq(2)

      regular_post = service_point.service_posts.find_by(post_number: 1)
      expect(regular_post.has_custom_schedule).to be false
      expect(regular_post.working_days).to be_nil
      expect(regular_post.custom_hours).to be_nil

      custom_post = service_point.service_posts.find_by(post_number: 2)
      expect(custom_post.has_custom_schedule).to be true
      expect(custom_post.working_days).to eq({
        'monday' => true,
        'tuesday' => false,
        'wednesday' => true,
        'thursday' => true,
        'friday' => false,
        'saturday' => false,
        'sunday' => false
      })
      expect(custom_post.custom_hours).to eq({
        'start' => '10:00',
        'end' => '19:00'
      })
    end

    context 'с некорректными данными индивидуального расписания' do
      let(:invalid_attributes) do
        {
          service_point: {
            name: 'Тестовая точка',
            address: 'ул. Тестовая, 1',
            city_id: create(:city).id,
            service_posts_attributes: [
              {
                name: 'Пост с ошибкой',
                post_number: 1,
                slot_duration: 60,
                has_custom_schedule: true,
                working_days: {
                  monday: false,
                  tuesday: false,
                  wednesday: false,
                  thursday: false,
                  friday: false,
                  saturday: false,
                  sunday: false
                },
                custom_hours: {
                  start: '19:00',
                  end: '18:00'
                }
              }
            ]
          }
        }
      end

      it 'возвращает ошибки валидации' do
        post "/api/v1/partners/#{partner.id}/service_points", 
             params: invalid_attributes.to_json, 
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to be_present
      end
    end
  end

  describe 'PATCH /api/v1/partners/:partner_id/service_points/:id' do
    let!(:existing_post) do
      create(:service_post, 
        service_point: service_point,
        post_number: 1,
        has_custom_schedule: false
      )
    end

    let(:update_attributes) do
      {
        service_point: {
          service_posts_attributes: [
            {
              id: existing_post.id,
              has_custom_schedule: true,
              working_days: {
                monday: true,
                tuesday: true,
                wednesday: false,
                thursday: true,
                friday: true,
                saturday: false,
                sunday: false
              },
              custom_hours: {
                start: '09:00',
                end: '17:00'
              }
            }
          ]
        }
      }
    end

    it 'обновляет пост с индивидуальным расписанием' do
      patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}", 
            params: update_attributes.to_json, 
            headers: headers

      expect(response).to have_http_status(:ok)
      
      existing_post.reload
      expect(existing_post.has_custom_schedule).to be true
      expect(existing_post.working_days['monday']).to be true
      expect(existing_post.working_days['wednesday']).to be false
      expect(existing_post.custom_hours['start']).to eq('09:00')
      expect(existing_post.custom_hours['end']).to eq('17:00')
    end

    it 'возвращает обновленные данные поста в ответе' do
      patch "/api/v1/partners/#{partner.id}/service_points/#{service_point.id}", 
            params: update_attributes.to_json, 
            headers: headers

      response_data = response.parsed_body
      post_data = response_data['service_posts'].find { |p| p['id'] == existing_post.id }
      
      expect(post_data['has_custom_schedule']).to be true
      expect(post_data['working_days']).to include('monday' => true, 'wednesday' => false)
      expect(post_data['custom_hours']).to include('start' => '09:00', 'end' => '17:00')
    end
  end

  describe 'GET /api/v1/service_points/:id' do
    let!(:custom_post) do
      create(:service_post, 
        service_point: service_point,
        post_number: 1,
        has_custom_schedule: true,
        working_days: {
          'monday' => true,
          'tuesday' => false,
          'wednesday' => true
        },
        custom_hours: {
          'start' => '10:00',
          'end' => '18:00'
        }
      )
    end

    it 'возвращает данные индивидуального расписания в ответе' do
      get "/api/v1/service_points/#{service_point.id}", headers: headers

      expect(response).to have_http_status(:ok)
      
      response_data = response.parsed_body
      post_data = response_data['service_posts'].first
      
      expect(post_data['has_custom_schedule']).to be true
      expect(post_data['working_days']).to eq({
        'monday' => true,
        'tuesday' => false,
        'wednesday' => true
      })
      expect(post_data['custom_hours']).to eq({
        'start' => '10:00',
        'end' => '18:00'
      })
      expect(post_data['working_days_list']).to contain_exactly('monday', 'wednesday')
    end
  end
end 