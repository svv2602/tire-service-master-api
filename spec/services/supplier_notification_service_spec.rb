require 'rails_helper'

RSpec.describe SupplierNotificationService do
  let(:supplier) { create(:supplier, email: 'supplier@test.com', telegram_chat_id: '123456') }
  let(:supplier_without_contacts) { create(:supplier, email: nil, telegram_chat_id: nil) }
  let(:partner) { create(:partner) }
  let(:order) { create(:tire_order, supplier: supplier, partner: partner) }

  # Mock TelegramService globally to avoid initialization issues
  let(:telegram_service) { instance_double(TelegramService) }

  before do
    allow(TelegramService).to receive(:new).and_return(telegram_service)
    allow(telegram_service).to receive(:send_message)
  end

  describe '#notify_new_order' do
    context 'when supplier has email and telegram' do
      it 'sends email notification' do
        service = described_class.new(supplier)

        expect {
          service.notify_new_order(order)
        }.to have_enqueued_mail(SupplierMailer, :new_order)
      end

      it 'sends telegram notification' do
        expect(telegram_service).to receive(:send_message).with(supplier.telegram_chat_id, anything)

        service = described_class.new(supplier)
        service.notify_new_order(order)
      end
    end

    context 'when supplier has no contacts' do
      it 'does not send email notification' do
        service = described_class.new(supplier_without_contacts)

        expect {
          service.notify_new_order(order)
        }.not_to have_enqueued_mail(SupplierMailer, :new_order)
      end

      it 'does not send telegram notification' do
        expect(telegram_service).not_to receive(:send_message)

        service = described_class.new(supplier_without_contacts)
        service.notify_new_order(order)
      end
    end

    context 'when supplier is nil' do
      it 'does nothing without raising error' do
        service = described_class.new(nil)

        expect {
          service.notify_new_order(order)
        }.not_to raise_error
      end
    end
  end

  describe '#notify_order_cancelled' do
    it 'sends email with cancellation reason' do
      service = described_class.new(supplier)

      expect {
        service.notify_order_cancelled(order, 'Out of stock')
      }.to have_enqueued_mail(SupplierMailer, :order_cancelled)
    end

    it 'sends telegram notification' do
      expect(telegram_service).to receive(:send_message).with(supplier.telegram_chat_id, anything)

      service = described_class.new(supplier)
      service.notify_order_cancelled(order, 'Out of stock')
    end
  end

  describe '#notify_order_status_changed' do
    it 'sends notification with old and new status' do
      service = described_class.new(supplier)

      expect {
        service.notify_order_status_changed(order, 'submitted', 'confirmed')
      }.to have_enqueued_mail(SupplierMailer, :order_status_changed)
    end
  end

  describe '#notify_low_stock' do
    let(:products) do
      create_list(:supplier_tire_product, 3, supplier: supplier, stock_status: 'low')
    end

    it 'sends notification about low stock products' do
      service = described_class.new(supplier)

      expect {
        service.notify_low_stock(products)
      }.to have_enqueued_mail(SupplierMailer, :low_stock_alert)
    end

    it 'does not send notification when products array is empty' do
      service = described_class.new(supplier)

      expect {
        service.notify_low_stock([])
      }.not_to have_enqueued_mail(SupplierMailer, :low_stock_alert)
    end
  end

  describe '#notify_price_upload_completed' do
    let(:statistics) { { processed_count: 100, success_count: 98, errors_count: 2 } }

    it 'sends notification about successful price upload' do
      service = described_class.new(supplier)

      expect {
        service.notify_price_upload_completed('v1.2.3', statistics)
      }.to have_enqueued_mail(SupplierMailer, :price_upload_completed)
    end
  end

  describe '#notify_price_upload_failed' do
    it 'sends notification about failed price upload' do
      service = described_class.new(supplier)

      expect {
        service.notify_price_upload_failed('Invalid XML format')
      }.to have_enqueued_mail(SupplierMailer, :price_upload_failed)
    end
  end

  describe 'telegram message formatting' do
    it 'formats new order message correctly' do
      expect(telegram_service).to receive(:send_message) do |chat_id, message|
        expect(chat_id).to eq(supplier.telegram_chat_id)
        expect(message).to include('Новый заказ')
        expect(message).to include(order.order_number)
      end

      service = described_class.new(supplier)
      service.notify_new_order(order)
    end

    it 'formats order cancelled message correctly' do
      expect(telegram_service).to receive(:send_message) do |chat_id, message|
        expect(chat_id).to eq(supplier.telegram_chat_id)
        expect(message).to include('Заказ отменён')
        expect(message).to include('Test reason')
      end

      service = described_class.new(supplier)
      service.notify_order_cancelled(order, 'Test reason')
    end
  end
end
