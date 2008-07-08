require File.dirname(__FILE__) + '/abstract_unit'

class TagHierarchyBuilderTest < Test::Unit::TestCase
  fixtures :tags, :tags_hierarchy, :tags_synonyms

  def test_dump_hierarchy
    hierarchy = TagHierarchyBuilder.dump_hierarchy
    hierarchy_fixture = [
      ['People', 'Children'],
      ['People', 'Me'],
      ['People', 'Nude'],
      ['Nature', 'Animals', 'Horse'],
      ['Nature', 'Animals', 'Domestic Animals', 'Cat', 'Kitty'],
    ]
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
end
