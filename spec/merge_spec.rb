require 'yaml'
require 'rubygems'
require 'activerecord'

spec_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift spec_dir, File.join(spec_dir, '..', 'lib')

ActiveRecord::Base.establish_connection(YAML.load(File.read(File.join(spec_dir, "database.yml"))))

require 'schema'
require 'models'
require 'merge'

describe Merge do
  
  it 'should ignore created_at and updated_at in merge_equal' do
    c = Company.create!(:name => "Myname", :created_at => Date.civil(2008,1,10), :updated_at => Date.civil(2008,2,4))
    c.should be_merge_equal(Company.create!(:name => "Myname"))
  end
    
  describe "attributes only" do
    
    it 'should overwrite blank attributes' do
      c1 = Company.create!(:name => "company1", :alpha => "")
      c2 = Company.create!(:name => "company2", :alpha => "C2")
      c3 = Company.create!(:name => "company3", :alpha => "C3", :status_code => 2)
      c1.merge!(c2, c3)
      c1.name.should == "company1"
      c1.alpha.should == "C2"
      c1.status_code.should == 2
      Company.all(:conditions => {:id => [c2.id, c3.id]}).should == []
    end
    
    it 'should overwrite blank foreign keys' do
      c = Company.create!
      p1 = Project.create!(:name => "Website")
      p2 = Project.create!(:name => "Site", :company => c)
      p1.merge!(p2)
      p1.name.should == "Website"
      p1.company.should == c
    end
    
    it 'should keep existing foreign keys' do
      c1 = Company.create!
      c2 = Company.create!
      p1 = Project.create!(:company => c1)
      p2 = Project.create!(:company => c2)
      p1.merge!(p2)
      p1.company.should == c1
      c2.projects.should be_empty
    end
    
    it 'should ignore creator and updater metadata' do
      c1 = Company.create!
      p1 = Person.create!
      c2 = Company.create!(:creator => p1, :updater => p1)
      c1.merge!(c2)
      c1.creator.should be_nil
      c1.updater.should be_nil
    end
    
  end
  
  describe "has_many associations" do
    
    it 'should associate all related objects to the master' do
      c1 = Company.create!
      c2 = Company.create!
      c3 = Company.create!
      p1 = Person.create!(:relationships => [Relationship.new(:company => c1)])
      p2 = Person.create!(:relationships => [Relationship.new(:company => c2)])
      p3 = Person.create!(:relationships => [Relationship.new(:company => c3)])
      p4 = Person.create!(:relationships => [Relationship.new(:company => c3)])
      c1.merge!(c2, c3)
      c1.relationships.length.should == 4
      c1.people.length.should == 4
      Company.all(:conditions => {:id => [c2.id, c3.id]}).should == []
    end
    
    it 'should not associate objects that are merge_equal twice' do
      c1 = Company.create!
      c2 = Company.create!
      p1 = Person.create!(:relationships => [Relationship.new(:company => c1)])
      p2 = Person.create!(:relationships => [Relationship.new(:company => c2)])
      p3 = Person.create!(:relationships => [Relationship.new(:company => c1), Relationship.new(:company => c2)])
      c1.merge!(c2)
      c1.relationships.length.should == 3
      p3.reload.relationships.length.should == 1
      p3.companies.should == [c1]
    end
    
    it 'should merge associated objects that are merge_equal' do
      c1 = Company.create!
      c2 = Company.create!
      ph1 = Phonenumber.create!(:phonable => c1, :country_code => "32", :number => "123456")
      ph2 = Phonenumber.create!(:phonable => c2, :country_code => "32", :number => "12/34.56", :description => "Home")
      c1.merge!(c2)
      c1.phonenumbers.length.should == 1
      c1.phonenumbers.first.number.should == "123456"
      c1.phonenumbers.first.description.should == "Home"
      Phonenumber.first(:conditions => {:id => ph2.id}).should be_nil
    end
    
  end
  
  describe "has_and_belongs_to_many associations" do
    
    it 'should associate all related objects to the master' do
      pr1 = Project.create!
      pr2 = Project.create!
      p1 = Person.create!(:projects => [pr1])
      p2 = Person.create!(:projects => [pr2])
      pr1.merge!(pr2)
      pr1.people.length.should == 2
      p2.projects.length.should == 1
      Project.first(:conditions => {:id => pr2.id}).should be_nil
    end
    
    it 'should not associate the same object twice' do
      p1 = Person.create!
      p2 = Person.create!
      pr1 = Project.create!(:people => [p1])
      pr2 = Project.create!(:people => [p1, p2])
      pr3 = Project.create!(:people => [p2])
      p1.merge!(p2)
      p1.projects.length.should == 3
      pr2.reload.people.length.should == 1
      Person.connection.select_value("select count(*) from people_projects where project_id = #{pr2.id}").should == '1'
      Person.first(:conditions => {:id => p2.id}).should be_nil
    end
    
  end
  
  describe "has_one associations" do
    
    it 'should keep the master association when available' do
      a = Address.create!
      c1 = Company.create!(:address => a)
      c2 = Company.create!
      c1.merge!(c2)
      c1.reload.address.should == a
    end
    
    it 'should overwrite the master association when blank' do
      a = Address.create!
      c1 = Company.create!
      c2 = Company.create!(:address => a)
      c1.merge!(c2)
      c1.address.should == a
    end
    
    it 'should merge the associated objects' do
      c1 = Company.create!(:address => Address.create!(:city => "Brussels", :zip => "1000"))
      c2 = Company.create!(:address => Address.create!(:street => "Somestreet 1"))
      c1.merge!(c2)
      c1.reload.address.street.should == "Somestreet 1"
      c1.address.city.should == "Brussels"
      c1.address.zip.should == "1000"
    end
    
  end
  
  describe "excluded associations" do
    
    it 'should not overwrite the master association when blank' do
      p1 = Person.create!
      p2 = Person.create!(:avatar => Avatar.create!)
      p1.merge!(p2)
      p1.avatar.should be_nil
      Avatar.first(:conditions => {:id => p2.avatar.id}).should be_nil
      Person.first(:conditions => {:id => p2.id}).should be_nil
    end
    
    it 'should not merge the associated objects' do
      p1 = Person.create!(:avatar => Avatar.create!(:url => "http://example.org"))
      p2 = Person.create!(:avatar => Avatar.create!(:alt => "example"))
      p1.merge!(p2)
      p1.reload.avatar.alt.should be_nil
      p1.avatar.url.should == "http://example.org"
    end
    
  end
  
end