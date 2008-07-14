class TagHierarchyBuilder
  class WrongSpecificationSyntax < StandardError; end

  def self.rebuild_transitive_closure
    # (5) :)
  end
  
  def self.rebuild_hierarchy(specification)
    # TODO save old hierarchy somewhere.
    
    Tag.transaction do
      # Clear join tables
      Tag.connection.execute('DELETE from tags_hierarchy')
      Tag.connection.execute('DELETE from tags_synonyms')
      
      specification.each do |line|
        next if line.blank?
        next if line =~ /^\s*#.*/ # If line is a comment
        begin
          if line =~ /^\s*#{Tag::SYMBOL}+\s*(=\s*#{Tag::SYMBOL}+\s*)+$/
            instantiate_synonyms(line)
            next
          end

          if line =~ /^\s*#{Tag::SYMBOL}+\s*(\/\s*#{Tag::SYMBOL}+\s*)+$/
            instantiate_hierarchy(line)
            next
          end
        
          raise WrongSpecificationSyntax.new("Line #{line}")
        rescue ActiveRecord::RecordInvalid => e
          raise WrongSpecificationSyntax.new("Line #{line}")
        end
      end
            
      hierarchy_acyclic? or raise Tag::HierarchyCycle
      
    end
  end
  
  # Input should be validated
  def self.instantiate_synonyms(line)
    # (2) TODO validate synonyms repetition? Like Cat = Kitty and Kitty = Cat
    # То есть ни один из «синонимов» не может быть в «стволе»
    # (3) FIXME а ведь можно намутить цикл при помощи сочетания синонимов и иерархии. 
    # Ни один из синонимов не может участвовать в «иерархии»
    # То есть нам нужна flat иерархия, flat ствол и flat синонимы
    # Причём хранить с номерами строк и выдавать ошибки «в такой-то строке»
    # (4) TODO Мы хотим гламурные сообщения о циклах. Для этого опять-таки нужно можно воспользоваться тем flatten.
    # Итого тесты. Сообщения об ошибках: 
    # "Левый синтаксис в строке 5"
    # "Синоним AAA из строки 15 участвует в иерархии в строках …" 
    # "Синоним BBB из строки 15 повторяется в строке …"    
    syns = line.split('=').map(&:strip)
    
    b = Tag.find_or_create_with_like_by_name!(syns.shift)
    syns.each do |syn|
      b.synonyms << Tag.find_or_create_with_like_by_name!(syn)
    end
  end

  def self.instantiate_hierarchy(line)
    line = line.split('/').map(&:strip)
    
    line.each_cons(2) do |(p, c)|
      p = Tag.find_or_create_with_like_by_name!(p)
      c = Tag.find_or_create_with_like_by_name!(c)
      
      raise Tag::HierarchyCycle.new if c.parents.include?(p) || c == p 
      
      c.parents << p
    end
  end

  def self.hierarchy_acyclic?
    # FIXME Again, naive and unoptimized
    tags = Tag.find(:all)
    visited_tags = []
    
    tags_status = tags.map { |x| [ x, :unvisited ] }.flatten
    tags_status = Hash[*tags_status]
           
    tags.each do |tag|
      next if tags_status[tag] != :unvisited
      (reclambda do |this, tag|        
        return false if tags_status[tag] == :processing
        tags_status[tag] = :processing
        tag.parents.any? do |child|
          this.call(child)
        end
        tags_status[tag] = :closed
      end).call(tag)
    end
    return true
  end
  
  # ==== DUMPER ======
  
  def self.dump_tags
    ['# Категории'] +
    dump_hierarchy.map { |chain| chain * ' / '} +
    ['', '# Синонимы'] +
    dump_synonyms.map { |chain| chain * ' = '} +
    ['', '# Ещё не имеют связей'] +
    dump_orphans
  end
  
  def self.dump_hierarchy
    tags_chains = Tag.with_joined_hierarchy.without_children.with_parents.find(:all).map { |x| [x] }

    # FIXME Soooo naive
    while chain = tags_chains.detect { |chain| !chain.first.parents.empty? }
      tags_chains.delete(chain)
      chain.first.parents.each do |parent|
        raise Tag::HierarchyCycle.new if chain.include?(parent)
        tags_chains << ([parent] + chain)
      end
    end
    
    tags_chains.map { |chain| chain.map { |tag| tag.name } }.sort_by { |chain| chain * ' ' }
  end  
  
  def self.dump_synonyms
    # FIXME N+1
    tags_with_synonyms = Tag.find(:all, 
                                  :joins => :synonyms, 
                                  :select => 'DISTINCT tags.*', 
                                  :order => 'name ASC')

    tags_with_synonyms.map { |t| 
      [ t.name ] + t.synonyms.find(:all, :order => 'name ASC').map(&:name)
    }
    
  end
  
  def self.dump_orphans
    # FIXME Benchmark it :)
    Tag.with_joined_hierarchy_and_synonyms.without_children.without_parents.without_synonyms.
        find(:all, :select => 'name', :order => 'name ASC').map(&:name)
  end
end

# FIXME move somewhere, uhm
def reclambda
  lambda do |f|
    f.call(f)
  end.call(lambda do |f|
             lambda do |this|
               lambda do |*args|
                 yield(this, *args)
               end
             end.call(lambda do |x|
                       f.call(f).call(x)
                      end)
           end)
end