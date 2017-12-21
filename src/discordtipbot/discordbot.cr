class DiscordBot
  def initialize(@config : Config, @log : Logger)
    @log.debug("#{@config.coinname_short}: starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @tip = TipBot.new(@config, @log)

    prefix = @config.prefix

    @bot.on_message_create do |msg|
      case msg.content
      when prefix + "ping"
        self.ping(msg)
      when prefix + "tip"
        self.tip(msg)
      when prefix + "withdraw"
        self.withdraw(msg)
      when prefix + "deposit"
        self.deposit(msg)
      when prefix + "soak"
        self.soak(msg)
      when prefix + "rain"
        self.rain(msg)
      when prefix + "getinfo"
        self.getinfo(msg)
      end
    end
  end

  # Since there is no easy way, just to reply to a message
  private def reply(payload : Discord::Message, msg : String)
    begin
      @bot.create_message(payload.channel_id, msg)
    rescue
      @log.warn("#{@config.coinname_short}: bot failed sending a msg to #{payload.channel_id} with text: #{msg}")
    end
  end

  def run
    @bot.run
    @log.info("#{@config.coinname_short}: Started #{@config.coinname_full} bot")
  end

  # All helper methods for handling discord commands below

  # respond with pong
  def ping(msg : Discord::Message)
    reply(msg, "pong")
  end

  # respond getinfo RPC
  def getinfo(msg : Discord::Message)
    reply(msg, "#{@tip.get_info}")
  end

  # transfer from user to user
  def tip(msg : Discord::Message)
    # TODO
  end

  # withdraw amount to address
  def withdraw(msg : Discord::Message)
    # TODO
  end

  # return deposit address
  def deposit(msg : Discord::Message)
    # TODO
  end

  # send coins to all currently online users
  def soak(msg : Discord::Message)
    # TODO
  end

  # split amount between people who recently sent a message
  def rain(msg : Discord::Message)
    # TODO
  end
end
