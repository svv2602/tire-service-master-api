# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::ChannelRouter do
  let(:router) { described_class.new }

  describe '#determine_channels' do
    context 'with explicitly requested channels' do
      it 'returns requested channels if valid' do
        notification_type = double(name: 'test')
        channels = router.determine_channels(notification_type, %w[email push])

        expect(channels).to eq(%w[email push])
      end

      it 'filters out invalid channels' do
        notification_type = double(name: 'test')
        channels = router.determine_channels(notification_type, %w[email invalid_channel push])

        expect(channels).to eq(%w[email push])
      end
    end

    context 'with notification type settings' do
      it 'uses channels from notification type' do
        notification_type = double(
          name: 'test',
          is_push?: true,
          is_email?: true,
          is_sms?: false,
          is_telegram?: false
        )

        channels = router.determine_channels(notification_type, nil)

        expect(channels).to contain_exactly('push', 'email')
      end
    end

    context 'with default channels' do
      it 'returns default channels for booking_created' do
        notification_type = double(
          name: 'booking_created',
          is_push?: false,
          is_email?: false,
          is_sms?: false,
          is_telegram?: false
        )

        channels = router.determine_channels(notification_type, nil)

        expect(channels).to eq(%w[push email])
      end

      it 'returns default channels for booking_reminder' do
        notification_type = double(
          name: 'booking_reminder',
          is_push?: false,
          is_email?: false,
          is_sms?: false,
          is_telegram?: false
        )

        channels = router.determine_channels(notification_type, nil)

        expect(channels).to eq(%w[push email sms])
      end
    end
  end

  describe '#channel_available?' do
    it 'returns true for available channels' do
      %w[email push sms telegram].each do |channel|
        expect(router.channel_available?(channel)).to be true
      end
    end

    it 'returns false for unknown channels' do
      expect(router.channel_available?('unknown')).to be false
      expect(router.channel_available?('whatsapp')).to be false
    end
  end

  describe '#recipient_supports_channel?' do
    let(:user) { instance_double(User, email: 'test@example.com', phone: '+380501234567') }
    let(:client) { instance_double(Client, email: nil, phone: nil, user: user) }

    describe 'email channel' do
      it 'returns true if user has email' do
        expect(router.recipient_supports_channel?(user, 'email')).to be true
      end

      it 'returns true if client has user with email' do
        expect(router.recipient_supports_channel?(client, 'email')).to be true
      end

      it 'returns false if no email' do
        user_without_email = instance_double(User, email: nil, phone: '+380501234567')
        expect(router.recipient_supports_channel?(user_without_email, 'email')).to be false
      end
    end

    describe 'sms channel' do
      it 'returns true if user has phone' do
        expect(router.recipient_supports_channel?(user, 'sms')).to be true
      end

      it 'returns false if no phone' do
        user_without_phone = instance_double(User, email: 'test@example.com', phone: nil)
        expect(router.recipient_supports_channel?(user_without_phone, 'sms')).to be false
      end
    end

    describe 'telegram channel' do
      it 'returns true if user has active telegram subscription' do
        subscription = instance_double(TelegramSubscription, can_receive_notifications?: true)
        allow(user).to receive(:telegram_subscription).and_return(subscription)

        expect(router.recipient_supports_channel?(user, 'telegram')).to be true
      end

      it 'returns false if no telegram subscription' do
        allow(user).to receive(:telegram_subscription).and_return(nil)

        expect(router.recipient_supports_channel?(user, 'telegram')).to be false
      end
    end

    describe 'push channel' do
      it 'always returns true for registered users' do
        expect(router.recipient_supports_channel?(user, 'push')).to be true
      end
    end
  end

  describe '#filter_channels_for_recipient' do
    let(:user) do
      instance_double(
        User,
        email: 'test@example.com',
        phone: nil,
        telegram_subscription: nil
      )
    end

    it 'returns only supported channels' do
      channels = router.filter_channels_for_recipient(user, %w[email push sms telegram])

      expect(channels).to contain_exactly('email', 'push')
    end
  end

  describe '#default_channels_for' do
    it 'returns correct defaults for known types' do
      expect(router.default_channels_for('booking_created')).to eq(%w[push email])
      expect(router.default_channels_for('booking_confirmed')).to eq(%w[push email sms])
      expect(router.default_channels_for('operator_assignment')).to eq(%w[email telegram push])
    end

    it 'returns push as default for unknown types' do
      expect(router.default_channels_for('unknown_type')).to eq(%w[push])
    end
  end
end
