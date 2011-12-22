module Merge
  
  # True if self is safe to merge with +object+, ie they are more or less equal.
  # Default implementation compares all attributes except id and metadata.
  # Can be overridden in specific models that have a neater way of comparison.
  def merge_equal?(object)
    object.instance_of?(self.class) and merge_attributes == object.merge_attributes
  end
  
  MERGE_INDIFFERENT_ATTRIBUTES = %w(id position created_at updated_at creator_id updater_id).freeze
  MERGE_EXCLUDE_ASSOCIATIONS = [].freeze
  
  # Attribute hash used for comparison.
  def merge_attributes
    merge_attribute_names.inject({}) do |attrs, name|
      attrs[name] = self[name]
      attrs
    end
  end
  
  # Names of the attributes that should be merged.
  def merge_attribute_names
    attribute_names - MERGE_INDIFFERENT_ATTRIBUTES
  end
  
  # Names of associations excluded from the merge. 
  # Override if the model has multiple scoped associations,
  # that can all be retrieved by a single has_many association.
  def merge_exclude_associations
    MERGE_EXCLUDE_ASSOCIATIONS
  end
  
  # Merge this object with the given +objects+. 
  # This object will serve as the master,
  # blank attributes will be taken from the given objects, in order.
  # All associations to +objects+ will be assigned to +self+.
  def merge!(*objects)
    transaction do
      merge_attributes!(*objects)
      merge_association_reflections.each do |r|
        local = send(r.name)
        objects.each do |object|
          if r.macro == :has_one
            other = object.send(r.name)
            if local and other
              local.merge!(other)
            elsif other
              send("#{r.name}=", other)
            end
          else
            other = object.send(r.name) - local
            # May be better to compare without the primary key attribute instead of setting it.
            other.each {|o| o[r.primary_key_name] = self.id}
            other.reject! {|o| local.any? {|l| merge_if_equal(l,o) }}
            local << other
          end
        end
      end
      objects.each {|o| o.reload and o.destroy unless o.new_record?}
    end
  end
  
  def merge_attributes!(*objects)
    blank_attributes = merge_attribute_names.select {|att| self[att].blank?}
    until blank_attributes.empty? or objects.empty?
      object = objects.shift
      blank_attributes.reject! do |att|
        if val = object[att] and not val.blank?
          self[att] = val
        end
      end
    end
    save!
  end
  
  private
  
  def merge_association_reflections
    self.class.reflect_on_all_associations.select do |r| 
      [:has_many, :has_one, :has_and_belongs_to_many].include?(r.macro) and 
      not r.options[:through] and 
      not merge_exclude_associations.include?(r.name.to_sym)
    end
  end
  
  def merge_if_equal(master, object)
    if master.merge_equal?(object)
      master.merge!(object) ; true
    end
  end
  
end

ActiveRecord::Base.class_eval { include Merge }