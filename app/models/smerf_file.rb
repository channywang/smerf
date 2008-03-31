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

class SmerfFile
  
  def initialize
    @smerf_form_object = nil
    @code = ''
  end
  
  # This method checks if the form definition file has been modified by 
  # comparing the timestamp of the form definition file against the timestamp
  # stored in the smerf_forms DB table, if they are not the same the form is rebuilt.
  #  
  def SmerfFile.modified?(code, db_timestamp)
    smerf_fname = SmerfFile.file_exists?(code)
    if (ActiveRecord::Base.default_timezone == :utc)
      (File.mtime(smerf_fname).utc != db_timestamp)    
    else
      (File.mtime(smerf_fname) != db_timestamp)    
    end
  end

  # When a new SmerfFile object is created this method gets executed. It performs
  # a number of function including:
  # 
  # * make sure the form definition file actually exists
  # * opens and reads all the data from the file
  # * processes the file creating the required form objects
  # * check for errors
  # 
  # Refer to the rebuild_cache method within the smerfform.rb file.
  #
  def process(code) 
    @code = code
    
    # Get the form file name after making sure the file exists
    smerf_fname = SmerfFile.file_exists?(code)
       
    # Load form data from YAML file
    data = YAML::load(File.open(smerf_fname))
    raise("#{smerf_fname} is blank nothing to do") if (data.blank?)
    
    # Make sure this is a smerf form file
    if (data.kind_of?(Hash) and data.size > 0 and 
      data.has_key?('smerfform') and !data['smerfform'].blank?)
      # Process form data, building form objects as required
      smerf_form_object = SmerfMetaForm.new(@code)
      smerf_form_object.process(data, smerf_form_object)
    
      # Throw exception if any errors exist
      check_for_errors(smerf_form_object.errors)
    else
      raise("#{smerf_fname} is not a valid smerf form file")
    end
    return smerf_form_object
  end
  
  private  
  
    # This is a small helper method that checks the errors string to see if there
    # are any errors present, if so we raise an exception
    #
    def check_for_errors(errors)
      # Throw exception if errors found
      if errors.size > 0
        error_msg = "Errors found in form configuration file #{SmerfFile.smerf_file_name(@code)}:\n"
        errors.each do |attribute, messages|
          messages.each do |message|
            error_msg += "#{attribute}: #{message}\n"
          end
        end        
        raise(error_msg)
      end          
    end

    # Check if the form file exists
    def SmerfFile.file_exists?(code)
      filename = SmerfFile.smerf_file_name(code)
      if (!File.file?(filename))
        raise(RuntimeError, "Form configuration file #{filename} not found.")
      else
        return filename
      end
    end
  
    # Functions format file name from supplied form code
    # Class method
    def SmerfFile.smerf_file_name(code)
      "#{RAILS_ROOT}/smerf/#{code}.yml"    
    end
end