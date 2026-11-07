module KYAMLBench
  # Fixed inputs are loaded before evaluating timing.
  module Workloads
    SMALL      = File.read(File.join(__DIR__, "workloads", "small.yaml"))
    DEPLOYMENT = File.read(File.join(__DIR__, "workloads", "deployment.yaml"))

    STREAM_DOC_COUNT = 100

    # Return a stream of **count** fixture Deployment yaml docs
    def self.deployment_stream(count : Int32 = STREAM_DOC_COUNT) : String
      raise ArgumentError.new("Document count can only be positive") if count < 0

      String.build do |io|
        count.times { io << DEPLOYMENT }
      end
    end
  end
end
