module Metropoli
  def self.included(base)
    base.send :extend, ClassMethods
  end
  
  module Messages
    def self.error(class_name, kind)
      I18n.t( kind, :scope => [:metropoli, self.class.to_s.downcase])
    end
  end 
  
  module ClassMethods
    
    def metropoli_for(metropoli_model, opts = {})
      metropoli_relation = metropoli_model.to_s
      relation = opts[:as] && opts[:as].to_s || ConfigurationHelper.relation_name_for(metropoli_relation)
      relation_class_name = ConfigurationHelper.relation_class_for(metropoli_relation)
      relation_class = eval(relation_class_name)

      input_string = "_metropoli_#{relation}_name"
      relation_collector = "_metropoli_#{relation.pluralize}"

      self.send :attr_accessor, input_string
      self.send :attr_accessor, relation_collector

      self.belongs_to relation.to_sym, :class_name => relation_class_name

      define_method "#{relation}_name=" do |attr_value|
        send "#{input_string}=", attr_value
        send "#{relation_collector}=", (relation_class.with_values(attr_value) || [])

        if send(relation_collector).size == 1
          send "#{relation}=", send(relation_collector).first
        else
          send "#{relation}=", nil
        end
      end

      define_method "#{relation}_name" do
        send(input_string) || send(relation).to_s
      end
      
      #Validation Methods
      if opts[:required] || opts[:required_if]
        #TODO optimize this
        if opts[:required_if]
          validates_presence_of   relation, :if => opts[:required_if]
        else
          validates_presence_of   relation
        end
        validate do |record|
          collection = record.send(relation_collector)
          #relation_value = record.read_attribute(relation)
          needs_validation = opts[:required_if].nil? ? true : record.send(opts[:required_if])
          if collection && needs_validation
            if (collection.size > 1 rescue nil)
              record.errors.add(relation, Metropoli::Messages.error(metropoli_relation, :found_too_many))
            end
            if (collection.size == 0)
              record.errors.add(relation, Metropoli::Messages.error(metropoli_relation, :couldnt_find))
            end
          end
        end
      end      
    end
  end
end

ActiveRecord::Base.send :include, Metropoli
