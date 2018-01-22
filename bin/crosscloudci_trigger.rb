lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

#require 'pry'
require 'byebug'
require 'logger'

# CrossCloudCI::Common.init_config defined here
require_relative "#{config_dir}/environment"
require 'crosscloudci/ciservice_client'

def check_required(var, msg, exitstatus)
  if var.nil? or var.empty?
    puts msg
    exit exitstatus unless exitstatus.nil?
  end
end

##############################################################################

@config = CrossCloudCI::Common.init_config

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

if @config[:gitlab][:api_token].nil?
  @logger.error "Global GitLab API token not set!"
  exit 1
end

#@c = CrossCloudCI::CiService.client(:endpoint => @config[:gitlab][:api_url], :api_token => @config[:gitlab][:api_token])
@c = CrossCloudCI::CiService.client(@config)
@gp = @c.gitlab_proxy


#build_project(gitlabprojects.select {|p| p["name"] == "Kubernetes"}.first["id"], @config[:gitlab][:pipeline]["kubernetes"][:api_token], @config[:projects]["kubernetes"]["stable_ref"], {:dashboard_api_host_port => @config[:dashboard][:dashboard_api_host_port], :cross_cloud_yml => @config[:cross_cloud_yml]})

@c.load_project_data


# module CrossCloudCI
#   module TriggerClient
#    def self.


__END__



## TODO LATER: (AFTER ALL WORKING)
#
# TODO: refactor where some functions are... Some may be the app calling the CI functions vs in the CI module itself
#       eg. build active projects is more about the 3am trigger vs a common CI service function
#       - will need access to common config in both places
#       - need to decide on what options are passed ot CIService (eg. common config or specifc options)



      # TODO: build status loop? may not be needed for this client

      #         if [ "${JOB_STATUS}" == '"failed"' ]; then
      #             echo "$build failed"
      #             exit 1
      #         elif [ "${JOB_STATUS}" == '"canceled"' ]; then
      #             echo "$build canceled"
      #             exit 1
      #         elif [ "${JOB_STATUS}" == '"skipped"' ]; then
      #             echo "$build skipped"
      #             exit 1
      #         else
      #             continue
      #         fi



