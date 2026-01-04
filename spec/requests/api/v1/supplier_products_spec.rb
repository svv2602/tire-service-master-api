require 'rails_helper'

RSpec.describe 'Supplier Products API', type: :request do
  let!(:supplier_role) { UserRole.find_or_create_by!(name: 'supplier') }
  let!(:supplier_user) { create(:user, role: supplier_role) }
  let!(:supplier) { create(:supplier, user: supplier_user) }
  let(:headers) { auth_headers(supplier_user.reload) }

  let!(:admin_role) { UserRole.find_or_create_by!(name: 'admin') }
  let!(:admin_user) { create(:user, role: admin_role) }
  let(:admin_headers) { auth_headers(admin_user.reload) }

  let!(:products) { create_list(:supplier_tire_product, 5, supplier: supplier) }
  let(:product) { products.first }

  describe 'GET /api/v1/suppliers/:supplier_id/manage/products' do
    context 'as supplier' do
      it 'returns list of products' do
        get "/api/v1/suppliers/#{supplier.id}/manage/products", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['products']).to be_an(Array)
        expect(json['products'].length).to eq(5)
        expect(json['pagination']).to be_present
        expect(json['stats']).to be_present
        expect(json['stats']['total']).to eq(5)
      end

      it 'filters by brand' do
        products.first.update!(brand_normalized: 'TestBrand')

        get "/api/v1/suppliers/#{supplier.id}/manage/products", params: { brand: 'TestBrand' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['products'].length).to eq(1)
      end

      it 'filters by in_stock' do
        products.first.update!(in_stock: false)

        get "/api/v1/suppliers/#{supplier.id}/manage/products", params: { in_stock: 'true' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['products'].length).to eq(4)
      end

      it 'searches by text' do
        get "/api/v1/suppliers/#{supplier.id}/manage/products", params: { search: product.original_brand }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['products']).not_to be_empty
      end
    end

    context 'as admin' do
      it 'can access any supplier products' do
        get "/api/v1/suppliers/#{supplier.id}/manage/products", headers: admin_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /api/v1/suppliers/:supplier_id/products/:id' do
    it 'returns product details' do
      get "/api/v1/suppliers/#{supplier.id}/manage/products/#{product.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['product']['id']).to eq(product.id)
      expect(json['product']).to have_key('orders_count')
      expect(json['product']).to have_key('total_sold')
    end
  end

  describe 'PATCH /api/v1/suppliers/:supplier_id/products/:id' do
    it 'updates product price' do
      patch "/api/v1/suppliers/#{supplier.id}/manage/products/#{product.id}",
            params: { product: { price_uah: 5999.99 } },
            headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(product.reload.price_uah.to_f).to eq(5999.99)
    end

    it 'updates stock status' do
      patch "/api/v1/suppliers/#{supplier.id}/manage/products/#{product.id}",
            params: { product: { in_stock: false, stock_status: 'out_of_stock' } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(product.reload.in_stock).to be false
    end
  end

  describe 'DELETE /api/v1/suppliers/:supplier_id/products/:id' do
    it 'archives product (soft delete)' do
      delete "/api/v1/suppliers/#{supplier.id}/manage/products/#{product.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(product.reload.in_stock).to be false
      expect(product.stock_status).to eq('archived')
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/products/:id/toggle_active' do
    it 'toggles product active status' do
      product.update!(in_stock: true)

      post "/api/v1/suppliers/#{supplier.id}/manage/products/#{product.id}/toggle_active", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(product.reload.in_stock).to be false
    end
  end

  describe 'POST /api/v1/suppliers/:supplier_id/products/bulk_update' do
    it 'updates multiple products' do
      updates = products.first(3).map do |p|
        { id: p.id, price_uah: 1000 + p.id }
      end

      post "/api/v1/suppliers/#{supplier.id}/manage/products/bulk_update",
           params: { updates: updates },
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['results']['updated']).to eq(3)
      expect(json['results']['failed']).to eq(0)
    end

    it 'handles partial failures' do
      updates = [
        { id: products.first.id, price_uah: 2000 },
        { id: 999999, price_uah: 3000 } # Non-existent product
      ]

      post "/api/v1/suppliers/#{supplier.id}/manage/products/bulk_update",
           params: { updates: updates },
           headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['results']['updated']).to eq(1)
      expect(json['results']['failed']).to eq(1)
    end

    it 'rejects too many updates' do
      updates = (1..101).map { |i| { id: i, price_uah: 1000 } }

      post "/api/v1/suppliers/#{supplier.id}/manage/products/bulk_update",
           params: { updates: updates },
           headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'requires updates parameter' do
      post "/api/v1/suppliers/#{supplier.id}/manage/products/bulk_update",
           params: {},
           headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end
end
