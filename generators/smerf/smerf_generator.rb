class SmerfGenerator < Rails::Generator::NamedBase
  attr_accessor :plugin_path
  attr_accessor :user_model_name, :user_table_name, :user_table_fk_name 
  attr_accessor :link_table_name, :link_table_fk_name, :link_table_model_name,
                :link_table_model_class_name, :link_table_model_file_name

  def initialize(runtime_args, runtime_options = {})
    super

    @user_model_name = @name
    @user_table_name = @name.pluralize
    @user_table_fk_name = "#{@user_model_name}_id"
    
    if (("smerf_forms" <=> @user_table_name) <= 0)
      @link_table_name = "smerf_forms_#{@user_table_name}"
    else
      @link_table_name = "#{@user_table_name}_smerf_forms"
    end
    @link_table_fk_name = "#{@link_table_name.singularize()}_id"
    @link_table_model_name = @link_table_name.singularize()
    @link_table_model_class_name = @link_table_model_name.classify()
    @link_table_model_file_name = @link_table_model_name.underscore()
    
    @plugin_path = "vendor/plugins/smerf"
  end

  def manifest
    record do |m|

      # Create code directories
      m.directory("#{plugin_path}/app")     
      m.directory("#{plugin_path}/app/controllers")
      m.directory("#{plugin_path}/app/helpers")
      m.directory("#{plugin_path}/app/models")
      m.directory("#{plugin_path}/app/views")
      m.directory("#{plugin_path}/app/views/smerf_forms")
      m.directory("#{plugin_path}/app/views/smerf_test")
      
      # Migrations
      m.migration_template("migrate/create_smerfs.rb", 
        "db/migrate", {:migration_file_name => 'create_smerfs'})

      # Routes
      m.route_resources(:smerf_forms)

      # Create smerf directory and copy test form
      m.directory('smerf')
      m.file('smerf/testsmerf.yml', 'smerf/testsmerf.yml')
      
      # Copy example stylesheet
      m.file('public/smerf.css', 'public/stylesheets/smerf.css')

      # Copy error and help images
      m.file('public/smerf_error.gif', 'public/images/smerf_error.gif')
      m.file('public/smerf_help.gif', 'public/images/smerf_help.gif')
      
      # Helpers
      m.file 'lib/smerf_helpers.rb', 'lib/smerf_helpers.rb'
      m.file 'lib/smerf_system_helpers.rb', "#{plugin_path}/lib/smerf_system_helpers.rb"
      
      # Copy models
      m.template('app/models/smerf_forms_user.rb', "#{plugin_path}/app/models/#{@link_table_model_file_name}.rb")
      m.file('app/models/smerf_answer.rb', "#{plugin_path}/app/models/smerf_answer.rb")
      m.file('app/models/smerf_file.rb', "#{plugin_path}/app/models/smerf_file.rb")
      m.file('app/models/smerf_form.rb', "#{plugin_path}/app/models/smerf_form.rb")
      m.file('app/models/smerf_group.rb', "#{plugin_path}/app/models/smerf_group.rb")
      m.file('app/models/smerf_item.rb', "#{plugin_path}/app/models/smerf_item.rb")
      m.file('app/models/smerf_question.rb', "#{plugin_path}/app/models/smerf_question.rb")
      m.file('app/models/smerf_response.rb', "#{plugin_path}/app/models/smerf_response.rb")
      
      # Copy controllers
      m.template('app/controllers/smerf_forms_controller.rb', "#{plugin_path}/app/controllers/smerf_forms_controller.rb")
      m.file('app/controllers/smerf_test_controller.rb', "#{plugin_path}/app/controllers/smerf_test_controller.rb")
      
      # Copy helpers
      m.file('app/helpers/smerf_forms_helper.rb', "#{plugin_path}/app/helpers/smerf_forms_helper.rb")
      m.file('app/helpers/smerf_test.rb', "#{plugin_path}/app/helpers/smerf_test.rb")
      
      # Copy views
      m.file('app/views/smerf_forms/_smerf_form.html.erb', "#{plugin_path}/app/views/smerf_forms/_smerf_form.html.erb")
      m.file('app/views/smerf_forms/create.html.erb', "#{plugin_path}/app/views/smerf_forms/create.html.erb")
      m.file('app/views/smerf_forms/edit.html.erb', "#{plugin_path}/app/views/smerf_forms/edit.html.erb")

      m.file('app/views/smerf_test/index.html.erb', "#{plugin_path}/app/views/smerf_test/index.html.erb")

      # init.rb
      m.file('smerf_init.rb', "#{plugin_path}/init.rb", :collision => :force)

      # Display INSTALL notes
      m.readme "INSTALL"
    end
  end
  
  protected
  
    # Custom banner
    def banner
      "Usage: #{$0} smerf UserModelName"
    end



end
