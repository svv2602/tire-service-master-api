require 'rails_helper'
require 'benchmark'

RSpec.describe 'Data Isolation Performance', type: :request do
  # Создаем роли
  let(:partner_role) { UserRole.find_or_create_by(name: 'partner') }
  let(:operator_role) { UserRole.find_or_create_by(name: 'operator') }
  let(:client_role) { UserRole.find_or_create_by(name: 'client') }

  # Создаем тестовые данные в большом количестве
  let!(:partners) { create_list(:partner, 10) }
  let!(:service_points) { partners.flat_map { |p| create_list(:service_point, 5, partner: p) } }
  let!(:clients) { create_list(:client, 100) }
  let!(:operators) { partners.flat_map { |p| create_list(:operator, 3, partner: p) } }
  
  # Создаем бронирования (по 20 на каждую точку)
  let!(:bookings) do
    service_points.flat_map do |sp|
      create_list(:booking, 20, service_point: sp, client: clients.sample)
    end
  end

  # Создаем отзывы (по 10 на каждую точку)
  let!(:reviews) do
    service_points.flat_map do |sp|
      create_list(:review, 10, service_point: sp, client: clients.sample)
    end
  end

  describe 'Partner Query Performance' do
    let(:partner) { partners.first }
    let(:partner_user) { partner.user }

    before do
      # Создаем привязки операторов к точкам партнера
      partner.operators.each_with_index do |operator, index|
        point = partner.service_points[index % partner.service_points.count]
        create(:operator_service_point, operator: operator, service_point: point)
      end
    end

    it 'performs clients query efficiently' do
      sign_in partner_user

      # Замеряем время выполнения запроса
      time = Benchmark.realtime do
        get '/api/v1/clients'
        expect(response).to have_http_status(:success)
      end

      # Проверяем что запрос выполняется быстро (менее 1 секунды)
      expect(time).to be < 1.0
      
      # Проверяем количество SQL запросов
      expect { get '/api/v1/clients' }.to perform_under(10).db_queries
    end

    it 'performs bookings query efficiently' do
      sign_in partner_user

      time = Benchmark.realtime do
        get '/api/v1/bookings'
        expect(response).to have_http_status(:success)
      end

      expect(time).to be < 1.0
      expect { get '/api/v1/bookings' }.to perform_under(10).db_queries
    end

    it 'performs reviews query efficiently' do
      sign_in partner_user

      time = Benchmark.realtime do
        get '/api/v1/reviews'
        expect(response).to have_http_status(:success)
      end

      expect(time).to be < 1.0
      expect { get '/api/v1/reviews' }.to perform_under(10).db_queries
    end

    it 'returns correct subset of data' do
      sign_in partner_user

      get '/api/v1/bookings'
      partner_bookings = JSON.parse(response.body)

      # Проверяем что возвращаются только бронирования партнера
      service_point_ids = partner.service_points.pluck(:id)
      returned_point_ids = partner_bookings.map { |b| b['service_point_id'] }.uniq

      expect(returned_point_ids).to all(be_in(service_point_ids))
      expect(partner_bookings.count).to be > 0
      expect(partner_bookings.count).to be < bookings.count # Не все бронирования
    end
  end

  describe 'Operator Query Performance' do
    let(:operator) { operators.first }
    let(:operator_user) { operator.user }
    let(:assigned_points) { operator.partner.service_points.first(2) }

    before do
      # Привязываем оператора к первым 2 точкам его партнера
      assigned_points.each do |point|
        create(:operator_service_point, operator: operator, service_point: point)
      end
    end

    it 'performs bookings query efficiently with point restrictions' do
      sign_in operator_user

      time = Benchmark.realtime do
        get '/api/v1/bookings'
        expect(response).to have_http_status(:success)
      end

      expect(time).to be < 1.0
      expect { get '/api/v1/bookings' }.to perform_under(10).db_queries
    end

    it 'returns only bookings from assigned service points' do
      sign_in operator_user

      get '/api/v1/bookings'
      operator_bookings = JSON.parse(response.body)

      # Проверяем что возвращаются только бронирования назначенных точек
      assigned_point_ids = assigned_points.pluck(:id)
      returned_point_ids = operator_bookings.map { |b| b['service_point_id'] }.uniq

      expect(returned_point_ids).to all(be_in(assigned_point_ids))
      expect(operator_bookings.count).to be > 0
      
      # Должно быть меньше чем у партнера (только назначенные точки)
      partner_booking_count = operator.partner.service_points.joins(:bookings).count
      expect(operator_bookings.count).to be < partner_booking_count
    end
  end

  describe 'Query Optimization with Indexes' do
    it 'uses database indexes for partner filtering' do
      partner = partners.first
      sign_in partner.user

      # Проверяем что запрос использует индекс на partner_id
      expect do
        get '/api/v1/service_points'
      end.to perform_under(5).db_queries

      # Проверяем план выполнения запроса (PostgreSQL specific)
      if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
        query = ServicePoint.joins(:bookings).where(partner_id: partner.id).to_sql
        explain_result = ActiveRecord::Base.connection.execute("EXPLAIN #{query}")
        
        # Проверяем что используется Index Scan, а не Seq Scan
        expect(explain_result.to_a.join).to include('Index')
      end
    end
  end

  describe 'Memory Usage' do
    it 'does not load excessive data into memory' do
      partner = partners.first
      sign_in partner.user

      # Замеряем использование памяти
      memory_before = `ps -o rss= -p #{Process.pid}`.to_i

      get '/api/v1/bookings'
      expect(response).to have_http_status(:success)

      memory_after = `ps -o rss= -p #{Process.pid}`.to_i
      memory_increase = memory_after - memory_before

      # Проверяем что увеличение памяти разумно (менее 50MB)
      expect(memory_increase).to be < 50_000 # KB
    end
  end

  describe 'Concurrent Access Performance' do
    it 'handles multiple partner requests efficiently' do
      threads = []
      results = []

      # Запускаем 5 одновременных запросов от разных партнеров
      5.times do |i|
        threads << Thread.new do
          partner = partners[i]
          sign_in partner.user

          time = Benchmark.realtime do
            get '/api/v1/bookings'
            expect(response).to have_http_status(:success)
          end

          results << time
        end
      end

      threads.each(&:join)

      # Проверяем что все запросы выполнились быстро
      expect(results.max).to be < 2.0 # Максимальное время
      expect(results.sum / results.count).to be < 1.0 # Среднее время
    end
  end

  private

  def sign_in(user)
    token = JWT.encode({ user_id: user.id }, Rails.application.credentials.secret_key_base, 'HS256')
    @auth_headers = { 'Authorization' => "Bearer #{token}" }
  end

  def get(path, **options)
    super(path, headers: @auth_headers, **options)
  end
end 