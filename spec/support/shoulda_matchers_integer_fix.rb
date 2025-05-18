# Из-за проблем с shoulda-matchers и методом empty? для Integer
# Добавляем методы для совместимости

class Integer
  def empty?
    false
  end
  
  def blank?
    false
  end
  
  def to_sym
    to_s.to_sym
  end
end
