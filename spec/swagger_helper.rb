# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'Tire Service API',
        version: 'v1'
      },
      paths: {},
      components: {
        schemas: {
          Review: {
            type: :object,
            properties: {
              id: { type: :integer },
              rating: { type: :integer },
              comment: { type: :string },
              recommend: { type: :boolean },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime },
              client: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  first_name: { type: :string },
                  last_name: { type: :string }
                }
              }
            }
          },
          ReviewDetailed: {
            type: :object,
            properties: {
              id: { type: :integer },
              rating: { type: :integer },
              comment: { type: :string },
              recommend: { type: :boolean },
              created_at: { type: :string, format: :datetime },
              updated_at: { type: :string, format: :datetime },
              client: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  first_name: { type: :string },
                  last_name: { type: :string }
                }
              },
              booking: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  booking_date: { type: :string, format: :date },
                  start_time: { type: :string, format: :time },
                  end_time: { type: :string, format: :time }
                }
              },
              service_point: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  address: { type: :string }
                }
              }
            }
          },
          ReviewRequest: {
            type: :object,
            properties: {
              booking_id: { type: :integer },
              rating: { type: :integer },
              comment: { type: :string },
              recommend: { type: :boolean }
            },
            required: [:booking_id, :rating]
          },
          ReviewUpdateRequest: {
            type: :object,
            properties: {
              rating: { type: :integer },
              comment: { type: :string },
              recommend: { type: :boolean }
            },
            required: [:rating]
          },
          Pagination: {
            type: :object,
            properties: {
              current_page: { type: :integer },
              total_pages: { type: :integer },
              total_count: { type: :integer },
              per_page: { type: :integer }
            }
          },
          ErrorResponse: {
            type: :object,
            properties: {
              error: { type: :string },
              details: { type: :array, items: { type: :string } }
            }
          },
          ValidationErrorResponse: {
            type: :object,
            properties: {
              errors: {
                type: :object,
                additionalProperties: {
                  type: :array,
                  items: { type: :string }
                }
              }
            }
          }
        },
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT'
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :json
end 