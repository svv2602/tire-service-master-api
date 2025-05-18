require 'csv'

namespace :db do
  desc 'Export table data to CSV files'
  task export_csv: :environment do
    puts 'Starting CSV export...'

    tables = ActiveRecord::Base.connection.tables.reject do |t|
      %w[schema_migrations ar_internal_metadata].include?(t)
    end

    export_path = Rails.root.join('db/csv_data')
    FileUtils.mkdir_p(export_path)

    tables.sort.each do |table_name|
      next if %w[schema_migrations ar_internal_metadata active_storage_blobs active_storage_attachments].include?(table_name)

      begin
        puts "Exporting #{table_name} table..."
        records = ActiveRecord::Base.connection.select_all("SELECT * FROM #{table_name}")
        next if records.empty?

        columns = records.columns
        
        CSV.open("#{export_path}/#{table_name}.csv", 'wb') do |csv|
          csv << columns
          records.each do |record|
            csv << record.values
          end
        end
      rescue => e
        puts "Error exporting table #{table_name}: #{e.message}"
      end
    end

    puts 'CSV export completed!'
  end

  desc 'Import table data from CSV files'
  task import_csv: :environment do
    puts 'Starting CSV import...'

    import_path = Rails.root.join('db/csv_data')

    Dir.glob("#{import_path}/*.csv").sort.each do |csv_file|
      table_name = File.basename(csv_file, '.csv')
      next if %w[schema_migrations ar_internal_metadata].include?(table_name)
      
      begin
        puts "Importing #{table_name} table..."
        
        csv_data = CSV.read(csv_file)
        columns = csv_data.shift

        if csv_data.any?
          # Disable constraints temporarily
          ActiveRecord::Base.connection.execute("ALTER TABLE #{table_name} DISABLE TRIGGER ALL;") rescue nil

          # Clear existing data
          ActiveRecord::Base.connection.execute("TRUNCATE #{table_name} CASCADE;") rescue nil

          # Insert new data
          csv_data.each do |row|
            values = row.map { |val| ActiveRecord::Base.connection.quote(val) }.join(',')
            ActiveRecord::Base.connection.execute(
              "INSERT INTO #{table_name} (#{columns.join(',')}) VALUES (#{values});"
            ) rescue puts "Error inserting row in #{table_name}: #{row.inspect}"
          end

          # Reset sequence if exists
          if columns.include?('id')
            max_id = csv_data.map { |r| r[columns.index('id')].to_i }.max
            if max_id
              ActiveRecord::Base.connection.execute(
                "SELECT setval('#{table_name}_id_seq', #{max_id});"
              ) rescue nil
            end
          end
          
          # Re-enable constraints
          ActiveRecord::Base.connection.execute("ALTER TABLE #{table_name} ENABLE TRIGGER ALL;") rescue nil
        end
      rescue => e
        puts "Error importing table #{table_name}: #{e.message}"
      end
    end

    puts 'CSV import completed!'
  end
end
