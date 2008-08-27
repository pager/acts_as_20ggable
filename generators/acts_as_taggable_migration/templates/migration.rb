class ActsAsTaggableMigration < ActiveRecord::Migration
  def self.up
    create_table :tags do |t|
      t.column :name, :string
    end
    
    create_table :taggings do |t|
      t.column :tag_id, :integer
      t.column :taggable_id, :integer
      
      # You should make sure that the column created is
      # long enough to store the required class names.
      t.column :taggable_type, :string
      
      t.column :created_at, :datetime
    end
    
    create_table :tags_hierarchy, :id => false do |t|
      t.column :tag_id, :integer
      t.column :child_id, :integer
    end

    create_table :tags_transitive_hierarchy, :id => false do |t|
      t.column :tag_id, :integer
      t.column :child_id, :integer
    end

    create_table :tags_synonyms, :id => false do |t|
      t.column :tag_id, :integer
      t.column :synonym_id, :integer
    end      
    
    add_index :taggings, :tag_id
    add_index :taggings, [:taggable_id, :taggable_type]
    add_index :tags, :name
  end
  
  def self.down
    drop_table :taggings
    drop_table :tags
    drop_table :tags_hierarchy
    drop_table :tags_transitive_hierarchy
    drop_table :tags_synonyms
  end
end
