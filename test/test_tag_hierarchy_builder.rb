require File.dirname(__FILE__) + '/abstract_unit'

class TagHierarchyBuilderTest < Test::Unit::TestCase
  fixtures :tags, :tags_hierarchy, :tags_synonyms

  def hierarchy_blank?(options = {})
    except = [ options[:except] ].flatten.compact
    Tag.find(:all).all? { |tag| !except.include?(tag.name) || (tag.parents.empty? && tag.children.empty? && tag.synonyms.empty?) }.inspect
  end
  
  def test_dump_hierarchy
    hierarchy = TagHierarchyBuilder.dump_hierarchy
    hierarchy_fixture = [
      ['Nature', 'Animals', 'Domestic Animals', 'Cat', 'Kitten'],
      ['Nature', 'Animals', 'Horse'],
      ['People', 'Children'],
      ['People', 'Me'],
      ['People', 'Nude'],
    ]
    
    assert_equal hierarchy, hierarchy_fixture
  end
  
  def test_dump_synonyms
    synonyms = TagHierarchyBuilder.dump_synonyms
    synonyms_fixture = [
      ['Cat', 'Kitty', 'Pussy'], 
      ['Horse', 'Racehorse'], 
      ['Question', 'Problem']
    ]
    
    assert_equal synonyms, synonyms_fixture
  end

  def test_dump_orphans
    orphans = TagHierarchyBuilder.dump_orphans
    orphans_fixture = ['Bad', 'Crazy animal', 'Very good'] 
        
    assert_equal orphans, orphans_fixture
  end
  
  def test_rebuild_hierarchy_with_empty_specification
    TagHierarchyBuilder.rebuild_hierarchy([''])    
    assert hierarchy_blank? 
  end

  def test_rebuild_hierarchy_with_only_comments_in_specification
    TagHierarchyBuilder.rebuild_hierarchy(['#Comment one', '    # Comment two'])    
    assert hierarchy_blank? 
  end

  def test_rebuild_hierarchy_with_synonyms
    TagHierarchyBuilder.rebuild_hierarchy(['Cat = Racehorse = Problem'])    
    
    assert_equal Tag.find_with_like_by_name("Cat").synonyms.map(&:name).sort,
                 ['Racehorse', 'Problem'].sort
                 
    assert hierarchy_blank?(:except => 'Cat')
  end
  
  

end
