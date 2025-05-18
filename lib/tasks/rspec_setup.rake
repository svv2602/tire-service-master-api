namespace :db do
  namespace :rspec do
    desc "Setup the test database for RSpec tests"
    task setup: :environment do
      return unless Rails.env.test?
      
      puts "Setting up test database for RSpec"
      
      # Check if database exists
      begin
        ActiveRecord::Base.connection
      rescue ActiveRecord::NoDatabaseError
        # Database does not exist, create it
        puts "Creating test database..."
        Rake::Task['db:create'].invoke
      end
      
      # Load schema
      puts "Loading schema..."
      Rake::Task['db:schema:load'].invoke
      
      # Run pending migrations if needed
      puts "Checking migrations..."
      migrations_status = `RAILS_ENV=test bin/rails db:migrate:status`
      if migrations_status.include?("down")
        puts "Running pending migrations..."
        Rake::Task['db:migrate'].invoke
      end
      
      puts "Test database setup completed!"
    end
  end
end

# Ensure the test database is properly set up before running RSpec
task 'spec' => 'db:rspec:setup'
