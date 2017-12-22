class DiscordBot
  USER_REGEX = /<@!?(?<id>\d+)>/

  def initialize(@config : Config, @log : Logger)
    @log.debug("#{@config.coinname_short}: starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @tip = TipBot.new(@config, @log)

    prefix = @config.prefix

    @bot.on_message_create do |msg|
      case msg.content
      when prefix + "ping"
        self.ping(msg)
      when .starts_with? prefix + "tip"
        self.tip(msg)
      when .starts_with? prefix + "withdraw"
        self.withdraw(msg)
      when .starts_with? prefix + "deposit"
        self.deposit(msg)
      when .starts_with? prefix + "soak"
        self.soak(msg)
      when .starts_with? prefix + "rain"
        self.rain(msg)
      when prefix + "getinfo"
        self.getinfo(msg)
      end
      # TODO: Add config
    end

    # TODO: DM owner of guild, to config the bot when they add the bot
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
    cmd_usage = "`#{@config.prefix}tip [@user] [amount]`"
    # cmd[0]: trigger, cmd[1]: user, cmd[2]: amount
    cmd = msg.content.split(" ")

    return reply(msg, "Error! Usage: #{cmd_usage}") unless cmd.size > 2

    if match = USER_REGEX.match(cmd[1])
      id = match["id"].try &.to_u64
    end
    err = "Error: Please specify the user you want to tip! #{cmd_usage}"
    return reply(msg, err) unless id
    begin
      to = @bot.get_user(id)
    rescue
      return reply(msg, err)
    end

    if m = /(?<amount>\d+)/.match(cmd[2])
      amount = m["amount"].try &.to_f32
    end
    return reply(msg, "Error: Please specify a valid amount! #{cmd_usage}") unless amount

    @tip.transfer(from: msg.author.id, to: id, amount: amount)
    # TODO Add message
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
