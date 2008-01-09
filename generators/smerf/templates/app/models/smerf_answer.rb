# This class contains details about answers to form questions, it derives from
# SmerfItem.
# 
# It knows how to handle subquestions. Subquestions are additional questions
# that a user can answer if certain answers are selected. An example subquestion
# would be where an <em>Other</em> is provided as one of the answers to a question,
# a subquestion can be defined to display a text field to accept more information.
#
# Question answers are defined using the following fields:
# 
# code:: Code to uniquely identify the answer, code needs to be unique for each 
#        question (mandatory). The value specified here will be saved as the 
#        users response when the answer is selected.
# answer:: The text that will be displayed to the user (mandatory) 
# default:: If set to Y then this answer will be selected by default (optional) 
# sort_order:: The sort order for this answer (mandatory) 
# subquestions:: Some answers may need additional information, another question 
#                can be defined to obtain this information. To define a subquestion 
#                the same fields that define a normal question is used (optional) 
#
# Here is an example answer definition:
#
#      answers:
#        1_20:
#          code: 1
#          answer: | 1-20
#          sort_order: 1
#          default: N
#          ...
#

class SmerfAnswer < SmerfItem
  attr_accessor :code, :answer, :default, :sort_order, :subquestion_objects
    
  # Array to hold codes for all items for this class, we use this to check for
  # duplicates, for example duplicate question codes as question codes must be 
  # unique for the complete form
  @@class_code_array = Array.new

  # Clear all class variables
  #
  def SmerfAnswer.clear
    @@class_code_array.clear()   
  end  
  
  # Class constructor
  #
  def initialize(item, sort_order_field, owner_ident)   
    # Call the base class constructor with required params
    super(item, sort_order_field, @@class_code_array, owner_ident)    
  end
  
  # This method performs the bulk of the processing. It processes the answer
  # definition making sure that all mandatory fields have values. If any 
  # subquestions are found they will be processed and validated. Subquestions 
  # are treated as normal questions and processed by the SmerfQuestion class.
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
    # Process subquestion for this answer
    @subquestion_objects = nil
    if (!@subquestions.nil? and !@subquestions.empty?)
      # Process and validate subquestions 
      @subquestion_objects = Array.new
      errors += validate_sub_objects(SmerfQuestion, 
          @subquestions, "sort_order", @subquestion_objects)
    end 
    
    # Clear data no longer required, this will reduce the amount of data 
    # saved to the DB
    cleanup()
    
    return errors
  end
  
  private
  
    # These fields should match the fields in the form definition file as well
    # as the names of the attr_accessor's
    def setup_fields      
      @fields = {
        'code'                      => {'mandatory' => 'Y'},
        'answer'                    => {'mandatory' => 'Y'},
        'default'                   => {'mandatory' => 'Y'},
        'sort_order'                => {'mandatory' => 'Y'},
        'subquestions'              => {'mandatory' => 'N'}
      }  
    end

    def object_id_message
      return "answer #{@item_tag unless @item_tag.blank?}"
    end

    # Reload class variables after the form is unserialized from the DB
    #
    def init_object_class_variables
      # Process form subquestions for this answer
      @subquestion_objects.each {|subquestion_object| subquestion_object.init_class_variables()} if (@subquestion_objects)
    end 
end
