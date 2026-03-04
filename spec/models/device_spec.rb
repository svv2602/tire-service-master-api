# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Device, type: :model do
  let(:user) { create(:client_user) }
  let(:device) { create(:device, user: user) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:device, user: user) }

    it { is_expected.to validate_presence_of(:device_token) }
    it { is_expected.to validate_uniqueness_of(:device_token) }
    it { is_expected.to validate_presence_of(:platform) }
    it { is_expected.to validate_inclusion_of(:platform).in_array(%w[ios android]) }
  end

  describe 'scopes' do
    let!(:active_ios) { create(:device, user: user, platform: 'ios', is_active: true) }
    let!(:active_android) { create(:device, :android, user: user, is_active: true) }
    let!(:inactive_device) { create(:device, :inactive, user: user) }

    describe '.active' do
      it 'returns only active devices' do
        expect(Device.active).to include(active_ios, active_android)
        expect(Device.active).not_to include(inactive_device)
      end
    end

    describe '.ios' do
      it 'returns only iOS devices' do
        expect(Device.ios).to include(active_ios)
        expect(Device.ios).not_to include(active_android)
      end
    end

    describe '.android' do
      it 'returns only Android devices' do
        expect(Device.android).to include(active_android)
        expect(Device.android).not_to include(active_ios)
      end
    end
  end

  describe '#activate!' do
    let(:device) { create(:device, :inactive, user: user) }

    it 'activates the device and updates last_used_at' do
      device.activate!
      expect(device.is_active).to be true
      expect(device.last_used_at).to be_present
    end
  end

  describe '#deactivate!' do
    it 'deactivates the device' do
      device.deactivate!
      expect(device.is_active).to be false
    end
  end

  describe '#stale?' do
    it 'returns true when last_used_at is older than 90 days' do
      device.update!(last_used_at: 91.days.ago)
      expect(device.stale?).to be true
    end

    it 'returns false when last_used_at is recent' do
      device.update!(last_used_at: 1.day.ago)
      expect(device.stale?).to be false
    end

    it 'returns true when last_used_at is nil' do
      device.update!(last_used_at: nil)
      expect(device.stale?).to be true
    end
  end

  describe '#can_receive_push?' do
    it 'returns true for active, non-stale device' do
      expect(device.can_receive_push?).to be true
    end

    it 'returns false for inactive device' do
      device.update!(is_active: false)
      expect(device.can_receive_push?).to be false
    end

    it 'returns false for stale device' do
      device.update!(last_used_at: 100.days.ago)
      expect(device.can_receive_push?).to be false
    end
  end
end
