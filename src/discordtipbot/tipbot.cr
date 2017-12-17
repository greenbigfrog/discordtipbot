class Tipbot
  @db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @log.debug("Starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @log.info("Started #{@config.coinname_full} bot")

    @db = DB.open(@config.database_url)
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
  end
end
