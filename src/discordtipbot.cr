class DiscordTipBot
  def initialize
    abort "No Config File specified! Exiting!" if ARGV.size == 0

    @log = Logger.new(STDOUT)

    load_config

    Raven.configure do |raven_config|
      raven_config.async = true
    end

    Raven.capture do
      # Set your log level here
      @log.level = Logger::DEBUG

      @log.debug("Tipbot network getting started")

      @log.debug("starting forking")
      Config.current.each do |name, config|
        raven_spawn(name: "#{name} Bot") do
          Controller.new(config, @log)
        end
      end
      @log.debug("finished forking")

      @log.info("All bots should be running now")
    end
    sleep
  end

  def load_config
    @log.debug("Attempting to load config from #{ARGV[0].inspect}")
    Config.load(ARGV[0])
    @log.info("Loaded config from #{ARGV[0].inspect}")
  end
end
