require_relative 'api_generator/base'
require_relative 'api_generator/neo4j'

# class PipelineAggregator::StaticAPIGenerator < PipelineAggregator::Base

#   def initialize(config_data)
#     @config_data = config_data

#     @cache = PipelineAggregator::JenkinsCache.new(@config_data)

#     # TODO Validate config file is correct

#     @jobs_dir = File.expand_path("#{api_directory}/jobs")
#     @working_dir  = File.expand_path("#{api_directory}/working")

#     # Create data dirs if it doesn't exist
#     Dir.mkdir(api_directory) unless File.directory?(api_directory)
#     Dir.mkdir(@jobs_dir) unless File.directory?(@jobs_dir)
#     Dir.mkdir(@working_dir) unless File.directory?(@working_dir)
#   end

#   private
#   def purge_working
#     log("Purging Working Directory")
#     Dir["#{@working_dir}/*.*"].map { |file| 
#       File.delete(file)
#     }
#   end


#   public
#   def generate
#     purge_working

#     # Get all of the build jobs
#     @config_data["projects"].each do |project|
#       @config_data["branches"].each do |branch|
#         initial_jobname = project["init_job"].gsub(/##branch##/,branch)
#         job = @cache.get_job(project["jenkins_master"],initial_jobname)

#         job["builds"].each do |build|
#           log("Traversing build #{build['number']} of job #{initial_jobname} of #{branch} branch of the #{project['name']} project")
#           this_build = @cache.get_build(project["jenkins_master"],initial_jobname,build['number'])

#           #build_graph = {
#           #  "#{initial_jobname}/"
#           #}




#           puts this_build
#           #build = @jenkins.get_build(jenkins_master,jobname,build["number"],use_cache)
    
#           break;
#         end


#         # begin
#         #   jobname = joblist[0]
#         #   log("Getting job #{jobname}")
#         #   job = @jenkins.get_job(project["jenkins_master"],jobname,use_cache)

#         #   job['aggregator'] = project
#         #   job['aggregator']['branch'] = branch
#         #   @cache.set_job(project["jenkins_master"],jobname,job)

#         #   # Remove itself from the list
#         #   joblist = joblist - [jobname]

#         #   # Add all of the downstream projects to the list
#         #   job["downstreamProjects"].each do |downjob|
#         #     joblist << downjob["name"]
#         #   end
#         # end until joblist.length == 0

#       end
#     end
#   end

#   def generatexxxxxx
#     log("Building Jenkins API static files")

#     # Get all of the build jobs
#     @config_data["projects"].each do |project|
#       @config_data["branches"].each do |branch|
#         displayname = project["displayname"].gsub(/##branch##/,branch)
#         unique_name = project["unique_name"].gsub(/##branch##/,branch)
#         filename = File.expand_path("#{@jobs_dir}/#{unique_name}.json")

#         job_json = {
#           'actions': [],
#           'description': "Aggregated Jenkins Pipeline #{unique_name}",
#           'displayName': displayname,
#           'displayNameOrNull': displayname,
#           'name': unique_name,
#           'url': 'TBD',
#           'buildable': true,
#           'builds': [
#             {
#               "number": 308,
#               "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/308/",
#             },
#           ],
#           "color": "blue",
#           "firstBuild": {
#             "number": 307,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/307/"
#           },
#           "healthReport": [
#             {
#               "description": "Build stability: 1 out of the last 5 builds failed.",
#               "iconClassName": "icon-health-60to79",
#               "iconUrl": "health-60to79.png",
#               "score": 80
#             }
#           ],
#           "lastBuild": {
#             "number": 308,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/308/"
#           },
#           "lastCompletedBuild": {
#             "number": 308,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/308/"
#           },
#           "lastFailedBuild": {
#             "number": 304,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/304/"
#           },
#           "lastStableBuild": {
#             "number": 308,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/308/"
#           },
#           "lastSuccessfulBuild": {
#             "number": 308,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/308/"
#           },
#           "lastUnstableBuild": nil,
#           "lastUnsuccessfulBuild": {
#             "number": 304,
#             "url": "https://jenkins.puppetlabs.com/job/platform_puppet-agent_pkg-van-ship_daily-stable/304/"
#           },
#           "nextBuildNumber": 309,
#           "property": [],
#           "queueItem": nil,
#           "concurrentBuild": false,
#           "downstreamProjects": [],
#           "scm": {},
#           "upstreamProjects": [],
#           "activeConfigurations": [],
#         }

# #puts JSON.pretty_generate(job_json)
#         log("Writing job #{unique_name}")
#         File.open(filename, 'w') { |file| file.write( JSON.pretty_generate(job_json) ) }
#      end
#     end
#   end
# end
