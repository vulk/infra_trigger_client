require 'logger'
require 'crosscloudci/ciservice_client'

#config_dir = File.expand_path("../../config", __FILE__)
config_dir = File.expand_path("../../../config", __FILE__)
# CrossCloudCI::Common.init_config defined here
require_relative "#{config_dir}/environment"

## TODO: Subclass CiService client?
module CrossCloudCi
  class TriggerClient
    attr_accessor :logger
    attr_accessor :config, :ciservice, :data_store

    def initialize(options = {})
      @config = CrossCloudCi::Common.init_config
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO

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

    def sync_k8s_nightly_build
        @ciservice.sync_k8s_nightly_build
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
      @logger.info "[TriggerClient] Deprovisioning clouds"
      # destroy all provisionings
      @ciservice.provisionings.each do |p|
        @logger.info "[TriggerClient] Deprovisioning #{p[:cloud]} for #{p[:project_name]} #{p[:target_project_ref]}"
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



