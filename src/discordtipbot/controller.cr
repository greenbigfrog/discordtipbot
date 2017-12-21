class Controller
  def initialize(@config : Config, @log : Logger)
    @log.info("#{@config.coinname_short}: Fork starting #{@config.coinname_full} bot")
    @bot = DiscordBot.new(@config, @log)
    @bot.run
  end
end
