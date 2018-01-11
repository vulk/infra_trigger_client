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

      @config = {
        :cross_cloud_yml => cross_cloud_yml,
        :dashboard => {
          :dashboard_api_host_port => dashboard_api_host_port
        },
        :gitlab => {
          :base_url => gitlab_base_url,
          :api_url => "#{gitlab_base_url}/api/v4",
          :api_token => ENV["GITLAB_API_TOKEN"],
          :projects => {
            "cross_cloud" => {
              :cross_cloud_ref => cross_cloud_ref,
              :api_token => ENV["GITLAB_CROSS_CLOUD_TOKEN"]
            },
            "cross_project" => {
              :cross_project_ref => cross_project_ref,
              :api_token => ENV["GITLAB_CROSS_PROJECT_TOKEN"]
            },
            "kubernetes" => {
              :master_ref => "master",
              :stable_ref => nil,
              :api_token => ENV["GITLAB_KUBERNETES_TOKEN"]
            },
            "prometheus" => {
              :master_ref => "master",
              :stable_ref => nil,
              :api_token => ENV["GITLAB_PROMETHEUS_TOKEN"]
            },
            "coredns" => {
              :master_ref => "master",
              :stable_ref => nil,
              :api_token => ENV["GITLAB_COREDNS_TOKEN"]
            },
            "linkerd" => {
              :master_ref => "master",
              :stable_ref => nil,
              :api_token => ENV["GITLAB_LINKERD_TOKEN"]
            }
          }
        }
      }
    end
  end
end
