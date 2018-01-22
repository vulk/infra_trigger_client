module CrossCloudCI
  module Common
    def self.init_config(options = {})
      case ENV["CROSS_CLOUD_CI_ENV"]
      when "cidev"
        gitlab_base_url="https://gitlab.cidev.cncf.ci"
        cross_cloud_yml="https://raw.githubusercontent.com/crosscloudci/cncf-configuration/integration/cross-cloud.yml"
        cross_cloud_ref="master"
        cross_project_ref="master"
        dashboard_api_host_port="cidevapi.cncf.ci"
      when "staging"
        gitlab_base_url="https://gitlab.staging.cncf.ci"
        cross_cloud_yml="https://raw.githubusercontent.com/crosscloudci/cncf-configuration/staging/cross-cloud.yml"
        cross_cloud_ref="staging"
        cross_project_ref="staging"
        dashboard_api_host_port="stagingapi.cncf.ci"
      when "production"
        gitlab_base_url="https://gitlab.cncf.ci"
        cross_cloud_yml="https://raw.githubusercontent.com/crosscloudci/cncf-configuration/production/cross-cloud.yml"
        cross_cloud_ref="production"
        cross_project_ref="production"
        dashboard_api_host_port="productionapi.cncf.ci"
      # Default
      else
        gitlab_base_url="https://gitlab.dev.cncf.ci"
        cross_cloud_yml="https://raw.githubusercontent.com/crosscloudci/cncf-configuration/master/cross-cloud.yml"
        cross_cloud_ref="integration"
        cross_project_ref="integration"
        dashboard_api_host_port="devapi.cncf.ci"
      end

      dashboard_api_host_port = ENV["DASHBOARD_API_HOST_PORT"] unless ENV["DASHBOARD_API_HOST_PORT"].nil?

      @config = {
        :cross_cloud_yml => cross_cloud_yml,
        :dashboard => {
          :dashboard_api_host_port => dashboard_api_host_port
        },
        :gitlab => {
          :base_url => gitlab_base_url,
          :api_url => "#{gitlab_base_url}/api/v4",
          :api_token => ENV["GITLAB_API_TOKEN"],
          :pipeline => {
            "cross-cloud" => {
              :cross_cloud_ref => cross_cloud_ref,
              :api_token => ENV["GITLAB_CROSS_CLOUD_TOKEN"]
            },
            "cross-project" => {
              :cross_project_ref => cross_project_ref,
              :api_token => ENV["GITLAB_CROSS_PROJECT_TOKEN"]
            },
            "kubernetes" => {
              :api_token => ENV["GITLAB_KUBERNETES_TOKEN"]
            },
            "prometheus" => {
              :api_token => ENV["GITLAB_PROMETHEUS_TOKEN"]
            },
            "coredns" => {
              :api_token => ENV["GITLAB_COREDNS_TOKEN"]
            },
            "linkerd" => {
              :api_token => ENV["GITLAB_LINKERD_TOKEN"]
            }
          }
        }
      }

      response = Faraday.get @config[:cross_cloud_yml]


      # TODO: Decide if we want to return nil/raise an error and let a higher level handle the error
      if response.nil?
        @logger.fatal "Failed to retrieve cross-cloud configuration!"
        exit 1
      else
        cross_cloud_config = YAML.parse(response.body).to_ruby
      end

      if cross_cloud_config.nil?
        @logger.fatal "cross-cloud.yml configuration empty/undefined"
        exit 1
        #return nil
      end

      @config[:projects] = cross_cloud_config["projects"]

      # Helm configuration
      @config[:projects]["linkerd"][:helm] = {
        :label_master => "app=linkerd-master-linkerd",
        :label_stable => "app=linkerd-stable-linkerd",
        :filter_master => ".items[0].spec.containers[0].image",
        :filter_stable => ".items[0].spec.containers[0].image"
      }

      @config[:projects]["coredns"][:helm] = {
        :label_master => "app=coredns-master-coredns",
        :label_stable => "app=coredns-stable-coredns",
        :filter_master => ".items[0].spec.containers[0].image",
        :filter_stable => ".items[0].spec.containers[0].image"
      }

      @config[:projects]["prometheus"][:helm] = {
        :label_master => "app=prometheus-master-prometheus",
        :label_stable => "app=prometheus-stable-prometheus",
        :filter_master => ".items[0].spec.containers[0].image",
        :filter_stable => ".items[0].spec.containers[0].image"
      }

      @config[:clouds] = cross_cloud_config["clouds"]

      @config[:gitlab][:pipeline].each do |p|
        cp = cross_cloud_config["gitlab_pipeline"][p[0]] 
        next if cp.nil?
        cp.each_pair do |k,v|
          @config[:gitlab][:pipeline][p[0]][k] = v
        end
      end
      @config
    end
  end
end
