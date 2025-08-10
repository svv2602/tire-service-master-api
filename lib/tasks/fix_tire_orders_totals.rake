namespace :tire_orders do
  desc "Исправить total_amount для всех заказов с нулевой суммой"
  task fix_totals: :environment do
    puts "🔧 Начинаем исправление сумм заказов..."
    
    fixed_count = 0
    error_count = 0
    
    TireOrder.where(total_amount: [0, nil]).find_each do |order|
      begin
        old_total = order.total_amount
        
        # Принудительно пересчитываем сумму
        order.send(:calculate_total_amount)
        
        if order.total_amount != old_total
          order.save!
          puts "✅ Заказ #{order.id}: #{old_total} -> #{order.total_amount} UAH"
          fixed_count += 1
        else
          puts "⚪ Заказ #{order.id}: сумма корректна (#{order.total_amount} UAH)"
        end
      rescue => e
        puts "❌ Ошибка при исправлении заказа #{order.id}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\n📊 Результаты:"
    puts "✅ Исправлено заказов: #{fixed_count}"
    puts "❌ Ошибок: #{error_count}"
    puts "🎉 Задача завершена!"
  end
  
  desc "Показать статистику по суммам заказов"
  task stats: :environment do
    puts "📊 Статистика сумм заказов:"
    puts "Всего заказов: #{TireOrder.count}"
    puts "С нулевой суммой: #{TireOrder.where(total_amount: [0, nil]).count}"
    puts "С ненулевой суммой: #{TireOrder.where.not(total_amount: [0, nil]).count}"
    puts "Общая сумма всех заказов: #{TireOrder.sum(:total_amount)} UAH"
  end
end