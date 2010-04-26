class Company < ActiveRecord::Base
  has_one :address, :as => :addressable, :dependent => :destroy
  has_many :relationships, :dependent => :destroy
  has_many :people, :through => :relationships
  has_many :projects
  has_many :phonenumbers, :as => :phonable, :dependent => :destroy
  belongs_to :creator, :class_name => 'Person'
  belongs_to :updater, :class_name => 'Person'
end

class Project < ActiveRecord::Base
  belongs_to :company
  has_and_belongs_to_many :people
end

class Relationship < ActiveRecord::Base
  belongs_to :company
  belongs_to :person
end

class Person < ActiveRecord::Base
  has_one :avatar, :dependent => :destroy
  has_one :address, :as => :addressable, :dependent => :destroy
  has_many :relationships, :dependent => :destroy
  has_many :companies, :through => :relationships
  has_many :phonenumbers, :as => :phonable, :dependent => :destroy
  has_and_belongs_to_many :projects
  
  def merge_exclude_associations
    [:avatar]
  end
end

class Phonenumber < ActiveRecord::Base
  belongs_to :phonable, :polymorphic => true
  
  def flat_number
    number.gsub(/[^0-9]/, '')
  end
  
  def merge_equal?(p)
    p.is_a?(Phonenumber) and
    country_code == p.country_code and
    flat_number = p.flat_number
  end
end

class Address < ActiveRecord::Base
  belongs_to :addressable, :polymorphic => true
end

class Avatar < ActiveRecord::Base
  belongs_to :person
end