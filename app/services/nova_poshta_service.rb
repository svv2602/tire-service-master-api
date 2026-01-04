# frozen_string_literal: true

require 'net/http'
require 'json'

# Service for Nova Poshta API integration
# API Documentation: https://developers.novaposhta.ua/
class NovaPoshtaService
  API_URL = 'https://api.novaposhta.ua/v2.0/json/'.freeze

  class Error < StandardError; end
  class ApiError < Error; end
  class ValidationError < Error; end

  def initialize
    @api_key = ENV['NOVA_POSHTA_API_KEY']
    raise ValidationError, 'NOVA_POSHTA_API_KEY is not configured' if @api_key.blank?
  end

  # Track shipment by tracking number (TTN)
  # @param ttn [String] tracking number (14 digits)
  # @return [Hash] tracking information
  def track_shipment(ttn)
    raise ValidationError, 'TTN is required' if ttn.blank?

    response = call_api('TrackingDocument', 'getStatusDocuments', {
      Documents: [{ DocumentNumber: ttn.to_s.gsub(/\D/, ''), Phone: '' }]
    })

    return nil if response['data'].blank?

    document = response['data'].first
    {
      ttn: ttn,
      status: document['Status'],
      status_code: document['StatusCode'],
      status_description: status_description(document['StatusCode']),
      date_created: document['DateCreated'],
      date_received: document['RecipientDateTime'],
      warehouse_recipient: document['WarehouseRecipient'],
      city_recipient: document['CityRecipient'],
      sender_address: document['SenderAddress'],
      recipient_address: document['RecipientAddress'],
      actual_delivery_date: document['ActualDeliveryDate'],
      cost_on_site: document['DocumentCost'],
      weight: document['DocumentWeight'],
      payer_type: document['PayerType'],
      raw_data: document
    }
  end

  # Get list of cities for autocomplete
  # @param query [String] search query
  # @return [Array<Hash>] list of cities
  def search_cities(query, limit: 20)
    response = call_api('Address', 'getCities', {
      FindByString: query,
      Limit: limit
    })

    response['data'].map do |city|
      {
        ref: city['Ref'],
        name: city['Description'],
        name_ru: city['DescriptionRu'],
        area: city['Area'],
        settlement_type: city['SettlementType']
      }
    end
  end

  # Get list of warehouses in a city
  # @param city_ref [String] city reference from search_cities
  # @return [Array<Hash>] list of warehouses
  def get_warehouses(city_ref, limit: 100)
    response = call_api('Address', 'getWarehouses', {
      CityRef: city_ref,
      Limit: limit
    })

    response['data'].map do |warehouse|
      {
        ref: warehouse['Ref'],
        number: warehouse['Number'],
        description: warehouse['Description'],
        description_ru: warehouse['DescriptionRu'],
        short_address: warehouse['ShortAddress'],
        short_address_ru: warehouse['ShortAddressRu'],
        phone: warehouse['Phone'],
        type: warehouse['TypeOfWarehouse'],
        city_ref: warehouse['CityRef'],
        schedule: {
          monday: warehouse['Schedule']&.dig('Monday'),
          tuesday: warehouse['Schedule']&.dig('Tuesday'),
          wednesday: warehouse['Schedule']&.dig('Wednesday'),
          thursday: warehouse['Schedule']&.dig('Thursday'),
          friday: warehouse['Schedule']&.dig('Friday'),
          saturday: warehouse['Schedule']&.dig('Saturday'),
          sunday: warehouse['Schedule']&.dig('Sunday')
        },
        max_weight: warehouse['ReceivingLimitationsOnDimensions']&.dig('Weight'),
        position: {
          latitude: warehouse['Latitude'],
          longitude: warehouse['Longitude']
        }
      }
    end
  end

  # Calculate delivery cost
  # @param city_sender [String] sender city ref
  # @param city_recipient [String] recipient city ref
  # @param weight [Float] weight in kg
  # @param cost [Float] declared value in UAH
  # @return [Hash] delivery cost information
  def calculate_delivery_cost(city_sender:, city_recipient:, weight:, cost:, service_type: 'WarehouseWarehouse')
    response = call_api('InternetDocument', 'getDocumentPrice', {
      CitySender: city_sender,
      CityRecipient: city_recipient,
      Weight: weight.to_s,
      Cost: cost.to_s,
      ServiceType: service_type,
      CargoType: 'Cargo'
    })

    return nil if response['data'].blank?

    data = response['data'].first
    {
      cost: data['Cost'].to_f,
      cost_redelivery: data['CostRedelivery'].to_f,
      assessment_cost: data['AssessmentCost'].to_f,
      estimated_delivery_date: data['EstimatedDeliveryDate']
    }
  end

  # Get status description by status code
  def status_description(status_code)
    case status_code.to_s
    when '1' then 'Новое (Отправитель готовит груз)'
    when '2' then 'Удалено'
    when '3' then 'Не найдено'
    when '4' then 'В городе отправителя'
    when '5' then 'В пути'
    when '6' then 'В городе получателя'
    when '7' then 'В отделении'
    when '8' then 'На таможне'
    when '9' then 'Получено'
    when '10' then 'Возврат'
    when '11' then 'Возврат получен'
    when '102' then 'Отказ'
    when '103' then 'Посылка утилизирована'
    when '104' then 'Посылка не получена в срок'
    else 'Неизвестный статус'
    end
  end

  # Check if delivery is completed
  def delivery_completed?(status_code)
    %w[9 11].include?(status_code.to_s)
  end

  # Check if delivery failed
  def delivery_failed?(status_code)
    %w[2 3 10 102 103 104].include?(status_code.to_s)
  end

  # Check if package is in transit
  def in_transit?(status_code)
    %w[1 4 5 6 7 8].include?(status_code.to_s)
  end

  private

  def call_api(model_name, called_method, properties = {})
    uri = URI(API_URL)

    request_body = {
      apiKey: @api_key,
      modelName: model_name,
      calledMethod: called_method,
      methodProperties: properties
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = request_body.to_json

    response = http.request(request)
    result = JSON.parse(response.body)

    unless result['success']
      errors = result['errors']&.join(', ') || 'Unknown error'
      raise ApiError, "Nova Poshta API error: #{errors}"
    end

    result
  rescue JSON::ParserError => e
    raise ApiError, "Failed to parse Nova Poshta response: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise ApiError, "Nova Poshta API timeout: #{e.message}"
  rescue StandardError => e
    raise ApiError, "Nova Poshta API request failed: #{e.message}"
  end
end
