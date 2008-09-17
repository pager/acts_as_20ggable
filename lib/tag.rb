class Tag < ActiveRecord::Base
  class HierarchyCycle < StandardError; end
    
  # TODO валидация того, что в начале и конце не пробелы
  SYMBOL = /[^#=\/]/.freeze
  
  has_many :taggings, :dependent => :destroy
  
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_format_of :name, :with => /\A#{SYMBOL}*\Z/
  validates_format_of :name, :with => /\A\S\Z|\A\S.*\S\Z/
  
  cattr_accessor :destroy_unused
  self.destroy_unused = false
  
  has_and_belongs_to_many :children, :class_name => 'Tag', :foreign_key => 'tag_id',
                                                           :association_foreign_key => 'child_id',
                                                           :join_table => 'tags_hierarchy'

  has_and_belongs_to_many :parents, :class_name => 'Tag', :foreign_key => 'child_id',
                                                           :association_foreign_key => 'tag_id',
                                                           :join_table => 'tags_hierarchy'

  has_and_belongs_to_many :transitive_children, :class_name => 'Tag', :foreign_key => 'tag_id',
                                                          :association_foreign_key => 'child_id',
                                                          :join_table => 'tags_transitive_hierarchy'

  has_and_belongs_to_many :synonyms, :class_name => 'Tag', :foreign_key => 'tag_id',
                                                           :association_foreign_key => 'synonym_id',
                                                           :join_table => 'tags_synonyms'

  named_scope :with_joined_hierarchy_and_synonyms, { 
   :joins => "LEFT OUTER JOIN tags_hierarchy AS tags_hierarchy_parent ON tags_hierarchy_parent.tag_id = #{Tag.table_name}.id "+
             "LEFT OUTER JOIN tags_hierarchy AS tags_hierarchy_child ON tags_hierarchy_child.child_id = #{Tag.table_name}.id "+
             "LEFT OUTER JOIN tags_synonyms AS tags_synonyms_left ON tags_synonyms_left.tag_id = #{Tag.table_name}.id " +
             "LEFT OUTER JOIN tags_synonyms AS tags_synonyms_right ON tags_synonyms_right.synonym_id = #{Tag.table_name}.id "
  }
 
  named_scope :with_joined_hierarchy, { 
   :joins => "LEFT OUTER JOIN tags_hierarchy AS tags_hierarchy_parent ON tags_hierarchy_parent.tag_id = #{Tag.table_name}.id "+
             "LEFT OUTER JOIN tags_hierarchy AS tags_hierarchy_child ON tags_hierarchy_child.child_id = #{Tag.table_name}.id"}
  
  
  # Scopes for "With joined hierarchy"
  named_scope :without_children, { :conditions => 'tags_hierarchy_parent.child_id IS NULL' }
  named_scope :without_parents, { :conditions => 'tags_hierarchy_child.tag_id IS NULL' }
  named_scope :with_parents, { :conditions => 'tags_hierarchy_child.tag_id IS NOT NULL' }
  named_scope :without_synonyms, { :conditions => 'tags_synonyms_left.synonym_id IS NULL AND tags_synonyms_right.tag_id IS NULL' }


  # LIKE is used for cross-database case-insensitivity
  def self.find_or_create_with_like_by_name(name)
    find_with_like_by_name(name) || create(:name => name)
  end

  def self.find_or_create_with_like_by_name!(name)
    find_with_like_by_name(name) || create!(:name => name)
  end

  def self.find_with_like_by_name(name)
    find(:first, :conditions => ["name LIKE ?", name])
  end
  
  def ==(object)
    super || (object.is_a?(Tag) && name == object.name)
  end
  
  def to_s
    name
  end
  
  def to_param
    name
  end
  
  def count
    read_attribute(:count).to_i
  end
  
  def marked?
    read_attribute(:mark).to_i == 1
  end
  
  class << self
    # Calculate the tag counts for all tags.
    #  :start_at - Restrict the tags to those created after a certain time
    #  :end_at - Restrict the tags to those created before a certain time
    #  :conditions - A piece of SQL conditions to add to the query
    #  :limit - The maximum number of tags to return
    #  :order - A piece of SQL to order by. Eg 'count desc' or 'taggings.created_at desc'
    #  :at_least - Exclude tags with a frequency less than the given value
    #  :at_most - Exclude tags with a frequency greater than the given value
    #  :mark_condition - Set 'mark' attribute on tags conforms this condition
    #                    primarliy used with per-user taggings like ['taggings.create_by_id = ?', user.id]

    def counts(options = {})
      find(:all, options_for_counts(options))
    end
    
    def options_for_counts(options = {})
      options.assert_valid_keys :start_at, :end_at, :conditions, :at_least, :at_most, :order, :limit, :joins, :mark_condition
      options = options.dup
      
      start_at = sanitize_sql(["#{Tagging.table_name}.created_at >= ?", options.delete(:start_at)]) if options[:start_at]
      end_at = sanitize_sql(["#{Tagging.table_name}.created_at <= ?", options.delete(:end_at)]) if options[:end_at]
      
      conditions = [
        options.delete(:conditions),
        start_at,
        end_at
      ].compact
      
      conditions = conditions.any? ? conditions.join(' AND ') : nil
      
      mark_condition = options.delete(:mark_condition)
      mark_condition = sanitize_sql(mark_condition) if mark_condition
      mark_select = "GROUP_CONCAT(DISTINCT IF((#{sanitize_sql(mark_condition)}), 1, NULL)) as mark" if mark_condition
      base_select = "#{Tag.table_name}.id, #{Tag.table_name}.name, COUNT(*) AS count"
      
      select = [ base_select, mark_select ].compact.join(', ') 
      
      joins = ["INNER JOIN #{Tagging.table_name} ON #{Tag.table_name}.id = #{Tagging.table_name}.tag_id"]
      joins << options.delete(:joins) if options[:joins]
      
      at_least  = sanitize_sql(['COUNT(*) >= ?', options.delete(:at_least)]) if options[:at_least]
      at_most   = sanitize_sql(['COUNT(*) <= ?', options.delete(:at_most)]) if options[:at_most]
      having    = [at_least, at_most].compact.join(' AND ')
      group_by  = "#{Tag.table_name}.id, #{Tag.table_name}.name HAVING COUNT(*) > 0"
      group_by << " AND #{having}" unless having.blank?
      
      { :select     => select,
        :joins      => joins.join(" "),
        :conditions => conditions,
        :group      => group_by
      }.update(options)
    end
  end
end
