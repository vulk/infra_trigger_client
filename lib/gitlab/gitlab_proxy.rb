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
      attr_accessor :use_json

      def initialize(options = {})
        @use_json = options[:use_json] ? true : false
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
        r = gitlab_client.projects.auto_paginate.reduce([]) {|x,y| x << y.name}
        @use_json ? r.to_json : r
      end 

      def get_projects 
        r = gitlab_client.projects.auto_paginate.reduce([]) {|x,y| x << y.to_hash}
        @use_json ? r.to_json : r
      end 

      def get_project(project_id) 
        r = gitlab_client.project(project_id).to_hash
        @use_json ? r.to_json : r
      end 

      def get_pipelines(project_id)
        r = gitlab_client.pipelines(project_id).auto_paginate.reduce([]) {|x,y| x << y.to_hash}
        @use_json ? r.to_json : r
      end 

      def get_pipeline(project_id, pipeline_id)
        r = gitlab_client.pipeline(project_id, pipeline_id).to_hash
        @use_json ? r.to_json : r
      end 

      def get_pipeline_jobs(project_id, pipeline_id)
        r = gitlab_client.pipeline_jobs(project_id, pipeline_id).auto_paginate.reduce([]) {|x,y| x << y.to_hash}
        @use_json ? r.to_json : r
      end 


      def trigger_pipeline(project_id, api_token, ref, trigger_variables = {})
        r = gitlab_client.run_trigger(project_id, api_token, ref, trigger_variables)
        @use_json ? r.to_json : r
      end
    end
  end
end
