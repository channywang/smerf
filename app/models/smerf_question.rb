# This class contains details about form questions, it derives from
# SmerfItem.
# 
# A group can contain any number of questions, there must be at least one question 
# per group. When defining a question you must specify the question type, 
# the type determines the type of form field that will be created. 
# There are currently four types that can be used, this will be expanded as 
# needed. The current question types are:
#
# multiplechoice:: Allows the user to select all of the answers that apply from a 
#                  list of possible choices, check boxes are used for this question 
#                  type as multiple selections can be made 
# singlechoice:: Allows the user to select one answer from a list of possible choices, 
#                radio buttons are used for the question type as only a single answer 
#                can be selected 
# textbox:: Allows the user to enter a large amount of free text, the size of the 
#           text box can be specified 
# textfield:: Allows the user to enter a small amount of free form text, the size 
#             of the text field can be specified 
# selectionbox:: Allows the user to select one or more answers from a dropdown list 
#                of possible choices
# 
# The following fields can be used to define a question:
# 
# code:: Unique code that will identify the question, the code must be unique within 
#        a form (mandatory) 
# type:: Specifies the type of field that should be constructed on the form for 
#        this question, see above list for current types (mandatory) 
# question:: The text of the question, this field is optional as subquestions do 
#            not have to have question text 
# textbox_size:: Specifies the size of the text box to construct, rows x cols, 
#                defaults to 30x5 (optional) 
# textfield_size:: Specified the size of the text field that should be constructed, 
#                  specified in the number of visible characters, default to 30 (optional) 
# header:: Specifies a separate heading for the question. The text will be 
#          displayed above the question allowing questions to be broken up into 
#          subsections (optional) 
# sort_order:: Specifies the sort order for the question 
# help:: Help text that will be displayed below the question 
# answers:: Defines the answers to the question if the question type displays a 
#           list of possibilities to the user 
# validation:: Specifies the validation methods (comma separated) that should be 
#              executed for this question, see Validation and Errors section for 
#              more details
# selectionbox_multiplechoice:: Specifies if the dropdown box should allow multiple choices
#  
# Below is an example question definition:
# 
#       questions:
#         specify_your_age:
#           code: g1q1
#           type: singlechoice
#           sort_order: 1
#           question: | Specify your ages  
#           help: | Select the <b>one</b> that apply 
#           validation: validate_mandatory_question
#           ...
#

class SmerfQuestion < SmerfItem
  attr_accessor :code, :type, :question, :sort_order, :help, :textbox_size, :answer_objects 
  attr_accessor :textfield_size, :header, :validation, :selectionbox_multiplechoice 
    
  # Array to hold codes for all items for this class, we use this to check for
  # duplicates, for example duplicate question codes as question codes must be 
  # unique for the complete form
  #
  @@class_code_array = Array.new

  # Clear all class variables
  #
  def SmerfQuestion.clear
    @@class_code_array.clear() 
  end  
  
  # Class constructor
  #
  def initialize(item, sort_order_field, owner_ident)
    # Call the base class constructor with required params
    super(item, sort_order_field, @@class_code_array, owner_ident)    
    # We want to make sure answer codes are unique on a 
    # question by question basis. This class manages answers
    # to the question so we set the flag value here.
    self.code_unique_for_smerf = false
  end
  
  # This method performs the bulk of the processing. It processes the question
  # definition making sure that all mandatory fields have values. If any 
  # answers are found they will be processed and validated. 
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
    # Process answers for this question
    @answer_objects = nil
    if (!@answers.nil? and !@answers.empty?)
      # Process and validate answers 
      @answer_objects = Array.new
      errors += validate_sub_objects(SmerfAnswer, 
          @answers, "sort_order", @answer_objects)
    end
    
    # Clear data no longer required, this will reduce the amount of data 
    # saved to the DB
    cleanup()
    remove_instance_variable(:@answers) 

    return errors
  end
    
  protected

    # Check if there are validations that need to be performed for this questions
    # if so add it to an array for easy verification later
    def validation_function
      object_validations << self if (!self.validation.blank?())        
      return ""
    end 
    
  private
  
    # These fields should match the fields in the form definition file as well
    # as the names of the attr_accessor's
    #
    def setup_fields      
      @fields = {
        'code'                        => {'mandatory' => 'Y'},
        'type'                        => {'mandatory' => 'Y', 'validate_function' => 'check_question_type'},
        'question'                    => {'mandatory' => 'N'},
        'sort_order'                  => {'mandatory' => 'Y'},
        'help'                        => {'mandatory' => 'N'},
        'answers'                     => {'mandatory' => 'N'},
        'textbox_size'                => {'mandatory' => 'N'},
        'textfield_size'              => {'mandatory' => 'N'},
        'header'                      => {'mandatory' => 'N'},
        'selectionbox_multiplechoice' => {'mandatory' => 'N'},
        'validation'                  => {'mandatory' => 'N', 'validate_function' => 'validation_function'},
      }
    end
    
    # Additional validation method to make sure a valid question type
    # has been used
    #
    def check_question_type
      error = ""
      case @type
      when 'multiplechoice'
      when 'textbox'
      when 'singlechoice'
      when 'textfield'
      when 'selectionbox'
      else
        error = "Invalid question type #{@type} specified for " + object_id_message() + "\n"
      end
      return error
    end

    def object_id_message
      return "question #{@item_tag unless @item_tag.blank?}"
    end

    # Reload class variables after the form is unserialized from the DB
    #
    def init_object_class_variables
      # Process form answers within this question
      @answer_objects.each {|answer_object| answer_object.init_class_variables()} if (@answer_objects)
      # Add any validation function defined for this question
      validation_function()
    end 
end
