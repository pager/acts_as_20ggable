class TagHierarchyBuilder
  def self.dump_tags
    ['# Категории'] +
    dump_hierarchy +
    ['# Синонимы'] +
    dump_synonyms +
    ['# Ещё не имеют связей'] +
    dump_orphans
  end
  
#protected
  def self.dump_hierarchy
    []
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
    Tag.with_joined_hierarchy.without_children.without_parents.without_synonyms.
        find(:all, :select => 'name', :order => 'name ASC').map(&:name)
  end
end