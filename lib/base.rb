module PipelineAggregator
  class Base 
    @config_data = nil

    def data_directory
      @config_data["datadir"]
    end

    def api_directory
      @config_data["apidir"]
    end

    def jobs_directory
      File.expand_path("#{data_directory}/jobs")
    end

    def builds_directory
      File.expand_path("#{data_directory}/builds")
    end

    def graphs_directory
      File.expand_path("#{data_directory}/graphs")
    end

    def log(message)
      puts message
    end
  end
end
