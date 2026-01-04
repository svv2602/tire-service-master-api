# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupplierReportService do
  let(:supplier) { create(:supplier, name: 'Test Supplier') }
  let(:partner) { create(:partner, company_name: 'Test Partner') }
  let(:date_from) { 30.days.ago.to_date }
  let(:date_to) { Date.current }

  let(:params) do
    {
      date_from: date_from.to_s,
      date_to: date_to.to_s,
      format: 'csv',
      report_type: 'full'
    }
  end

  subject(:service) { described_class.new(supplier, params) }

  describe '#initialize' do
    it 'sets default values when params are empty' do
      service = described_class.new(supplier, {})
      expect(service.instance_variable_get(:@date_from)).to eq(30.days.ago.to_date)
      expect(service.instance_variable_get(:@date_to)).to eq(Date.current)
      expect(service.instance_variable_get(:@format)).to eq('csv')
      expect(service.instance_variable_get(:@report_type)).to eq('full')
    end
  end

  describe '#generate' do
    context 'with invalid format' do
      let(:params) { { format: 'pdf' } }

      it 'raises ArgumentError' do
        expect { service.generate }.to raise_error(ArgumentError, /Invalid format/)
      end
    end

    context 'without supplier' do
      subject(:service) { described_class.new(nil, params) }

      it 'raises ArgumentError' do
        expect { service.generate }.to raise_error(ArgumentError, /Supplier is required/)
      end
    end

    context 'with date_from after date_to' do
      let(:params) do
        {
          date_from: Date.current.to_s,
          date_to: 30.days.ago.to_date.to_s,
          format: 'csv'
        }
      end

      it 'raises ArgumentError' do
        expect { service.generate }.to raise_error(ArgumentError, /date_from must be before date_to/)
      end
    end

    context 'with CSV format' do
      let(:params) { { format: 'csv' } }

      it 'generates CSV report' do
        result = service.generate
        expect(result).to be_a(String)
        expect(result).to include('Отчёт поставщика')
        expect(result).to include(supplier.name)
      end

      it 'includes summary section' do
        result = service.generate
        expect(result).to include('СВОДКА')
        expect(result).to include('Всего заказов')
        expect(result).to include('Выполнено заказов')
      end

      it 'includes orders section' do
        result = service.generate
        expect(result).to include('ЗАКАЗЫ')
      end

      it 'includes products section' do
        result = service.generate
        expect(result).to include('ТОВАРЫ')
      end
    end

    context 'with XLSX format' do
      let(:params) { { format: 'xlsx' } }

      it 'generates XLSX report' do
        result = service.generate
        expect(result).to be_a(String)
        # XLSX files start with PK (ZIP signature)
        expect(result[0..1]).to eq('PK')
      end
    end

    context 'with orders' do
      let!(:order) do
        create(:tire_order,
               supplier: supplier,
               partner: partner,
               status: 'completed',
               created_at: 5.days.ago)
      end

      let(:params) { { format: 'csv', date_from: 10.days.ago.to_date.to_s } }

      it 'includes order in report' do
        result = service.generate
        expect(result).to include(partner.company_name)
      end
    end

    context 'with products' do
      let!(:product) do
        create(:supplier_tire_product,
               supplier: supplier,
               brand_normalized: 'Michelin',
               original_model: 'Pilot Sport 4')
      end

      let(:params) { { format: 'csv' } }

      it 'includes product in report' do
        result = service.generate
        expect(result).to include('Michelin')
        expect(result).to include('Pilot Sport 4')
      end
    end
  end

  describe '#should_run_in_background?' do
    context 'with few records' do
      it 'returns false' do
        expect(service.should_run_in_background?).to be false
      end
    end

    context 'with many records' do
      before do
        allow(service).to receive(:estimate_row_count).and_return(15_000)
      end

      it 'returns true when row count exceeds threshold' do
        expect(service.should_run_in_background?).to be true
      end
    end
  end

  describe '#estimate_row_count' do
    context 'with orders report type' do
      let(:params) { { report_type: 'orders' } }

      before do
        create_list(:tire_order, 5, supplier: supplier, created_at: 5.days.ago)
      end

      it 'returns orders count' do
        expect(service.estimate_row_count).to eq(5)
      end
    end

    context 'with products report type' do
      let(:params) { { report_type: 'products' } }

      before do
        create_list(:supplier_tire_product, 10, supplier: supplier)
      end

      it 'returns products count' do
        expect(service.estimate_row_count).to eq(10)
      end
    end

    context 'with full report type' do
      let(:params) { { report_type: 'full' } }

      before do
        create_list(:tire_order, 5, supplier: supplier, created_at: 5.days.ago)
        create_list(:supplier_tire_product, 10, supplier: supplier)
      end

      it 'returns combined count plus extra rows' do
        # 5 orders + 10 products + 100 extra = 115
        expect(service.estimate_row_count).to eq(115)
      end
    end
  end

  describe 'private methods' do
    describe '#parse_date' do
      it 'parses valid date string' do
        result = service.send(:parse_date, '2025-01-15')
        expect(result).to eq(Date.new(2025, 1, 15))
      end

      it 'returns nil for blank value' do
        expect(service.send(:parse_date, '')).to be_nil
        expect(service.send(:parse_date, nil)).to be_nil
      end

      it 'returns nil for invalid date' do
        expect(service.send(:parse_date, 'not-a-date')).to be_nil
      end
    end

    describe '#format_order_number' do
      let(:order) { build(:tire_order, id: 123) }

      it 'formats order number with leading zeros' do
        result = service.send(:format_order_number, order)
        expect(result).to eq('TO-000123')
      end
    end

    describe '#translate_status' do
      it 'translates known statuses' do
        expect(service.send(:translate_status, 'pending')).to eq('Ожидает')
        expect(service.send(:translate_status, 'completed')).to eq('Завершён')
        expect(service.send(:translate_status, 'cancelled')).to eq('Отменён')
      end

      it 'returns original for unknown status' do
        expect(service.send(:translate_status, 'unknown')).to eq('unknown')
      end
    end

    describe '#format_currency' do
      it 'formats amount with currency symbol' do
        expect(service.send(:format_currency, 1500)).to eq('1500 ₴')
        expect(service.send(:format_currency, 1500.75)).to eq('1500.75 ₴')
      end

      it 'returns empty string for nil' do
        expect(service.send(:format_currency, nil)).to eq('')
      end
    end

    describe '#format_date' do
      it 'formats datetime' do
        datetime = DateTime.new(2025, 3, 15, 10, 30)
        expect(service.send(:format_date, datetime)).to eq('15.03.2025')
      end

      it 'returns empty string for nil' do
        expect(service.send(:format_date, nil)).to eq('')
      end
    end
  end
end
