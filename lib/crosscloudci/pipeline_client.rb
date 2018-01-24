require 'crosscloudci/pipeline_client/client'

module CrossCloudCI
  module PipelineClient
    def self.client(options = {})
      Client.new(options)
    end
  end
end
