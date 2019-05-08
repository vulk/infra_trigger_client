require './config/environment'
RSpec.describe CrossCloudCi::Common do
 context "init_config" do
   it "should initialize the yaml" do
      config = CrossCloudCi::Common.init_config
      expect(config[:projects]["kubernetes"]["head_ref"]).to eq "master"
   end
 end
end 
