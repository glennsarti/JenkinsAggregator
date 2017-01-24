require 'rake'
require_relative 'lib/pipeline_aggregator'

json_data =  <<EOT
{
  "datadir": "C:\\\\Source\\\\PuppetAgentPipeline\\\\ruby\\\\datadir",
  "apidir": "C:\\\\Source\\\\PuppetAgentPipeline\\\\ruby\\\\apidir",
  "branches": ["master", "stable", "LTS-1.7"],
  "jenkins_masters": {
    "cinext": {
      "server_url": "https://jenkins-master-prod-1.delivery.puppetlabs.net"
    },
    "platform": {
      "server_url": "https://jenkins.puppetlabs.com"
    }
  },
  "projects": [
    {
      "name":       "Facter",
      "init_job":    "platform_facter_init-van-component_##branch##",
      "jenkins_master": "cinext",
      "versioning_build_parameters": [ "COMPONENT_VERSION","SUITE_VERSION" ],
      "implicit_build_graph_parameters": [ "COMPONENT_COMMIT","SUITE_COMMIT" ]
    }
    ,{
      "name":       "Hiera",
      "init_job":    "platform_hiera_init-van-component_##branch##",
      "jenkins_master": "cinext",
      "versioning_build_parameters": [ "COMPONENT_VERSION","SUITE_VERSION" ],
      "implicit_build_graph_parameters": [ "COMPONENT_COMMIT","SUITE_COMMIT" ]
    }
    ,{
      "name":       "MCO",
      "init_job":    "platform_marionette-collective_init-van-component_##branch##",
      "jenkins_master": "cinext",
      "versioning_build_parameters": [ "COMPONENT_VERSION","SUITE_VERSION" ],
      "implicit_build_graph_parameters": [ "COMPONENT_COMMIT","SUITE_COMMIT" ]
    }
    ,{
      "name":       "Puppet",
      "init_job":    "platform_puppet_init-van-component_##branch##",
      "jenkins_master": "cinext",
      "versioning_build_parameters": [ "COMPONENT_VERSION","SUITE_VERSION" ],
      "implicit_build_graph_parameters": [ "COMPONENT_COMMIT","SUITE_COMMIT" ]
    }
    ,{
      "name":       "PXP Agent",
      "init_job":    "platform_pxp-agent_init-van-component_##branch##",
      "jenkins_master": "cinext",
      "versioning_build_parameters": [ "COMPONENT_VERSION","SUITE_VERSION" ],
      "implicit_build_graph_parameters": [ "COMPONENT_COMMIT","SUITE_COMMIT" ]
    }
    ,{
      "name":       "Puppet Agent",
      "init_job":    "platform_puppet-agent_init-van-int_suite-daily-##branch##",
      "jenkins_master": "platform",
      "versioning_build_parameters": [ "COMPONENT_VERSION","SUITE_VERSION" ],
      "implicit_build_graph_parameters": [ "COMPONENT_COMMIT","SUITE_COMMIT" ]
    }
  ]
}
EOT

desc 'Executes a HTTP server simulating a Jenkins API'
task :jenkins_api_server do
  agg = PipelineAggregator::Aggregator.new(json_data)
  agg.run_jenkins_api_server
end

desc 'Aggregates pipelines from Jenkins into singular jobs'
task :aggregate_jenkins do
  agg = PipelineAggregator::Aggregator.new(json_data)

  agg.purge_job_cache
  agg.aggregate_from_jenkins
end


