# SmerfItem class is a base class used by all other smerf classes
# and contains shared functionality.
# 
# Derived classes include:
# 
# * SmerfFile
# * SmerfGroup
# * SmerfQuestion
# * SmerfAnswer
#

class SmerfItem
  
  # Define methods that will allow access to class variable
  # object_index: class variable to hold the unique id for each form object 
  #               and a reference to that object. This makes it very easy to 
  #               find an object using the form objects id
  # object_validations: class variable that stores objects that have validation
  #               methods defined in an array, allows us to easily validate a form 
  #               by calling the methods in this array
  cattr_accessor :object_index, :object_validations   
  
  # Specifies that the codes for sub items (e.g. questions) must be unique
  # for the complete form, if this is false then we check only within this
  # item (e.g. answer codes for a question)
  attr_accessor :code_unique_for_smerf
  
  # This is the id of the object that owns this one, nil means that we
  # have reached the root object, normally the smerffile object. Keeping this
  # information allows us to walk the object tree to find owners. 
  # 
  attr_accessor :owner_ident

  # The object_id is unique id for all objects contructed by taking the 
  # owner_ident and combining it with this objects code. For example: group 
  # code 1, object id would be practiceprofile~~1, questions for this group 
  # might have object id practiceprofile~~1~~g1q1
  attr_accessor :object_ident
  
  # Define class variables
  @@object_index = Hash.new()
  @@object_validations = Array.new()
  
  # Class Constructor
  #
  def initialize(raw_data, sort_order_field, class_code_array, owner_ident)
    # Store the raw data as extracted from the form definition file
    @raw_data = raw_data
    # Stores the sort order used to sort items of this class. We then use
    # this field to make sure that the field is actually present in the items
    # definition. For example groups can be sorted by code, the smerf object will
    # pass the sort order field (code) to new group classes it creates, this value
    # is then used to confirm that each group has a code field defined. Form
    # does not have a sort field so it passes an empty string.
    @sort_order_field = sort_order_field
    # When defining a new section/level in a YAML file you do so by specifying a 
    # section/level header, e.g. groups:, but there is no value associated with it,
    # sub items are then defined, i.e. code: xyz. When the YAML file is loaded the 
    # header is loaded into an element array with 0 as the index and the items for
    # the level is loaded into another element with 1 as the index. The two data items
    # below are used to store the two bits of data (see decodedata method)
    @item_tag = nil
    @item_data = nil
    
    # By default make codes be unique for a complete form
    @code_unique_for_smerf = true
  
    # We may only want to have the items unique within a groups of sub items, for
    # example we want code to be unique for all answers to a question, we may not
    # want to them to unique within a complete form, here we use an instance 
    # variable so it only unique for this object
    @code_array = Array.new
    
    # I was going to use a single class array in this class @@class_code_array 
    # but it turns out Ruby at the moment will use the same class variable for 
    # ALL classes that derive from this class. This is not what I want as I want 
    # to keep a separate list of codes for groups, question. Using the class
    # var in this class means all of them would be mixed in together, not what 
    # I want. I believe in Ruby V2 this will ber fixed where the class var would
    # be for the resultant class SmerfGroup. In the mean time I have to create
    # a class var in each child class and pass it in to the base.
    @class_code_array = class_code_array
    
    @owner_ident = owner_ident
    @object_ident = nil
  end

  # This method reloads all our class variables after the form is 
  # unserialized from the DB. As the class variables are not serialized
  # and holds references to objects we need to load these once all objects
  # have been created.
  #
  def init_class_variables
    # Add this object to the object_index hash
    object_index[@object_ident.to_s()] = self
    # Call any custom inits that may be overriden on a class by class basis
    init_object_class_variables()
  end

  protected

    # The method takes a hash, a field name and an error message. The method
    # checks the hash to see if the field exists, it also checks to see if a value
    # has been specified for the field. If not the supplied error message or if
    # a empty string was supplied for the msg param then a default error will be 
    # returned.
    #
    def validate_field(hash, field, msg)
      error = ""
      if (hash.blank?() or !hash.has_key?(field) or hash[field].blank?)        
        error = ((msg.size > 0) ? msg : "No '#{field}' specified for ") + object_id_message() + "\n"
      end
      return error
    end
  
    # For each form item a list of fields that can be used in the YAML file
    # to define the item is defined (see SmerfGroup for example). This method 
    # is called to firstly setup a hash that contains all the fields, it checks 
    # that the sort order field is present and then checks the other fields. When 
    # setting up the fields you can specify if the field is mandatory or requires
    # further validation.
    #
    def validate_object_fields
      # Setup fields array
      setup_fields()      
      # Check the sort order field
      errors = ""
      if !@sort_order_field.blank?()
        errors += validate_field(@item_data, @sort_order_field,
          "Specified group sort field '#{@sort_order_field}' missing from ")    
      end
      # Validate all fields
      errors += validate_fields(@item_data, @fields)        
      # Create a unique id for this object, which is a combination of onwer_id
      # and this objects unique code      
      @object_ident = (@owner_ident) ? "#{@owner_ident}~~#{@code}" : "#{@code}"
      
      object_index[@object_ident.to_s()] = self
      return errors
    end
  
    # This method takes a class name (SmerfGroup), a hash that contains
    # the data read in from the YAML file, the order in which these sub items
    # should be sorted and array in which to return the objects created for
    # each sub item.
    # 
    # This function validates sub items such as groups, questions, etc.
    # It creates and object of the specified class and performs the 
    # validation on the contents for each item in the specified hash.
    # 
    # For example the smerffile object passes the groups array to this function,
    # this function creates a SmerfGroup object for each item in the array.
    # It then performs validation for each group and adds it to the object array
    # which is then used in the Smerf object. The same thing happens for the 
    # questions defined in each group, we create an SmerfQuestion object for each
    # item passed in the array by the SmerfGroup object.
    #
    def validate_sub_objects(object_class, hash, sort_order_field, object_array)    
      errors = ""
      array_of_objects = Array.new
      # Process each item passed to us in the hash
      for item in hash do
        # Create a new onject using the class name passed to us, pass
        # in the item contents and the sort order field to the new object
        class_object = object_class.new(item, sort_order_field, @object_ident)     
        # Perform the validation on the new object, checking manadatory fields 
        # are present and performing any custom validations as defined by the 
        # fields array setup for each class
        errors += class_object.validate()
        # Add the new object to the object array that will be used by the calling
        # object, e.g. smerffile object collects and uses groups          
        array_of_objects << class_object
        # If the object has a 'code' field move it to the code array to make
        # sure all codes are unique either for a complete form or within the
        # current object, e.g. answers for a question
        if class_object.respond_to?('code') 
          @class_code_array << class_object.code
          @code_array << class_object.code 
        end
      end     
      # Check all items have a unique code
      errors += check_duplicate_codes(object_class)
      # Sort the items using the supplied sort order field
      if errors.size <= 0 and !sort_order_field.blank?
        array_of_objects = array_of_objects.sort {|a,b| eval("a.#{sort_order_field}<=>b.#{sort_order_field}")}
        # The above function is faster than the one below
        #object_array = object_array.sort_by {|item| eval("item.#{sort_order_field}")}
      end
      # Copy all items to the destination array. 
      #array_of_objects.each {|item| object_array[item.code.to_s] = item}
      object_array.replace(array_of_objects)
      return errors
    end

    # This is a small helper method that checks the errors string to see if there
    # are any errors present, if so we raise an exception
    #
    def check_for_errors(errors)
      # Throw exception if errors found
      if errors.size > 0
        raise("Errors found in form configuration file #{@filename}:\n" + errors)
      end          
    end
  
    # This method decodes the raw data read in from a YAML file.
    # When defining a new section/level in a YAML file you do so by specifying a 
    # section/level header, e.g. groups:, but there is no value associated with it,
    # sub items are then defined, i.e. code: xyz. When the YAML file is loaded the 
    # header is loaded into an element array with 0 as the index and the items for
    # the level is loaded into another element with 1 as the index. 
    #
    def decode_data()
      # Raw data contains two array items, 
      # [0] = name 
      # [1] = data
      if @raw_data.blank? or @raw_data.size < 2
        raise("Invalid data found in form")
      end
      @item_tag = @raw_data[0]
      @item_data = @raw_data[1]
    end
  
  private
  
    # Stub that can be overriden in each class to add custom error information
    # e.g. the SmerfGroup class adds information about which group had the
    # error
    #
    def object_id_message
      return ""
    end
    
    # Stub that can be overriden in each class to do some class variable 
    # initialisation
    #
    def init_object_class_variables
      
    end
    
    # This method checks for duplicate code values. We uniquely ID each item
    # (group, question, ...) using a code. Here we make sure that all codes 
    # are unique for all questions for example using a class variable to store
    # each code
    #
    def check_duplicate_codes(object_class)
      error = ""
      if @code_unique_for_smerf 
        if @class_code_array.size > 0 and @class_code_array.uniq.size != @class_code_array.size
          error = "Duplicate #{object_class} 'code' found, code must be unique for complete form\n"
        end
      else
        if @code_array.size > 0 and @code_array.uniq.size != @code_array.size
          error = "Duplicate #{object_class} 'code' found, code must be unique for " + object_id_message() + "\n"
        end
      end
      return error
    end    

    # This method receives a hash that contains the data for the item, we are
    # also given a list of fields to check (e.g. all fields that define a group).
    # Using this information we check to make sure that all manadatory fields have
    # been defined and have a value. Additionally specific validation functions can
    # be called to perform extra checking.
    #
    def validate_fields(hash, fields)
      errors = ""
      # Process each field for the item
      fields.each do |field, options| 
        error = ""
        # If manadatory make sure it exists and a value have been defined
        if (options.has_key?('mandatory') and options['mandatory'] == 'Y')
          msg = (options.has_key?('error_msg')) ? options['error_msg'] : ""
          error = validate_field(hash, field, msg)
        end        
        #eval("@#{field} = nil")
        instance_variable_set("@#{field}", nil)
        # If the field exists then we set the instance variable for that field.
        # For example we define 'code' as a field, here we extract the value for
        # code and assign it to @code which is the instance variable for code.
        if !hash.blank?() and error.size <= 0 and hash.has_key?(field) and !hash[field].blank?
          #eval("@#{field} = hash[field]")
          instance_variable_set("@#{field}", hash[field])
          # Check if additional validation function need to be called
          if (options.has_key?('validate_function') and !options['validate_function'].blank? and
            self.respond_to?(options['validate_function']))
            # Call the function
            errors += self.send(options['validate_function'])
          end                      
        else
          errors += error
        end          
      end
      return errors    
    end
    
    # Cleanup all vars that do not need to be saved to the DB
    #
    def cleanup
      remove_instance_variable(:@raw_data)
      remove_instance_variable(:@sort_order_field)
      remove_instance_variable(:@item_tag)
      remove_instance_variable(:@item_data)
      remove_instance_variable(:@code_array)
      remove_instance_variable(:@class_code_array)       
      remove_instance_variable(:@fields) if (@fields)
    end
end
