# This class contains details about smerf form groups, it derives from
# SmerfItem.
# 
# Each form is divided up into groups of questions, you must have at least one 
# group per form. Here are the fields that are currently available when 
# defining a group:
#
# code:: This code must be unique for all groups within the form as it is used to identify each group (mandatory) 
# name:: The name of the group, this is displayed as the group heading (mandatory) 
# description:: Provide more detailed description/instructions for the group (optional) 
# questions:: Defines all the questions contained within this group (mandatory) 
#
# Here is the definition for the Personal Details group of the test form:
#
#     personal_details:
#       code: 1
#       name: Personal Details Group
#       description: | This is a brief description of the Personal Details Group
#         here we ask you some personal details ...
#       questions:
#       ...
#

class SmerfGroup < SmerfItem
  attr_accessor :code, :name, :description, :question_objects  
    
  # Array to hold codes for all items for this class, we use this to check for
  # duplicates, for example duplicate question codes as question codes must be 
  # unique for the complete form
  #
  @@class_code_array = Array.new

  # Clear all class variables
  #
  def SmerfGroup.clear
    @@class_code_array.clear()   
  end  
  
  # Class constructor
  #
  def initialize(item, sort_order_field, owner_ident)
    # Call the base class constructor with required params
    super(item, sort_order_field, @@class_code_array, owner_ident)    
  end
  
  # This method performs the bulk of the processing. It processes the group
  # definition making sure that all mandatory fields have values. If any 
  # questions are found they will be processed and validated. 
  # 
  # As it processes the data it also performs validation on the data to make 
  # sure all required fields have been specified in the definition file. 
  # If any errors are found a <em>RuntimeError</em> exception will be raised.
  #
  def validate
    # Decode the raw data
    decode_data()
    # Validate all fields present
    errors = validate_object_fields()
    # Process question for this group
    @question_objects = nil
    if (!@questions.nil? and !@questions.empty?)
      # Process and validate questions 
      @question_objects = Array.new
      errors += validate_sub_objects(SmerfQuestion, 
          @questions, "sort_order", @question_objects)
    end    
    
    # Clear data no longer required, this will reduce the amount of data 
    # saved to the DB
    cleanup()
    remove_instance_variable(:@questions) 
    
    return errors
  end
  
  private
  
    # These fields should match the fields in the form definition file as well
    # as the names of the attr_accessor's
    #
    def setup_fields      
      @fields = {
        'code'                      => {'mandatory' => 'Y'},
        'name'                      => {'mandatory' => 'Y'},
        'questions'                 => {'mandatory' => 'Y'},
        'description'               => {'mandatory' => 'N'}
        #'question_sort_order_field' => {'mandatory' => 'Y'}
      }     
    end

    def object_id_message
      return "group #{@item_tag unless @item_tag.blank?}"
    end

    # Reload class variables after the form is unserialized from the DB
    #
    def init_object_class_variables
      # Process form questions within this group
      @question_objects.each {|question_object| question_object.init_class_variables()} if (@question_objects)
    end 
end
  