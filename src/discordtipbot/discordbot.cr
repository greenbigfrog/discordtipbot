class DiscordBot
  USER_REGEX = /<@!?(?<id>\d+)>/

  def initialize(@config : Config, @log : Logger)
    @log.debug("#{@config.coinname_short}: starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @cache = Discord::Cache.new(@bot)
    @tip = TipBot.new(@config, @log)

    prefix = @config.prefix

    @bot.on_message_create do |msg|
      next if msg.author.id == @cache.resolve_current_user.id
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
      when .starts_with? prefix + "balance"
        self.balance(msg)
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

  private def private?(msg : Discord::Message)
    channel(msg).type == 1
  end

  private def channel(msg : Discord::Message) : Discord::Channel
    @cache.resolve_channel(msg.channel_id)
  end

  private def guild_id(msg : Discord::Message)
    channel(msg).guild_id
  end

  private def amount(msg : Discord::Message, string)
    if string == "all"
      amount = @tip.get_balance(msg.author.id)
    else
      if m = /(?<amount>^[0-9,\.]+)/.match(string)
        amount = m["amount"].try &.to_f64
      end
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
    unless @config.admins.includes?(msg.author.id)
      return reply(msg, "**ERROR**: This is a admin only command!")
    end
    # TODO format message
    reply(msg, "#{@tip.get_info}")
  end

  # transfer from user to user
  def tip(msg : Discord::Message)
    return reply(msg, "**ERROR**: Who are you planning on tipping? yourself?") if private?(msg)

    cmd_usage = "`#{@config.prefix}tip [@user] [amount]`"
    # cmd[0]: trigger, cmd[1]: user, cmd[2]: amount
    cmd = msg.content.split(" ")

    return reply(msg, "Error! Usage: #{cmd_usage}") unless cmd.size > 2

    match = USER_REGEX.match(cmd[1])
    id = match["id"].try &.to_u64 if match

    err = "Error: Please specify the user you want to tip! #{cmd_usage}"
    return reply(msg, err) unless id
    begin
      to = @cache.resolve_user(id)
    rescue
      return reply(msg, err)
    end

    return reply(msg, "**ERROR**: As a design choice you aren't allowed to tip Bot accounts") if to.bot

    return reply(msg, "**ERROR**: You trying to tip yourself!?") if id == msg.author.id

    amount = amount(msg, cmd[2])
    return reply(msg, "Error: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "Error: You have to tip at least #{@config.min_tip} #{@config.coinname_short}") if amount < @config.min_tip

    case @tip.transfer(from: msg.author.id, to: id, amount: amount, memo: "tip")
    when "success"
      return reply(msg, "#{msg.author.username} tipped **#{amount} #{@config.coinname_short}** to **#{to.username}**")
    when "insufficient balance"
      return reply(msg, "Insufficient Balance")
    when "error"
      return reply(msg, "Something went wrong!")
    end
  end

  # withdraw amount to address
  def withdraw(msg : Discord::Message)
    cmd_usage = "#{@config.prefix}withdraw [address] [amount]"

    # cmd[0]: command, cmd[1]: address, cmd[2]: amount
    cmd = msg.content.split(" ")

    return reply(msg, "Error! Usage: #{cmd_usage}") unless cmd.size > 2

    amount = amount(msg, cmd[2])
    return reply(msg, "Error: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "You have to withdraw at least #{@config.min_withdraw}") if amount <= @config.min_withdraw

    address = cmd[1]
    return reply(msg, "Error: Please specify a valid #{@config.coinname_full} address") unless @tip.validate_address(address)

    case @tip.withdraw(msg.author.id, address, amount)
    when "insufficient balance"
      return reply(msg, "**ERROR:** You tried withdrawing too much. Also make sure you've got enough balance to cover the Transaction fee as well: #{@config.txfee}")
    when false
      return reply(msg, "**ERROR:** Please try again later")
    when true
      reply(msg, "Successfully withdrew **#{amount} #{@config.coinname_short}** to **#{address}**")
    end
  end

  # return deposit address
  def deposit(msg : Discord::Message)
    return reply(msg, "This command doesn't work in public channels! Please use this command in a Direct Message") unless private?(msg)

    reply(msg, "You're deposit address is: **#{@tip.get_address(msg.author.id)}**\nPlease keep in mind, that this address is for one time use only. After every deposit your address will reset! Don't use this address to receive from faucets, pools, etc.")
  end

  # send coins to all currently online users
  def soak(msg : Discord::Message)
    return reply(msg, "**ERROR**: Who are you planning on making wet? yourself?") if private?(msg)

    cmd_usage = "#{@config.prefix}soak [amount]"

    # cmd[0]: command, cmd[1]: amount
    cmd = msg.content.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**You have to soak at least #{@config.min_soak_total} #{@config.coinname_short}**") unless amount >= @config.min_soak_total

    return reply(msg, "**ERROR**: Something went wrong") unless guild_id = guild_id(msg)

    users = Array(UInt64).new
    last_id = 0_u64

    loop do
      new_users = @bot.list_guild_members(guild_id, after: last_id)
      break if new_users.size == 0
      last_id = new_users.last.user.id
      new_users.reject!(&.user.bot)
      new_users.each { |x| users << x.user.id unless x.user.id == msg.author.id }
    end

    # TODO only soak online people
    # TODO only soak people that can view the channel

    return reply(msg, "No one wants to get wet right now :sob:") unless users.size > 1

    if (users.size * @config.min_soak) > @config.min_soak_total
      targets = users.sample((@config.min_soak_total / @config.min_soak).to_i32)
    else
      targets = users
    end
    targets.reject! { |x| x == nil }

    case @tip.multi_transfer(from: msg.author.id, users: targets, total: amount, memo: "soak")
    when "insufficient balance"
      return reply(msg, "**ERROR**: Insufficient Balance")
    when false
      reply(msg, "**ERROR**: Please try again later")
    when true
      string = ""
      targets.each { |x| string = string + ", <@#{x}>"}
      reply(msg, "#{msg.author.username} soaked #{amount} #{@config.coinname_short} onto #{string}")
    end
  end

  # split amount between people who recently sent a message
  def rain(msg : Discord::Message)
    return reply(msg, "**ERROR**: Who are you planning on tipping? yourself?") if private?(msg)

    cmd_usage = "#{@config.prefix}rain [amount]"

    # cmd[0]: command, cmd[1]: amount
    cmd = msg.content.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**You have to soak at least #{@config.min_rain_total} #{@config.coinname_short}**") unless amount >= @config.min_rain_total

    return reply(msg, "**ERROR**: Something went wrong") unless guild_id = guild_id(msg)

    msgs = Array(Discord::Message).new
    channel = @cache.resolve_channel(msg.channel_id)
    last_id = channel.last_message_id
    before = Time.now - 10.minutes

    loop do
      new_msgs = @bot.get_channel_messages(msg.channel_id, before: last_id)
      if new_msgs.size < 50
        new_msgs.each { |x| msgs << x }
        break
      end
      break if new_msgs.last.timestamp > before
      last_id = new_msgs.last.id
      new_msgs.each { |x| msgs << x }
    end

    msgs.reject!(&.author.bot)
    msgs.reject! { |x| x.timestamp < before }
    msgs.reject! { |x| x.author == msg.author }

    authors = Array(UInt64).new
    msgs.each { |x| authors << x.author.id }
    authors.uniq!

    case @tip.multi_transfer(from: msg.author.id, users: authors, total: amount, memo: "rain")
    when "insufficient balance"
      return reply(msg, "**ERROR**: Insufficient Balance")
    when false
      reply(msg, "**ERROR**: Please try again later")
    when true
      string = ""
      authors.each { |x| string = string + ", <@#{x}>"}
      reply(msg, "#{msg.author.username} rained **#{amount} #{@config.coinname_short}** onto #{string}")
    end
  end

  # the users balance
  def balance(msg : Discord::Message)
    reply(msg, "Your balance is: #{@tip.get_balance(msg.author.id)} #{@config.coinname_short}")
  end
end
