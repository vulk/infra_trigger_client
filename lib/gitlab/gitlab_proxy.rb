require "gitlab"
require 'json'
require 'awesome_print'

module CrossCloudCI
  module GitLabProxy
    def self.proxy(options = {})
      Proxy.new(options)
    end
  end
end

module CrossCloudCI
  module GitLabProxy
    class Proxy
      attr_accessor :client

      def initialize(options = {})
        unless options[:endpoint].nil? or options[:api_token].nil?
          @client = gitlab_client(options)
        end
      end 

      def gitlab_client(options = {})
        return @client if @client

        if options[:endpoint].nil? or options[:api_token].nil?
          raise ArgumentError, ":endpoint is required" if options[:endpoint].nil?
          raise ArgumentError, ":api_token is required" if options[:api_token].nil?
        end

        Gitlab.configure do |config|
          config.endpoint = options[:endpoint]
          config.private_token = options[:api_token]
        end
        #@client = Gitlab.client(endpoint: options[:endpoint], private_token: options[:api_token])
        @client = Gitlab.client()
      end

      def get_project_names
        gitlab_client.projects.auto_paginate.reduce([]) {|x,y| x << y.name}
      end 

      def get_projects 
        gitlab_client.projects.auto_paginate.reduce([]) {|x,y| x << y.to_hash}
      end 

      def get_project(project_id) 
        gitlab_client.project(project_id).to_hash
      end 

      def get_pipelines(project_id)
        gitlab_client.pipelines(project_id).auto_paginate.reduce([]) {|x,y| x << y.to_hash}
      end 

      def get_pipeline(project_id, pipeline_id)
        gitlab_client.pipeline(project_id, pipeline_id).to_hash
      end 

      def get_pipeline_jobs(project_id, pipeline_id)
        gitlab_client.pipeline_jobs(project_id, pipeline_id).auto_paginate.reduce([]) {|x,y| x << y.to_hash}
      end 


      def trigger_pipeline(project_id, api_token, ref, trigger_variables = {})
        gitlab_client.run_trigger(project_id, api_token, ref, trigger_variables)
      end
    end
  end
end
