lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
config_dir = File.expand_path("../../config", __FILE__)

#require 'pry'
require 'byebug'
require 'logger'
require 'date'
require 'yaml/store'

# CrossCloudCI::Common.init_config defined here
require_relative "#{config_dir}/environment"
require 'crosscloudci/ciservice_client'

## TODO: Subclass CiService client?
module CrossCloudCi
  class TriggerClient
    attr_accessor :logger
    attr_accessor :config, :ciservice, :data_store

    def initialize(options = {})
      @config = CrossCloudCi::Common.init_config

      if @config[:gitlab][:api_token].nil?
        @logger.error "Global GitLab API token not set!"
        exit 1
      end

      store_file = options[:store_file] 
      if store_file.nil?
        raise ArgumentError.new("TriggerClient requires a data store.  Pass :store_file option")
      end
      @data_store = YAML::Store.new(store_file)

      @ciservice = CrossCloudCI::CiService.client(@config)
    end

    # TODO: maybe move build_active projects to trigger client?
    def build_projects(options = {})
      # Start builds and store data
      @data_store.transaction do
        @ciservice.build_active_projects
        @data_store[:builds] = @ciservice.builds
      end
    end

    def load_previous_builds
      # Load previous build data
      @ciservice.builds = @data_store.transaction { @data_store.fetch(:builds, @ciservice.builds) }
    end


    def provision_clouds
      @data_store.transaction do
        @ciservice.provision_active_clouds
        # TODO: pull pipeline id for clouds just provisioned
        @data_store[:provisionings] = @ciservice.provisionings
      end
    end

    # Load previous provisioning data
    def load_previous_provisions
      @ciservice.provisionings = @data_store.transaction { @data_store.fetch(:provisionings, @ciservice.provisionings) }
    end

    def deploy_apps(options = {})
      @data_store.transaction do
        #@ciservice.app_deploy_to_active_clouds
        #@ciservice.app_deploy_to_active_clouds({release_types: [:stable]})
        @ciservice.app_deploy_to_active_clouds(options)

        @data_store[:app_deploys] = @ciservice.app_deploys
      end
    end

    def load_previous_app_deploys
      @ciservice.app_deploys = @data_store.transaction { @data_store.fetch(:app_deploys, @ciservice.app_deploys) }
    end

    def deprovision_clouds
      # destroy all provisionings
      @ciservice.provisionings.each do |p|
        @logger.info "[Deprovisioning] Deprovisioning #{p[:cloud]} for #{p[:project_name]} #{p[:target_project_ref]}"
        @ciservice.deprovision_cloud(p[:pipeline_id])
      end
    end

    def wait_for_builds(options = {})
      wait_for_kubernetes_builds
      wait_for_app_builds
    end

    def wait_for_app_builds(options = {})
      status_check_interval = options[:status_check_interval] ||= 10
      wait_for_pipelines(:build, @ciservice.builds[:app_layer], status_check_interval)
    end

    def wait_for_kubernetes_builds(options = {})
      status_check_interval = options[:status_check_interval] ||= 10
      wait_for_pipelines(:build, @ciservice.builds[:provision_layer], status_check_interval)
    end

    def wait_for_kubernetes_provisionings(options = {})
      status_check_interval = options[:status_check_interval] ||= 10
      wait_for_pipelines(:provision, @ciservice.provisionings, status_check_interval)
    end

    def wait_for_app_deploys(options = {})
      status_check_interval = options[:status_check_interval] ||= 10
      wait_for_pipelines(:app_deploy, @ciservice.app_deploys, status_check_interval)
    end

    # wait_for_pipelines() - waits for a list of pipelines to complete (status other than running, created or nil)
    #
    # args:
    #     pipeline_type = :build | :provision | :app_deploy
    #     pipelines = [{project_id1: <project_id>, pipeline_id2: <pipeline_id>}, {..}, ...]
    #                  list of pipelines with associated project ids
    def wait_for_pipelines(pipeline_type, pipelines = [], status_check_interval = 10)

      active_pipelines = pipelines.clone
      loop do
        active_pipelines.reject! do |p|
          project_name = @ciservice.project_name_by_id(p[:project_id])
          
          case pipeline_type
          when :build
            p[:pipeline_status] = @ciservice.build_status(p[:project_id],p[:pipeline_id])
          when :provision
            p[:pipeline_status] = @ciservice.provision_status(p[:pipeline_id])
          when :app_deploy
            p[:pipeline_status] = @ciservice.app_deploy_status(p[:pipeline_id])
          else
            raise ArgumentError.new("Unknown pipeline type: #{pipeline_type}")
          end

          @logger.debug "[TriggerClient] #{project_name} #{pipeline_type.to_s} pipeline #{p[:pipeline_id]} status: #{p[:pipeline_status]}"

          case p[:pipeline_status]
          when "created","running",nil
            false
          else
            true
          end
        end

        break if active_pipelines.empty?

        sleep status_check_interval
      end until active_pipelines.empty?
    end
  end
