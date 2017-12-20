class DiscordBot
  def initialize(@config : Config, @log : Logger)
    @log.debug("Starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @tip = TipBot.new(@config, @log)
  end

  def reply(payload : Discord::Message, msg : String)
    begin
      @bot.create_message(payload.channel_id, msg)
    rescue
      @log.warn("bot failed sending a msg to #{payload.channel_id} with text: #{msg}")
    end
  end

  def run
    @bot.run
    @log.info("Started #{@config.coinname_full} bot")
  end
end
