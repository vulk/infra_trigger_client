require 'crosscloudci/ciservice_client/client'

module CrossCloudCI
  module CiService
    #def self.client(options = {})
    def self.client(config)
      CrossCloudCI::CiService::Client.new(config)
    end
  end
end
