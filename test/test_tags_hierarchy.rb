require File.dirname(__FILE__) + '/abstract_unit'

class TestTagsHierarchy < Test::Unit::TestCase
  fixtures :tags, :taggings, :videos, :users, :tags_transitive_hierarchy

  def test_find_tagged_with_subtags
    assert_equivalent [videos(:jonathan_good_cat), videos(:sam_kitten)], 
                      Video.find_tagged_with('"Domestic Animals"')
    
  end
end

