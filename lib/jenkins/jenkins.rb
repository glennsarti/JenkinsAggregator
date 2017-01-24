class PipelineAggregator::Jenkins < PipelineAggregator::Base

  def initialize(config_data, datastore)
    @config_data = config_data

    # TODO Validate config file is correct

    @datastore = datastore

    # Create data dirs if it doesn't exist
  end

  def get_jenkinsmaster(jenkins_master)
    master = @config_data['jenkins_masters'][jenkins_master]

    fail "Unknown jenkins master '#{jenkins_master}" if master.nil?
    master
  end

  def get_build(jenkins_master,jobname,buildnumber,use_cache = true)
    build = nil

    if use_cache
      build = @datastore.get_build(jenkins_master,jobname,buildnumber)
      return build unless build.nil? || build["building"]
    end

    client = JenkinsApi::Client.new(get_jenkinsmaster(jenkins_master))
    build = client.job.get_build_details(jobname,buildnumber)

    @datastore.set_build(jenkins_master,jobname,buildnumber,build)

    build
  end

  def get_jobnames(jenkins_master, filter = '.+')
    client = JenkinsApi::Client.new(get_jenkinsmaster(jenkins_master))

    return client.job.list(filter,true)
  end

  def get_job(jenkins_master,jobname,use_cache = true)
    job = nil

    if use_cache
      job = @datastore.get_job(jenkins_master,jobname)
      return job unless job.nil?
    end

    client = JenkinsApi::Client.new(get_jenkinsmaster(jenkins_master))
    job = client.job.list_details(jobname)
    @datastore.set_job(jenkins_master,jobname,job)

    job
  end

end
