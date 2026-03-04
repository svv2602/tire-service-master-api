# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DataGeneratorController production protection', type: :request do
  describe 'ensure_non_production! guard' do
    let(:controller) { Api::V1::Tests::DataGeneratorController.new }

    it 'raises an error in production environment' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      expect {
        controller.send(:ensure_non_production!)
      }.to raise_error(RuntimeError, /not available in production/)
    end

    it 'does not raise in development environment' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

      expect {
        controller.send(:ensure_non_production!)
      }.not_to raise_error
    end

    it 'does not raise in test environment' do
      # Current environment is test, so no stubbing needed
      expect {
        controller.send(:ensure_non_production!)
      }.not_to raise_error
    end
  end

  describe 'route protection' do
    it 'routes are defined in test environment' do
      expect(Rails.application.routes.recognize_path('/api/v1/tests/generate_data', method: :get)).to include(
        controller: 'api/v1/tests/data_generator',
        action: 'generate'
      )
    end
  end
end
