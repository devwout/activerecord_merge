ActiveRecord::Schema.define do
  
  create_table :companies, :force => true do |t|
    t.string :name
    t.string :alpha
    t.integer :status_code
    t.timestamps
    t.integer :creator_id, :updater_id
  end
  
  create_table :projects, :force => true do |t|
    t.belongs_to :company
    t.string :name
  end
  
  create_table :people_projects, :force => true, :id => false do |t|
    t.belongs_to :project
    t.belongs_to :person
  end
  
  create_table :relationships, :force => true do |t|
    t.belongs_to :company
    t.belongs_to :person
  end
  
  create_table :people, :force => true do |t|
    t.belongs_to :company
    t.string :first_name
    t.string :last_name
  end
  
  create_table :phonenumbers, :force => true do |t|
    t.belongs_to :phonable, :polymorphic => true
    t.string :description
    t.string :country_code
    t.string :number
  end
  
  create_table :addresses, :force => true do |t|
    t.belongs_to :addressable, :polymorphic => true
    t.string :street, :zip, :city
  end
  
  create_table :avatars, :force => true do |t|
    t.belongs_to :person
    t.string :url
    t.string :alt
  end
  
end