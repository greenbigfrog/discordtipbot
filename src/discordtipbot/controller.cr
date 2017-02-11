class Controller
  def initialize(@config : Config, @log : Logger)
    @log.info("Fork starting #{@config.coinname_full} bot")
    @bot = Tipbot.new(@config, @log)
    @bot.run
  end
end
