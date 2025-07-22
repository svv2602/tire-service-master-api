class NotificationChannelSettingSerializer < ActiveModel::Serializer
  attributes :id, :channel_type, :enabled, :priority, :retry_attempts, :retry_delay,
             :daily_limit, :rate_limit_per_minute, :created_at, :updated_at,
             :channel_name, :status_text, :status_color, :priority_text

  def channel_name
    object.channel_name
  end

  def status_text
    object.status_text
  end

  def status_color
    object.status_color
  end

  def priority_text
    object.priority_text
  end
end 