require "./utilities"

class DiscordBot
  include Utilities

  USER_REGEX = /<@!?(?<id>\d+)>/
  START_TIME = Time.now
  TERMS      = "In no event shall this bot or its dev be responsible for any loss, theft or misdirection of funds."

  def initialize(@config : Config, @log : Logger)
    @log.debug("#{@config.coinname_short}: starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @cache = Discord::Cache.new(@bot)
    @bot.cache = @cache
    @tip = TipBot.new(@config, @log)
    @active_users_cache = ActivityCache.new(10.minutes)

    bot_id = @cache.resolve_current_user.id
    prefix_regex = /^(?:#{@config.prefix}|<@!?#{bot_id}> ?)(?<cmd>.*)/

    @bot.on_message_create do |msg|
      next if msg.author.id == bot_id

      content = msg.content

      if private?(msg)
        content = @config.prefix + content unless content.match(prefix_regex)
      end

      next unless match = content.match(prefix_regex)
      next unless cmd = match.named_captures["cmd"]

      # If a command expects input pass in parsed command
      case cmd
      when .starts_with? "ping"
        self.ping(msg)
      when .starts_with? "tip"
        self.tip(msg, cmd)
      when .starts_with? "withdraw"
        self.withdraw(msg, cmd)
      when .starts_with? "deposit"
        self.deposit(msg)
      when .starts_with? "address"
        self.deposit(msg)
      when .starts_with? "soak"
        self.soak(msg, cmd)
      when .starts_with? "rain"
        self.rain(msg, cmd)
      when .starts_with? "balance"
        self.balance(msg)
      when .starts_with? "bal"
        self.balance(msg)
      when .starts_with? "getinfo"
        self.getinfo(msg)
      when .starts_with? "help"
        self.help(msg)
      when .starts_with? "config"
        self.config(msg, cmd)
      when .starts_with? "terms"
        self.terms(msg)
      when .starts_with? "blocks"
        self.blocks(msg)
      when .starts_with? "connections"
        self.connections(msg)
      when .starts_with? "admin"
        self.admin(msg, cmd)
      when .starts_with? "active"
        self.active(msg)
      when .starts_with? "support"
        self.support(msg)
      when .starts_with? "invite"
        self.invite(msg)
      when .starts_with? "uptime"
        self.uptime(msg)
      when .starts_with? "checkconfig"
        self.check_config(msg)
      when .starts_with? "stats"
        self.stats(msg)
      when .starts_with? "lucky"
        self.lucky(msg, cmd)
      when .starts_with? "exit"
        self.exit(msg)
      end
    end

    @bot.on_ready do
      @log.info("#{@config.coinname_short}: #{@config.coinname_full} bot received READY")

      # Make use of the status to display info
      spawn do
        Discord.every(1.minutes) do
          update_game("#{@config.prefix}help | Serving #{@cache.users.size} users in #{@cache.guilds.size} guilds")
        end
      end
    end

    # Add user to active_users_cache on new message unless bot user
    @bot.on_message_create do |msg|
      @active_users_cache.touch(msg.channel_id, msg.author.id, msg.timestamp.to_utc) unless msg.author.bot
    end

    # Add server to config, if not existent
    @bot.on_guild_create do |guild|
      @tip.add_server(guild.id)
      string = "Hey! Someone just added me to your guild (#{guild.name}). By default, raining and soaking are disabled. Configure the bot using `#{@config.prefix}config [rain/soak/mention] [on/off]`. If you have any further questions, please join the support guild at http://tipbot.gbf.re"

      unless @tip.get_config(guild.id, "contacted")
        begin
          contact = @bot.create_message(@cache.resolve_dm_channel(guild.owner_id), string)
        rescue
          @log.error("#{@config.coinname_short}: Failed contacting #{guild.owner_id}")
        end
        @tip.update_config("contacted", true, guild.id) if contact
      end
    end

    # Check if total user balance exceeds node balance every ~60 seconds in extra fiber
    spawn do
      Discord.every(60.seconds) do
        node = @tip.node_balance
        next if node.nil?

        users = @tip.deposit_sum - @tip.withdrawal_sum

        if node < @tip.db_balance || node < users
          string = "**ALARM**: Total user balance exceeds node balance\n*Shutting bot down*"
          @config.admins.each do |x|
            @bot.create_message(@cache.resolve_dm_channel(x), string)
          end
          @log.error("#{@config.coinname_short}: #{string}")
          exit
        end
      end
    end

    # receive wallet transactions and insert into coin_transactions
    spawn do
      server = HTTP::Server.new(@config.walletnotify_port) do |context|
        next unless context.request.method == "POST"
        @tip.insert_tx(context.request.query_params["tx"])
      end
      server.listen
    end

    # on launch check for deposits and insert them into coin_transactions during down time
    spawn do
      @tip.insert_history_deposits
      @log.info("#{@config.coinname_short}: Inserted deposits during down time")
    end

    # check for confirmed deposits every 60 seconds
    spawn do
      Discord.every(30.seconds) do
        users = @tip.check_deposits
        @log.debug("#{@config.coinname_short}: Checked deposits")
        next if users.nil?
        next if users.empty?
        users.each do |x|
          dm_deposit(x)
        end
      end
    end

    # warn users that the tipbot shouldn't be used as wallet if their balance exceeds @config.high_balance
    spawn do
      Discord.every(6.hours) do
        users = @tip.get_high_balance(@config.high_balance)

        users.each do |x|
          @bot.create_message(@cache.resolve_dm_channel(x.to_u64), "Your balance exceeds #{@config.high_balance} #{@config.coinname_short}. You should consider withdrawing some coins! You should not use this bot as your wallet!")
        end
      end
    end

    # periodically clean up the user activity cache
    spawn do
      Discord.every(60.minutes) do
        @active_users_cache.prune
      end
    end
  end

  # Since there is no easy way, just to reply to a message
  private def reply(payload : Discord::Message, msg : String)
    if msg.size > 2000
      msgs = split(msg)
      msgs.each { |x| @bot.create_message(payload.channel_id, x) }
    else
      @bot.create_message(payload.channel_id, msg)
    end
  rescue
    @log.warn("#{@config.coinname_short}: bot failed sending a msg to #{payload.channel_id} with text: #{msg}")
  end

  private def update_game(name : String)
    @bot.status_update("online", Discord::GamePlaying.new(name, 0_i64))
  end

  private def dm_deposit(userid : UInt64)
    @bot.create_message(@cache.resolve_dm_channel(userid), "Your deposit just went through! Remember: Deposit Addresses are *one-time* use only so you'll have to generate a new address for your next deposit!\n*#{TERMS}*")
  rescue ex
    user = @cache.resolve_user(userid)
    @log.warn("#{@config.coinname_short}: Failed to contact #{userid} (#{user.username}##{user.discriminator}}) with deposit notification (Exception: #{ex.inspect_with_backtrace})")
  end

  private def private?(msg : Discord::Message)
    channel(msg).type == 1
  end

  private def channel(msg : Discord::Message) : Discord::Channel
    @cache.resolve_channel(msg.channel_id)
  end

  private def guild_id(msg : Discord::Message)
    channel(msg).guild_id.as(UInt64)
  end

  private def amount(msg : Discord::Message, string) : BigDecimal?
    if string == "all"
      @tip.get_balance(msg.author.id)
    elsif m = /(?<amount>^[0-9,\.]+)/.match(string)
      begin
        return nil unless string == m["amount"]
        BigDecimal.new(m["amount"]).round(8)
      rescue InvalidBigDecimalException
      end
    end
  end

  private def trigger_typing(msg : Discord::Message)
    @bot.trigger_typing_indicator(msg.channel_id)
  end

  def run
    @bot.run
  end

  # All helper methods for handling discord commands below

  # respond with pong
  def ping(msg : Discord::Message)
    reply(msg, "pong")
  end

  # respond getinfo RPC
  def getinfo(msg : Discord::Message)
    return reply(msg, "**ALARM**: This is an admin only command!") unless @config.admins.includes?(msg.author.id)
    return reply(msg, "**ERROR**: This command can only be used in DMs") unless private?(msg)

    info = @tip.get_info
    return unless info.is_a?(Hash(String, JSON::Type))

    balance = info["balance"]
    blocks = info["blocks"]
    connections = info["connections"]
    errors = info["errors"]

    string = "**Balance**: #{balance}\n**Blocks**: #{blocks}\n**Connections**: #{connections}\n**Errors**: *#{errors}*"

    reply(msg, string)
  end

  def help(msg : Discord::Message)
    cmds = {"ping", "uptime", "tip", "soak", "rain", "active", "balance", "terms", "withdraw", "deposit", "support", "invite"}
    string = String.build do |str|
      cmds.each { |x| str << "`" + @config.prefix + x + "`, " }
    end

    string = string.rchop(", ")

    reply(msg, "Currently the following commands are available: #{string}")
  end

  # transfer from user to user
  def tip(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: Who are you planning on tipping? yourself?") if private?(msg)

    cmd_usage = "`#{@config.prefix}tip [@user] [amount]`"
    # cmd[0]: trigger, cmd[1]: user, cmd[2]: amount
    cmd = cmd_string.split(" ")

    return reply(msg, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size > 2

    match = USER_REGEX.match(cmd[1])
    id = match["id"].try &.to_u64 if match

    err = "**ERROR**: Please specify the user you want to tip! #{cmd_usage}"
    return reply(msg, err) unless id
    begin
      to = @cache.resolve_user(id)
    rescue
      return reply(msg, err)
    end

    return reply(msg, "**ERROR**: As a design choice you aren't allowed to tip Bot accounts") if to.bot

    return reply(msg, "**ERROR**: Are you trying to tip yourself!?") if id == msg.author.id

    amount = amount(msg, cmd[2])
    return reply(msg, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to tip at least #{@config.min_tip} #{@config.coinname_short}") if amount < @config.min_tip

    case @tip.transfer(from: msg.author.id, to: id, amount: amount, memo: "tip")
    when "success"
      reply(msg, "#{msg.author.username} tipped **#{amount} #{@config.coinname_short}** to **#{to.username}**")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when "error"
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    end
  end

  # withdraw amount to address
  def withdraw(msg : Discord::Message, cmd_string : String)
    cmd_usage = "#{@config.prefix}withdraw [address] [amount]"

    # cmd[0]: command, cmd[1]: address, cmd[2]: amount
    cmd = cmd_string.split(" ")

    return reply(msg, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size > 2

    amount = amount(msg, cmd[2])
    return reply(msg, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to withdraw at least #{@config.min_withdraw}") if amount <= @config.min_withdraw

    address = cmd[1]

    case @tip.withdraw(msg.author.id, address, amount)
    when "insufficient balance"
      reply(msg, "**ERROR**: You tried withdrawing too much. Also make sure you've got enough balance to cover the Transaction fee as well: #{@config.txfee} #{@config.coinname_short}")
    when "invalid address"
      reply(msg, "**ERROR**: Please specify a valid #{@config.coinname_full} address")
    when "internal address"
      reply(msg, "**ERROR**: Withdrawing to an internal address isn't permitted")
    when false
      reply(msg, "**ERROR**: There was a problem trying to withdraw. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      reply(msg, "Successfully withdrew **#{amount} #{@config.coinname_short}** to **#{address}**")
    end
  end

  # return deposit address
  def deposit(msg : Discord::Message)
    notif = reply(msg, "Sent deposit address in a DM") unless private?(msg)
    begin
      address = @tip.get_address(msg.author.id)
      embed = Discord::Embed.new(
        footer: Discord::EmbedFooter.new("I love you! ❤"),
        image: Discord::EmbedImage.new("https://chart.googleapis.com/chart?cht=qr&chs=300x300&chld=L%7C1&chl=#{@config.uri_scheme}:#{address}")
      )
      @bot.create_message(@cache.resolve_dm_channel(msg.author.id), "Your deposit address is: **#{address}**\nPlease keep in mind, that this address is for **one time use only**. After every deposit your address will reset! Don't use this address to receive from faucets, pools, etc.\nDeposits take **#{@config.confirmations} confirmations** to get credited!\n*#{TERMS}*", embed)
    rescue
      reply(msg, "**ERROR**: Could not send deposit details in a DM. Enable `allow direct messages from server members` in your privacy settings")
      return unless notif.is_a?(Discord::Message)
      @bot.delete_message(notif.channel_id, notif.id)
    end
  end

  # send coins to all currently online users
  def soak(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: Who are you planning on making wet? yourself?") if private?(msg)

    return reply(msg, "The owner of this server has disabled #{@config.prefix}soak. You can contact them and ask them to enable it as they should have received a DM with instructions") unless @tip.get_config(guild_id(msg), "soak")

    cmd_usage = "#{@config.prefix}soak [amount]"

    # cmd[0]: command, cmd[1]: amount
    cmd = cmd_string.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to soak at least **#{@config.min_soak_total} #{@config.coinname_short}**") unless amount >= @config.min_soak_total

    return reply(msg, "**ERROR**: Something went wrong") unless guild_id = guild_id(msg)

    trigger_typing(msg)

    users = Array(UInt64).new
    last_id = 0_u64

    loop do
      new_users = @bot.list_guild_members(guild_id, after: last_id)
      break if new_users.size == 0
      last_id = new_users.last.user.id
      new_users.reject!(&.user.bot)
      new_users.each do |x|
        users << x.user.id unless x.user.id == msg.author.id
        @cache.cache(x.user)
      end
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
      reply(msg, "**ERROR**: Insufficient balance")
    when false
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      amount_each = amount / targets.size

      string = build_user_string(get_config_mention(msg), targets)

      reply(msg, "**#{msg.author.username}** soaked a total of **#{amount} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
    end
  end

  # split amount between people who recently sent a message
  def rain(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: Who are you planning on tipping? yourself?") if private?(msg)

    return reply(msg, "The owner of this server has disabled #{@config.prefix}rain. You can contact them and ask them to enable it as they should have received a DM with instructions") unless @tip.get_config(guild_id(msg), "rain")

    cmd_usage = "#{@config.prefix}rain [amount]"

    # cmd[0]: command, cmd[1]: amount
    cmd = cmd_string.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to rain at least #{@config.min_rain_total} #{@config.coinname_short}") unless amount >= @config.min_rain_total

    return reply(msg, "**ERROR**: Something went wrong") unless guild_id = guild_id(msg)

    authors = active_users(msg)
    return reply(msg, "**ERROR**: There is nobody to rain on!") if authors.nil? || authors.empty?

    case @tip.multi_transfer(from: msg.author.id, users: authors, total: amount, memo: "rain")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when false
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      amount_each = amount / authors.size

      string = build_user_string(get_config_mention(msg), authors)

      reply(msg, "**#{msg.author.username}** rained a total of **#{amount} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
    end
  end

  private def get_config_mention(msg : Discord::Message)
    @tip.get_config(guild_id(msg), "mention") || false
  end

  private def get_config(msg : Discord::Message, memo : String)
    @tip.get_config(guild_id(msg), memo)
  end

  def lucky(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: This command doesn't work in DMs") if private?(msg)

    cmd_usage = "#{@config.prefix}lucky [amount]"

    # cmd[0]: command, cmd[1]: amount"
    cmd = cmd_string.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to lucky rain at least #{@config.min_tip} #{@config.coinname_short}") unless amount >= @config.min_tip

    users = active_users(msg)

    return reply(msg, "**ERROR**: There is no one to make lucky!") unless users && (users = users.to_a).size > 0

    user = users.sample

    case @tip.transfer(from: msg.author.id, to: user, amount: amount, memo: "lucky")
    when "success"
      reply(msg, "#{msg.author.username} luckily rained **#{amount} #{@config.coinname_short}** onto **<@#{user}>**")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when "error"
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    end
  end

  def active(msg : Discord::Message)
    return reply(msg, "You cannot use this command in a private channel!") if private?(msg)

    authors = active_users(msg)
    return reply(msg, "No active users!") if authors.nil? || authors.empty?

    singular = authors.size == 1
    reply(msg, "There #{singular ? "is" : "are"} **#{authors.size}** active user#{singular ? "" : "s"} ATM")
  end

  # the users balance
  def balance(msg : Discord::Message)
    reply(msg, "#{msg.author.username} has a confirmed balance of **#{@tip.get_balance(msg.author.id)} #{@config.coinname_short}**")
  end

  # Config command (available to admins and respective server owner)
  def config(msg : Discord::Message, cmd_string : String)
    reply(msg, "Since it's hard to identify which server you want to configure if you run these commands in DMs, please rather use them in the respective server") if private?(msg)

    return reply(msg, "**ALARM**: This command can only be used by the guild owner") unless @cache.resolve_guild(guild_id(msg)).owner_id == msg.author.id || @config.admins.includes?(msg.author.id)

    cmd_usage = "#{@config.prefix}config [rain/soak/mention] [on/off]"
    # cmd[0] = cmd, cmd[1] = memo, cmd[2] = status
    cmd = cmd_string.split(" ")

    return reply(msg, cmd_usage) unless cmd.size == 3
    return reply(msg, cmd_usage) unless {"rain", "soak", "mention"}.includes?(cmd[1]) && {"on", "off"}.includes?(cmd[2])

    memo = cmd[1]
    if cmd[2] == "on"
      status = true
    else
      status = false
    end

    reply(msg, "Successfully turned #{memo} #{cmd[2]}") if @tip.update_config(memo, status, guild_id(msg))
  end

  def check_config(msg : Discord::Message)
    string = String.build do |str|
      unless private?(msg)
        mention = get_config(msg, "mention")
        rain = get_config(msg, "rain")
        soak = get_config(msg, "soak")
        str.puts "Mentioning: #{mention}"
        str.puts "Raining: #{rain}"
        str.puts "Soaking: #{soak}"
      end
      str.puts "Minimum tip: #{@config.min_tip}"
      str.puts "Minimum rain: #{@config.min_rain_total}"
      str.puts "Minimum soak: #{@config.min_soak_total}"
    end

    reply(msg, string)
  end

  def terms(msg : Discord::Message)
    reply(msg, TERMS)
  end

  def blocks(msg : Discord::Message)
    info = @tip.get_info
    return unless info.is_a?(Hash(String, JSON::Type))

    reply(msg, "Current Block Count (known to the node): **#{info["blocks"]}**")
  end

  def connections(msg : Discord::Message)
    info = @tip.get_info
    return unless info.is_a?(Hash(String, JSON::Type))

    reply(msg, "The node has **#{info["connections"]} Connections**")
  end

  def admin(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ALARM**: This is an admin only command! You have been reported!") unless @config.admins.includes?(msg.author.id)
    return reply(msg, "**ERROR**: This command only works in DMs") unless private?(msg)

    # cmd[0] = command, cmd[1] = type, cmd [2] = user
    cmd = cmd_string.split(" ")

    return reply(msg, "Current total user balances: **#{@tip.db_balance}**") if cmd.size == 1

    if cmd[1] == "unclaimed"
      node = @tip.node_balance
      return if node.nil?
      unclaimed = node - (@tip.deposit_sum - @tip.withdrawal_sum)

      return reply(msg, "Unclaimed coins: **#{unclaimed}** #{@config.coinname_short}")
    end

    if cmd[1]? == "balance"
      return reply(msg, "**ERROR**: You forgot to supply an ID to check balance of") unless cmd[2]?
      bal = @tip.get_balance(cmd[2].to_u64)
      reply(msg, "**#{cmd[2]}**'s balance is: **#{bal}** #{@config.coinname_short}")
    end
  end

  def invite(msg : Discord::Message)
    reply(msg, "You can add this bot to your own guild using following URL: <https://discordapp.com/oauth2/authorize?&client_id=#{@config.discord_client_id}&scope=bot>")
  end

  def support(msg : Discord::Message)
    reply(msg, "For support please visit <http://tipbot.gbf.re>")
  end

  def uptime(msg : Discord::Message)
    reply(msg, "Bot has been running for #{Time.now - START_TIME}")
  end

  def stats(msg : Discord::Message)
    guilds = @cache.guilds.size
    cached_users = @cache.users.size
    users = @cache.guilds.values.map { |x| x.member_count || 0 }.sum

    reply(msg, "The bot is in #{guilds} Guilds and sees #{users} users (of which #{cached_users} users are guaranteed unique)")
  end

  def exit(msg : Discord::Message)
    id = msg.author.id
    return reply(msg, "**ALARM**: This is an admin only command! You have been reported!") unless @config.admins.includes?(id)

    @log.warn("#{@config.coinname_short}: Shutdown requested by #{id}")
    exit
  end

  private def active_users(msg : Discord::Message)
    cache_users(msg) if Time.now - START_TIME < 10.minutes

    authors = @active_users_cache.resolve_to_id(msg.channel_id)
    return unless authors
    authors.delete(msg.author.id)
    authors
  end

  private def cache_users(msg : Discord::Message)
    trigger_typing(msg)

    msgs = Array(Discord::Message).new
    channel = @bot.get_channel(msg.channel_id)
    last_id = channel.last_message_id
    before = Time.now - 10.minutes

    loop do
      new_msgs = @bot.get_channel_messages(msg.channel_id, before: last_id)
      if new_msgs.size < 50
        new_msgs.each { |x| msgs << x }
        break
      end
      last_id = new_msgs.last.id
      new_msgs.each { |x| msgs << x }
      break if new_msgs.last.timestamp < before
    end

    msgs.each do |x|
      next if x.author.bot
      @active_users_cache.add_if_youngest(x.channel_id, x.author.id, x.timestamp.to_utc)
    end
  end
end