end

def trigger_help
  puts <<-EOM
# Methods for Trigger Client
## Build
# Build all active projects
\@tc.build_projects

# Build stable release for all active projects
\@tc.build_projects({release_types: [:stable]})

# Load build data from cache
\@tc.load_previous_builds

# Build a single project

## Provision (eg. K8s deploy)
# Provision (deploy kubernetes) to all active clouds
#
\@tc.provision_clouds

# Provision a single cloud

## App Deploy (eg. Apps deployed onto K8s)
# Deploy apps to active-provisioned clouds
#
\@tc.deploy_apps # head and stable
\@tc.deploy_apps({release_types: [:stable]}) # only stable releases

## Deprovision (eg. destroy the kubernetes environment on a cloud)

\@tc.deprovision_clouds
\@tc.ciservice.deprovision_cloud(provision_id)
EOM
end

def welcome_message
  <<-EOM
==================================================
= Cross-Cloud CI Trigger Client"
==================================================
*Quick start => type default_connect*

To use defaults and get a client run: default_connect
- @tc is the trigger client.
- @c is the ciservice client (also @tc.ciservice)
  => Use @c as outlined in docs/usage_from_irb.mkd 

## Manual setup
To change the data store, set the @store_file variable to use a differnt store file (default: db/datastore-<CROSS_CLOUD_CI_ENV>.yml)
Trigger client can be created with @tc = CrossCloudCi::TriggerClient.new({store_file: @store_file})
Ci service client is available as @tc.ciservice and @c
Set debugging level with @tc.logger.level and @tc.ciservice.logger.level

## Type trigger_help for more
EOM
end

if ENV["CROSS_CLOUD_CI_ENV"]
  ci_env = ENV["CROSS_CLOUD_CI_ENV"]
else
  ci_env = "development"
end

#dt = DateTime.now.strftime("%Y%m%d-%H:%M:%S%z")
#store_file = "db/datastore-#{ci_env}-#{dt}.yml"
@store_file = "db/datastore-#{ci_env}.yml"
#store_file = "db/datastore-cidev-20180124-02:59:26-0500.yml"
#store_file = "db/datastore-production-20180124-03:07:35-0500.yml"

@logger = Logger.new(STDOUT)
@logger.level = Logger::DEBUG

def default_connect
  @tc = CrossCloudCi::TriggerClient.new({store_file: @store_file})
  @tc.logger = Logger.new(STDOUT)
  @tc.logger.level = Logger::DEBUG

  @c = @tc.ciservice
  @c.logger = Logger.new(STDOUT)
  @c.logger.level = Logger::DEBUG
end

if $0 == "irb"
  puts welcome_message
else
  default_connect

  ###############################################################
  ## Steps for 3am scheduler
  ###############################################################

  ## 1. Build all projects

  # Build all active projects
  @tc.build_projects
  # Build stable release for all active projects
  #@c.build_projects({release_types: [:stable]})

  # Load build data from cache
  #@tc.load_previous_builds

  ## 2. Wait for a kubernetes build to complete
  #  Happy path:  continue no matter the status for both master/head continue (hoping/expecting success)

  @tc.wait_for_kubernetes_builds

  ## 3. Provision kubernetes to all active clouds
  # TODO: skip a provisioning a K8s if it fails to build

  @tc.provision_clouds

  #@tc.load_previous_provisions
 
  ## 4. Wait for Kubernetes to complete provisioning on active couds
  #
  #  TODO: update provision all to skip kubernetes that failed to build eg. stable build was sucess but master failed

  @tc.wait_for_kubernetes_provisionings
  @tc.wait_for_app_builds

  ## 5. Deploy all active Apps to active clouds
  #
  # TODO: skip release (eg. master/head) where kubernetes failed to build?
  # TODO: skip projects that failed to build
  # TODO: skip clouds that had a failed provision

  @tc.deploy_apps

  # @tc.load_previous_app_deploys


  ## Cleanup resources
  @tc.deprovision_clouds

end

__END__
