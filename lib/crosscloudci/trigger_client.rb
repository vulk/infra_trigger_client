require 'logger'

module CrossCloudCi
  module TriggerClient
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG

    def self.wait_for_kubernetes_builds(client)



    end

    #def self.wait_for_kubernetes_builds(client)
      # loop do
      #   client.builds[:provision_layer].each do |build|
      #     @logger.info "#{build[:project_name]} build status: #{client.build_status(build[:project_id],build[:pipeline_id])}"
      #
      #     break 
      #   end
      #end
    #end
  end
end



