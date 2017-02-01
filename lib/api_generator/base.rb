class PipelineAggregator::APIGenerator < PipelineAggregator::Base

  def initialize(config_data)
    @config_data = config_data

    # TODO Validate config file is correct
    @api_directory = @config_data['apidirectory'].nil? ? File.expand_path("#{File.dirname(__FILE__)}/../../static_api") : @config_data['apidirectory']

    @jobs_dir = File.expand_path("#{@api_directory}/jobs")
    @views_dir = File.expand_path("#{@api_directory}/views")
    @builds_dir = File.expand_path("#{@api_directory}/builds")

    # Create data dirs if it doesn't exist
    Dir.mkdir(@api_directory) unless File.directory?(@api_directory)
    Dir.mkdir(@jobs_dir) unless File.directory?(@jobs_dir)
    Dir.mkdir(@builds_dir) unless File.directory?(@builds_dir)
    Dir.mkdir(@views_dir) unless File.directory?(@views_dir)
  end

  def get_buildfilename(project_unique_name,buildnumber)
    #File.expand_path("#{@builds_dir}/#{project_unique_name}_#{buildnumber}.json")
  end

  # Save Static API files
  def get_root_json_filename
    File.expand_path("#{@api_directory}/root.json")
  end
  def get_view_filename(project)
    File.expand_path("#{@views_dir}/#{project}.json")
  end
  def get_job_filename(jobname)
    File.expand_path("#{@jobs_dir}/#{jobname}.json")
  end
  def get_lastbuild_filename(jobname)
    File.expand_path("#{@builds_dir}/#{jobname}_last.json")
  end
  def get_build_filename(jobname,buildnumber)
    File.expand_path("#{@builds_dir}/#{jobname}_#{buildnumber}.json")
  end

  # Create JSON responses
  def generate
    fail "This should be overridden (generate)"
  end

  def jenkinsapi_get_job(jobname)
    fail "This should be overridden jenkinsapi_get_job(#{jobname})"
  end

  def jenkinsapi_get_build(jobname,buildnumber)
    fail "This should be overridden jenkinsapi_get_build(#{jobname},#{buildnumber})"
  end

  private
  def purge_working
    #log("Purging Working Directory")
    #Dir["#{@working_dir}/*.*"].map { |file| 
    #  File.delete(file)
    #}
  end

end
