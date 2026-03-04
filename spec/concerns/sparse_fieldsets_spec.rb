# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SparseFieldsets do
  # Create a test class that includes the concern
  let(:controller_class) do
    Class.new do
      include SparseFieldsets

      attr_accessor :params

      def initialize(params = {})
        @params = ActionController::Parameters.new(params)
      end

      # Expose private methods for testing
      public :requested_fields, :sparse_fields_requested?, :apply_sparse_fieldsets, :filter_hash
    end
  end

  describe '#requested_fields' do
    it 'returns nil when no fields param present' do
      controller = controller_class.new({})
      expect(controller.requested_fields).to be_nil
    end

    it 'parses comma-separated fields' do
      controller = controller_class.new(fields: 'id,name,address')
      expect(controller.requested_fields).to eq(%w[id name address])
    end

    it 'strips whitespace from field names' do
      controller = controller_class.new(fields: 'id , name , address')
      expect(controller.requested_fields).to eq(%w[id name address])
    end

    it 'rejects blank fields' do
      controller = controller_class.new(fields: 'id,,name,')
      expect(controller.requested_fields).to eq(%w[id name])
    end
  end

  describe '#sparse_fields_requested?' do
    it 'returns false when no fields param present' do
      controller = controller_class.new({})
      expect(controller.sparse_fields_requested?).to be false
    end

    it 'returns true when fields param is present' do
      controller = controller_class.new(fields: 'id,name')
      expect(controller.sparse_fields_requested?).to be true
    end
  end

  describe '#apply_sparse_fieldsets' do
    it 'returns data unchanged when no fields requested' do
      controller = controller_class.new({})
      data = { 'id' => 1, 'name' => 'Test', 'address' => '123 St' }
      expect(controller.apply_sparse_fieldsets(data)).to eq(data)
    end

    it 'filters hash to include only requested fields plus id' do
      controller = controller_class.new(fields: 'name')
      data = { 'id' => 1, 'name' => 'Test', 'address' => '123 St', 'phone' => '555' }
      result = controller.apply_sparse_fieldsets(data)
      expect(result).to eq({ 'id' => 1, 'name' => 'Test' })
    end

    it 'filters array of hashes' do
      controller = controller_class.new(fields: 'name,address')
      data = [
        { 'id' => 1, 'name' => 'A', 'address' => '1 St', 'phone' => '111' },
        { 'id' => 2, 'name' => 'B', 'address' => '2 St', 'phone' => '222' }
      ]
      result = controller.apply_sparse_fieldsets(data)
      expect(result).to eq([
        { 'id' => 1, 'name' => 'A', 'address' => '1 St' },
        { 'id' => 2, 'name' => 'B', 'address' => '2 St' }
      ])
    end

    it 'filters paginated response with :data key' do
      controller = controller_class.new(fields: 'name')
      data = {
        data: [{ 'id' => 1, 'name' => 'A', 'phone' => '111' }],
        pagination: { current_page: 1 }
      }
      result = controller.apply_sparse_fieldsets(data)
      expect(result[:data]).to eq([{ 'id' => 1, 'name' => 'A' }])
      expect(result[:pagination]).to eq({ current_page: 1 })
    end

    it 'works with symbol keys' do
      controller = controller_class.new(fields: 'name')
      data = { id: 1, name: 'Test', address: '123 St' }
      result = controller.apply_sparse_fieldsets(data)
      expect(result).to eq({ id: 1, name: 'Test' })
    end
  end
end
