require 'rails_helper'

RSpec.describe "API V1 Articles", type: :request do
  # Создаем тестовых пользователей с разными ролями
  let(:admin_user) { create(:user, :admin) }
  let(:client_user) { create(:user, :client) }
  let(:partner_user) { create(:user, :partner) }
  
  # Создаем тестовые статьи
  let!(:published_article) { create(:article, :published) }
  let!(:draft_article) { create(:article, :draft) }
  let!(:featured_article) { create(:article, :featured) }

  describe "GET /api/v1/articles" do
    context "как анонимный пользователь" do
      it "возвращает только опубликованные статьи" do
        get "/api/v1/articles"
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].count).to eq(2) # published + featured
        expect(json_response['data'].map { |a| a['status'] }).to all(eq('published'))
      end

      it "поддерживает фильтрацию по категории" do
        seasonal_article = create(:article, :published, category: 'seasonal')
        
        get "/api/v1/articles", params: { category: 'seasonal' }
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].count).to eq(1)
        expect(json_response['data'][0]['id']).to eq(seasonal_article.id)
      end

      it "поддерживает поиск по заголовку и содержимому" do
        create(:article, :published, title: "Как выбрать зимние шины", content: "Подробный гид по выбору")
        
        get "/api/v1/articles", params: { query: "зимние шины" }
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].count).to eq(1)
      end

      it "возвращает рекомендуемые статьи" do
        get "/api/v1/articles", params: { featured: true }
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].count).to eq(1)
        expect(json_response['data'][0]['featured']).to be_truthy
      end
    end

    context "как администратор" do
      it "возвращает все статьи включая черновики" do
        get "/api/v1/articles", params: { include_drafts: true }, headers: auth_headers(admin_user)
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].count).to eq(3) # published + draft + featured
      end
    end
  end

  describe "GET /api/v1/articles/:id" do
    context "опубликованная статья" do
      it "возвращает статью с полным содержимым" do
        get "/api/v1/articles/#{published_article.id}"
        
        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(published_article.id)
        expect(json_response['title']).to eq(published_article.title)
        expect(json_response['content']).to be_present
        expect(json_response['reading_time']).to be_present
      end

      it "увеличивает счетчик просмотров" do
        expect {
          get "/api/v1/articles/#{published_article.id}"
        }.to change { published_article.reload.views_count }.by(1)
      end
    end

    context "черновик статьи" do
      it "возвращает 404 для анонимного пользователя" do
        get "/api/v1/articles/#{draft_article.id}"
        
        expect(response).to have_http_status(:not_found)
      end

      it "возвращает статью для администратора" do
        get "/api/v1/articles/#{draft_article.id}", headers: auth_headers(admin_user)
        
        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(draft_article.id)
      end
    end
  end

  describe "POST /api/v1/articles" do
    let(:valid_attributes) do
      {
        article: {
          title: "Новая статья о шинах",
          content: "Подробное содержание статьи...",
          excerpt: "Краткое описание",
          category: "tips",
          status: "published",
          featured: false
        }
      }
    end

    context "как администратор" do
      it "создает новую статью" do
        expect {
          post "/api/v1/articles", params: valid_attributes, headers: auth_headers(admin_user)
        }.to change(Article, :count).by(1)
        
        expect(response).to have_http_status(:created)
        expect(json_response['title']).to eq(valid_attributes[:article][:title])
        expect(json_response['author_id']).to eq(admin_user.id)
      end

      it "автоматически вычисляет время чтения" do
        post "/api/v1/articles", params: valid_attributes, headers: auth_headers(admin_user)
        
        expect(response).to have_http_status(:created)
        expect(json_response['reading_time']).to be > 0
      end

      it "возвращает ошибки валидации при неверных данных" do
        invalid_attributes = valid_attributes
        invalid_attributes[:article][:title] = ""
        
        post "/api/v1/articles", params: invalid_attributes, headers: auth_headers(admin_user)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors']).to include('title')
      end
    end

    context "как обычный пользователь" do
      it "запрещает создание статьи" do
        post "/api/v1/articles", params: valid_attributes, headers: auth_headers(client_user)
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "без авторизации" do
      it "требует авторизации" do
        post "/api/v1/articles", params: valid_attributes
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/articles/categories" do
    it "возвращает список доступных категорий" do
      get "/api/v1/articles/categories"
      
      expect(response).to have_http_status(:ok)
      expect(json_response).to include(
        {
          'key' => 'seasonal',
          'name' => 'Сезонные советы',
          'description' => 'Советы по смене резины по сезонам',
          'icon' => '🍂'
        }
      )
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end

  def auth_headers(user)
    token = Auth::JsonWebToken.encode_access_token(user_id: user.id)
    { 'Authorization' => "Bearer #{token}" }
  end
end