# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Устанавливаем переменную окружения
set :environment, ENV['RAILS_ENV'] || 'development'
set :output, "#{path}/log/cron.log"

# Ежедневное напоминание о записях на завтра
every 1.day, at: '8:00 am' do
  runner "DailyRemindersJob.perform_later"
end

# Напоминания за 2 часа до записи
every 30.minutes do
  runner "BookingRemindersJob.perform_later"
end

# Ежедневные сводки для партнеров
every 1.day, at: '9:00 pm' do
  runner "NotificationService.send_daily_summaries"
end 