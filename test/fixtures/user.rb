class User < ActiveRecord::Base
  has_many :posts
  has_many :photos
  
  has_many :subscriptions
  has_many :magazines, :through => :subscriptions
  
  has_many :videos
end
