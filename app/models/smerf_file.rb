# This class contains functions to work with the smerf form definition file. It
# will read the file validating the format of the file, if any errors are 
# found a <em>RuntimeError</em> exception will be raised.
# 
# Once the file has been validated all objects created during the process
# will be serialized to the smerf_forms DB table. Subsequent calls to the form
# will simplay unserialize the objects from the DB rather then reporcessing 
# the definition file.
# 
# If changes are made to the definition file the system will again call functions
# within this class to rebuild the form objects. Refer to the rebuild_cache method 
# within the smerfform.rb file to see how this all works.
#
# When setting up a new form the first thing we do is define some settings for 
# the form as a whole. Currently the following items can be defined for the form:
#
# name:: Name of the form (mandatory) 
# welcome:: Message displayed at the start of the form (optional) 
# thank_you:: Message displayed at the end of the form (optional) 
# group_sort_order_field:: Nominates which group field to use when sorting groups 
#                          for display (mandatory) 
# groups:: Defines the question groups within the form (mandatory) 
#
# Here is the definition for the test form included with the plugin:
#
#    --- 
#    smerfform:   
#      name: Test SMERF Form
#      welcome: | 
#        <b>Welcome:</b><br>
#        Thank you for taking part in our Test survey we appreciate your
#        input.<br><br>
#
#        <b>PRIVACY STATEMENT</b><br>
#        We will keep all the information you provide private and not share
#        it with anyone else....<br>
#
#      thank_you: | 
#        <b>Thank you for your input.</b><br><br>
#
#        Should you wish to discuss this survey please contact<br>
#        Joe Bloggs<br>
#        Tel. 12 345 678<br>
#        e-mail <A HREF=\"mailto:jbloggs@xyz.com.au\">Joe's email</A><br><br>
#
#        February 2007
#      group_sort_order_field: code
#
#      groups:
#      ...
#

class SmerfFile < SmerfItem
  attr_accessor :code, :name, :welcome, :thank_you, :group_objects
  attr_accessor :smerf_record, :smerf_file_name, :group_sort_order_field
    
  # Array to hold codes for all items for this class, we use this to check for
  # duplicates, for example duplicate question codes as question codes must be 
  # unique for the complete form. In this class we really do not need to make
  # it a class var as there will only ever be one of these objects per form. But
  # as we use class vars in all other form classes I've left this as a class var
  @@class_code_array = Array.new()

  # This method clears all class variables, as these are class vars they are 
  # created at startup and then exists for the duration of the app. We want 
  # to clear all values in these vars when we process a new form definition file.
  #
  def clear
    @@class_code_array.clear()
    SmerfGroup.clear()
    SmerfQuestion.clear()
    SmerfAnswer.clear()
  end
  
  # This method checks if the form definition file has been modified by 
  # comparing the timestamp of the form definition file against the timestamp
  # stored in the smerf_forms DB table, if they are not the same the form is rebuilt.
  #  
  def SmerfFile.modified?(code, db_timestamp)
    smerf_file_name = SmerfFile.file_exists?(code)
    if (ActiveRecord::Base.default_timezone == :utc)
      (File.mtime(smerf_file_name).utc != db_timestamp)    
    else
      (File.mtime(smerf_file_name) != db_timestamp)    
    end
  end

  # When a new SmerfFile object is created this method gets executed. It performs
  # a number of function including:
  # 
  # * make sure the form definition file actually exists
  # * opens and reads all the data from the file
  # * makes sure the file contains a form definition
  # * initialises variables
  # 
  # Refer to the rebuild_cache method within the smerfform.rb file.
  #
  def initialize(code) 
    # Get the form file name after making sure the file exists
    @smerf_file_name = SmerfFile.file_exists?(code)
       
    @code = code
    # Load form data from YAML file
    raw_data = YAML::load(File.open("#{RAILS_ROOT}/#{@smerf_file_name}" ))
    
    # Call the base class and pass in some values
    super(raw_data, "", @@class_code_array, nil)
    # Make sure smerf key specified, without it we do not have a form
    check_for_errors(validate_field(@raw_data, 'smerfform', ""))
    # Set data variables
    @item_data = @raw_data['smerfform']
    @item_tag = 'smerfform'
    # Array to hold codes for all items for this class, we use this to check for
    # duplicates, for example duplicate question codes as question codes must be 
    # unique for the complete form
    @class_code_array = Array.new

    # Clear all class variables for new file
    self.clear()    
    
    # On load of form make sure to clear form index array so that it is
    # ready to accept entries for the current form
    SmerfItem.object_index.clear()
    # Same for validations array
    SmerfItem.object_validations.clear()
  end
  
  # This method performs the bulk of the processing. Once the file is opened
  # and the data has been read into memory this method processes the data. It
  # processes all the groups, questions, answers and subquestions of the form
  # creating the appropriate objects as required. 
  # 
  # As it processes the data it also performs validation on the data to make 
  # sure all required fields have been specified in the definition file. 
  # If any errors are found a <em>RuntimeError</em> exception will be raised.
  # 
  # Refer to the rebuild_cache method within the smerfform.rb file.
  # 
  # The following object will be created during this process:
  # 
  # * SmerfGroup
  # * SmerfQuestion
  # * SmerfAnswer
  #
  def validate
    # Decode the raw form data and validate all fields present as defined by the
    # setup_fields method which is called from the method below
    errors = validate_object_fields()
    # Process question groups
    @group_objects = nil
    if (!@groups.nil? and !@groups.empty?)
      # Process and validate question groups
      @group_objects = Array.new
      errors += validate_sub_objects(SmerfGroup, 
          @groups, @group_sort_order_field, @group_objects)
    end 
    # Check for errors and raise an exception 
    check_for_errors(errors)
    
    # Clear data no longer required, this will reduce the amount of data 
    # saved to the DB
    cleanup()
    remove_instance_variable(:@groups) 
    self.clear()
  end
  
  private
  
    # These fields should match the fields in the form file as well
    # as the names of the attr_accessor's
    def setup_fields
      @fields = {
        'name'                    => {'mandatory' => 'Y'},
        'welcome'                 => {'mandatory' => 'N'},
        'thank_you'               => {'mandatory' => 'N'},
        'groups'                  => {'mandatory' => 'Y'},
        'group_sort_order_field'  => {'mandatory' => 'Y'}
      }
    end

    def object_id_message
      return "this form"
    end

    # Check if the form file exists
    def SmerfFile.file_exists?(code)
      filename = SmerfFile.smerf_file_name(code)
      if (!File.file?(filename))
        raise(RuntimeError, "Form configuration file #{filename} not found.")
      else
        return self.smerf_file_name(code)
      end
    end
  
    # Functions format file name from supplied form code
    # Class method
    def SmerfFile.smerf_file_name(code)
      "smerf/#{code}.yml"    
    end
  
    # Reload class variables after the form is unserialized from the DB
    #
    def init_object_class_variables
      # Process form groups
      @group_objects.each {|group| group.init_class_variables()} if (@group_objects)
    end
end