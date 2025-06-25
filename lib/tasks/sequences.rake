# lib/tasks/sequences.rake
# Задачи для работы с последовательностями PostgreSQL

namespace :db do
  desc "Исправление последовательностей PostgreSQL после импорта данных"
  task fix_sequences: :environment do
    puts "🔧 Исправление последовательностей PostgreSQL..."
    
    begin
      results = DatabaseSequences.fix_all_sequences!
      
      if results.nil? || results.empty?
        puts "ℹ️  Проверка последовательностей пропущена (не PostgreSQL или test окружение)"
        next
      end
      
      puts "\n🎉 Готово!"
      puts "   Исправлено: #{results[:fixed]}"
      puts "   Ошибок: #{results[:errors]}"
      puts "   Всего проверено: #{results[:checked]}"
      
    rescue => e
      puts "❌ Ошибка при исправлении последовательностей: #{e.message}"
      exit 1
    end
  end
  
  desc "Проверка состояния последовательностей PostgreSQL"
  task check_sequences: :environment do
    puts "🔍 Проверка состояния последовательностей PostgreSQL..."
    
    begin
      problems = DatabaseSequences.check_all_sequences
      
      if problems.nil?
        puts "ℹ️  Проверка последовательностей пропущена (не PostgreSQL или test окружение)"
        next
      end
      
      problems_found = problems.count { |p| p[:has_problem] }
      
      problems.each do |problem|
        if problem[:has_problem]
          if problem[:error]
            puts "❌ #{problem[:table].ljust(25)} -> Ошибка: #{problem[:error]}"
          else
            puts "⚠️  #{problem[:table].ljust(25)} -> Проблема! Последовательность: #{problem[:current_sequence]}, Макс ID: #{problem[:max_id]}, Записей: #{problem[:record_count]}"
          end
        else
          puts "✅ #{problem[:table].ljust(25)} -> OK (#{problem[:current_sequence]} > #{problem[:max_id]}), Записей: #{problem[:record_count]}"
        end
      end
      
      puts "\n📊 Результат проверки:"
      if problems_found > 0
        puts "   ⚠️  Найдено проблем: #{problems_found}"
        puts "   💡 Запустите: rake db:fix_sequences"
      else
        puts "   ✅ Все последовательности в порядке!"
      end
      
    rescue => e
      puts "❌ Ошибка при проверке последовательностей: #{e.message}"
      exit 1
    end
  end
  
  desc "Показать детальную информацию о последовательностях"
  task sequences_info: :environment do
    puts "📋 Детальная информация о последовательностях PostgreSQL:"
    puts "=" * 80
    
    # Получаем все последовательности
    sequences = ActiveRecord::Base.connection.execute(
      "SELECT schemaname, sequencename, last_value, increment_by FROM pg_sequences WHERE schemaname = 'public'"
    )
    
    sequences.each do |seq|
      table_name = seq['sequencename'].gsub('_id_seq', '')
      
      if ActiveRecord::Base.connection.table_exists?(table_name)
        max_id = ActiveRecord::Base.connection.execute(
          "SELECT MAX(id) FROM #{table_name}"
        ).first['max'] || 0
        
        count = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) FROM #{table_name}"
        ).first['count']
        
        status = seq['last_value'].to_i > max_id.to_i ? "✅ OK" : "⚠️  ПРОБЛЕМА"
        
        puts "#{table_name.ljust(25)} | Последовательность: #{seq['last_value'].to_s.ljust(5)} | Макс ID: #{max_id.to_s.ljust(5)} | Записей: #{count.to_s.ljust(5)} | #{status}"
      end
    end
    
    puts "=" * 80
  end
end 