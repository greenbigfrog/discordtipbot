require "./utilities"

class DiscordBot
  include Utilities

  USER_REGEX = /<@!?(?<id>\d+)>/
  START_TIME = Time.now
  TERMS      = "In no event shall this bot or its dev be responsible for any loss, theft or misdirection of funds."
  ZWS        = "​" # There is a zero width space stored here

  @unavailable_guilds = Set(UInt64).new
  @available_guilds = Set(UInt64).new

  def initialize(@config : Config, @log : Logger)
    @log.debug("#{@config.coinname_short}: starting bot: #{@config.coinname_full}")
    @bot = Discord::Client.new(token: @config.discord_token, client_id: @config.discord_client_id)
    @cache = Discord::Cache.new(@bot)
    @bot.cache = @cache
    @tip = TipBot.new(@config, @log)
    @active_users_cache = ActivityCache.new(10.minutes)
    @presence_cache = PresenceCache.new
    @webhook = Discord::Client.new("")

    bot_id = @cache.resolve_current_user.id
    @prefix_regex = /^(?:#{@config.prefix}|<@!?#{bot_id}> ?)(?<cmd>.*)/

    @bot.on_message_create(ErrorCatcher.new) do |msg|
      next if msg.author.id.to_u64 == bot_id

      content = msg.content

      if private_channel?(msg)
        content = @config.prefix + content unless content.match(@prefix_regex)
      end

      next unless match = content.match(@prefix_regex)
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
      when .starts_with? "reload_conf" || "load_conf"
        self.admin_config(msg, cmd)
      when .starts_with? "active"
        self.active(msg)
      when .starts_with? "support"
        self.support(msg)
      when .starts_with? "github"
        self.github(msg)
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
      when .starts_with? "statistics"
        self.statistics(msg)
      when .starts_with? "donate"
        self.donate(msg, cmd)
      when .starts_with? "offsite"
        self.offsite(msg, cmd)
      end
    end

    display_info_in_status

    # Add user to active_users_cache on new message unless bot user
    @bot.on_message_create(ErrorCatcher.new) do |msg|
      next if msg.content.match @prefix_regex
      @active_users_cache.touch(msg.channel_id.to_u64, msg.author.id.to_u64, msg.timestamp.to_utc) unless msg.author.bot
    end

    # Check if it's time to send off (or on) site
    raven_spawn do
      Discord.every(10.seconds) do
        check_and_notify_if_its_time_to_send_back_onsite
        check_and_notify_if_its_time_to_send_offsite
      end
    end

    handle_guilds

    @bot.on_presence_update(ErrorCatcher.new) do |presence|
      @presence_cache.handle_presence(presence)

      @cache.cache(Discord::User.new(presence.user)) if presence.user.full?
    end

    # receive wallet transactions and insert into coin_transactions
    raven_spawn do
      server = HTTP::Server.new do |context|
        next unless context.request.method == "POST"
        @tip.insert_tx(context.request.query_params["tx"])
      end
      server.bind_tcp(@config.walletnotify_port)
      server.listen
    end

    # on launch check for deposits and insert them into coin_transactions during down time
    raven_spawn do
      @tip.insert_history_deposits
      @log.info("#{@config.coinname_short}: Inserted deposits during down time")
    end

    # check for confirmed deposits every 60 seconds
    raven_spawn do
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

    # Check for pending withdrawals every X seconds
    raven_spawn do
      Discord.every(30.seconds) do
        users = @tip.process_pending_withdrawals
        users.each do |x|
          begin
            @bot.create_message(@cache.resolve_dm_channel(x.to_u64), "Your withdrawal just got processed" + Emoji::CHECK)
          rescue
            raise "#{config.coinname_short}: Unable to send confirmation message to #{x}, while processing pending withdrawals"
          end
        end
      end
    end

    # warn users that the tipbot shouldn't be used as wallet if their balance exceeds @config.high_balance
    raven_spawn do
      Discord.every(1.hours) do
        if Set{6, 18}.includes?(Time.now.hour)
          users = @tip.get_high_balance(@config.high_balance)

          users.each do |x|
            @bot.create_message(@cache.resolve_dm_channel(x.to_u64), "Your balance exceeds #{@config.high_balance} #{@config.coinname_short}. You should consider withdrawing some coins! You should not use this bot as your wallet!")
          end
        end
      end
    end

    # periodically clean up the user activity cache
    raven_spawn do
      Discord.every(60.minutes) do
        @active_users_cache.prune
      end
    end
  end

  # Since there is no easy way, just to reply to a message
  private def reply(payload : Discord::Message, msg : String)
    if msg.size > 2000
      msgs = split(msg)
      msgs.each { |x| @bot.create_message(payload.channel_id.to_u64, x) }
    else
      @bot.create_message(payload.channel_id.to_u64, msg)
    end
  rescue
    @log.warn("#{@config.coinname_short}: bot failed sending a msg to #{payload.channel_id} with text: #{msg}")
  end

  private def dm_deposit(userid : UInt64)
    @bot.create_message(@cache.resolve_dm_channel(userid), "Your deposit just went through! Remember: Deposit Addresses are *one-time* use only so you'll have to generate a new address for your next deposit!\n*#{TERMS}*")
  rescue ex
    user = @cache.resolve_user(userid)
    @log.warn("#{@config.coinname_short}: Failed to contact #{userid} (#{user.username}##{user.discriminator}}) with deposit notification (Exception: #{ex.inspect_with_backtrace})")
  end

  private def private_channel?(msg : Discord::Message)
    channel(msg).type == Discord::ChannelType::DM
  end

  private def channel(msg : Discord::Message) : Discord::Channel
    @cache.resolve_channel(msg.channel_id)
  end

  private def guild_id(msg : Discord::Message)
    id = channel(msg).guild_id
    # If it's a DM channel, it won't have an Guild ID. Else it should.
    raise "Somehow we tried getting the Guild ID of a DM" unless id
    id.to_u64
  end

  private def amount(msg : Discord::Message, string) : BigDecimal?
    if string == "all"
      @tip.get_balance(msg.author.id.to_u64)
    elsif string == "half"
      BigDecimal.new(@tip.get_balance(msg.author.id.to_u64) / 2).round(8)
    elsif string == "rand"
      BigDecimal.new(Random.rand(1..6))
    elsif string == "bigrand"
      BigDecimal.new(Random.rand(1..42))
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
    m = reply(msg, "Pong!")
    return unless m.is_a?(Discord::Message)
    time = Time.utc_now - msg.timestamp
    @bot.edit_message(m.channel_id, m.id, "Pong! *Time taken: #{time.total_milliseconds} ms.*")
  end

  # respond getinfo RPC
  def getinfo(msg : Discord::Message)
    return if admin_alarm?(msg)
    return reply(msg, "**ERROR**: This command can only be used in DMs") unless private_channel?(msg)

    info = @tip.get_info.as_h
    return unless info.is_a?(Hash(String, JSON::Any))

    balance = info["balance"]
    blocks = info["blocks"]
    connections = info["connections"]
    errors = info["errors"]

    string = "**Balance**: #{balance}\n**Blocks**: #{blocks}\n**Connections**: #{connections}\n**Errors**: *#{errors}*"

    reply(msg, string)
  end

  def help(msg : Discord::Message)
    cmds = {"ping", "uptime", "tip", "soak", "rain", "active", "balance", "terms", "withdraw", "deposit", "support", "github", "invite"}
    string = String.build do |str|
      cmds.each { |x| str << "`" + @config.prefix + x + "`, " }
    end

    string = string.rchop(", ")

    reply(msg, "Currently the following commands are available: #{string}")
  end

  private def get_config_mention(msg : Discord::Message)
    @tip.get_config(guild_id(msg), "mention") || false
  end

  private def get_config(msg : Discord::Message, memo : String)
    @tip.get_config(guild_id(msg), memo)
  end

  def active(msg : Discord::Message)
    return if private?(msg)

    authors = active_users(msg)
    return reply(msg, "No active users!") if authors.nil? || authors.empty?

    singular = authors.size == 1
    reply(msg, "There #{singular ? "is" : "are"} **#{authors.size}** active user#{singular ? "" : "s"} ATM")
  end

  # the users balance
  def balance(msg : Discord::Message)
    reply(msg, "#{msg.author.username} has a confirmed balance of **#{@tip.get_balance(msg.author.id.to_u64)} #{@config.coinname_short}**")
  end

  # Config command (available to admins and respective server owner)
  def config(msg : Discord::Message, cmd_string : String)
    reply(msg, "Since it's hard to identify which server you want to configure if you run these commands in DMs, please rather use them in the respective server") if private_channel?(msg)

    return reply(msg, "**ALARM**: This command can only be used by the guild owner") unless @cache.resolve_guild(guild_id(msg)).owner_id == msg.author.id || admin?(msg)
    cmd_usage = "#{@config.prefix}config [rain/soak/mention] [on/off]"
    # cmd[0] = cmd, cmd[1] = memo, cmd[2] = status
    cmd = cmd_string.cmd_split

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
      unless private_channel?(msg)
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
    return unless info.is_a?(Hash(String, JSON::Any))

    reply(msg, "Current Block Count (known to the node): **#{info["blocks"]}**")
  end

  def connections(msg : Discord::Message)
    info = @tip.get_info
    return unless info.is_a?(Hash(String, JSON::Any))

    reply(msg, "The node has **#{info["connections"]} Connections**")
  end

  def invite(msg : Discord::Message)
    reply(msg, "You can add this bot to your own guild using following URL: <https://discordapp.com/oauth2/authorize?&client_id=#{@config.discord_client_id}&scope=bot>")
  end

  def support(msg : Discord::Message)
    reply(msg, "For support please visit <http://tipbot.gbf.re>")
  end

  def github(msg : Discord::Message)
    reply(msg, "To contribute to the development of the tipbot visit <https://github.com/greenbigfrog/discordtipbot/>")
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
    id = msg.author.id.to_u64
    return if admin_alarm?(msg)

    @log.warn("#{@config.coinname_short}: Shutdown requested by #{id}")
    exit
  end

  def statistics(msg : Discord::Message)
    stats = Statistics.get(@tip.db)
    string = String.build do |io|
      io.puts "*Currently the users of this bot have:*"
      io.puts "Transfered a total of **#{stats.total} #{@config.coinname_short}** in #{stats.transactions} transactions"
      io.puts
      io.puts "Of these **#{stats.tips} #{@config.coinname_short}** were tips,"
      io.puts "**#{stats.rains} #{@config.coinname_short}** were rains and"
      io.puts "**#{stats.soaks} #{@config.coinname_short}** were soaks."
      io.puts "*Last updated at #{Statistics.last}*"
    end

    reply(msg, string)
  end

  private def active_users(msg : Discord::Message)
    cache_users(msg) if Time.now - START_TIME < 10.minutes

    authors = @active_users_cache.resolve_to_id(msg.channel_id.to_u64)
    return unless authors
    authors.delete(msg.author.id.to_u64)
    authors - @config.ignored_users.to_a
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
      next if x.content.match @prefix_regex
      @active_users_cache.add_if_youngest(x.channel_id.to_u64, x.author.id.to_u64, x.timestamp.to_utc)
    end
  end

  private def post_embed_to_webhook(embed : Discord::Embed, webhook : Webhook)
    @webhook.execute_webhook(webhook.id, webhook.token, embeds: [embed])
  end

  private def bot?(user : Discord::User)
    bot_status = user.bot
    if bot_status
      return false if @config.whitelisted_bots.includes?(user.id)
    end
    bot_status
  end

  private def admin?(msg : Discord::Message)
    @config.admins.includes?(msg.author.id.to_u64)
  end

  private def admin_alarm?(msg : Discord::Message)
    unless admin?(msg)
      reply(msg, "**ALARM**: This is an admin only command! You have been reported!")
      return true
    end
    false
  end

  private def private?(msg : Discord::Message)
    if private_channel?(msg)
      reply(msg, "**ERROR**: This command doesn't work in DMs")
      return true
    end
    false
  end

  private def check_and_notify_if_its_time_to_send_offsite
    wallet = @tip.node_balance(@config.confirmations)
    users = @tip.db_balance
    return if wallet == 0 || users == 0
    goal_percentage = BigDecimal.new(0.25)

    if (wallet / users) > 0.4
      return if @tip.pending_withdrawal_sum > @tip.node_balance
      missing = wallet - (users * goal_percentage)
      return if @tip.pending_coin_transactions
      current_percentage = ((wallet / users) * 100).round(4)
      embed = Discord::Embed.new(
        title: "It's time to send some coins off site",
        description: "Please remove **#{missing} #{@config.coinname_short}** from the bot and to your own wallet! `#{@config.prefix}offsite send`",
        colour: 0x0066ff_u32,
        timestamp: Time.now,
        fields: offsite_fields(users, wallet, current_percentage, goal_percentage * 100)
      )
      post_embed_to_webhook(embed, @config.admin_webhook)
      wait_for_balance_change(wallet, Compare::Smaller)
    end
  end

  private def check_and_notify_if_its_time_to_send_back_onsite
    wallet = @tip.node_balance(0)
    users = @tip.db_balance
    return if wallet == 0 || users == 0
    goal_percentage = BigDecimal.new(0.35)

    if (wallet / users) < 0.2 || @tip.pending_withdrawal_sum > @tip.node_balance
      missing = wallet - (users * goal_percentage)
      missing = missing - @tip.pending_withdrawal_sum if @tip.pending_withdrawal_sum > @tip.node_balance
      current_percentage = ((wallet / users) * 100).round(4)
      embed = Discord::Embed.new(
        title: "It's time to send some coins back to the bot",
        description: "Please deposit **#{missing} #{@config.coinname_short}** to the bot (your own `#{@config.prefix}offsite address`)",
        colour: 0xff0066_u32,
        timestamp: Time.now,
        fields: offsite_fields(users, wallet, current_percentage, goal_percentage * 100)
      )
      post_embed_to_webhook(embed, @config.admin_webhook)
      wait_for_balance_change(wallet, Compare::Bigger)
    end
  end

  private def offsite_fields(user_balance : BigDecimal, wallet_balance : BigDecimal, current_percentage, goal_percentage)
    [
      Discord::EmbedField.new(name: "Current Total User Balance", value: "#{user_balance} #{@config.coinname_short}"),
      Discord::EmbedField.new(name: "Current Wallet Balance", value: "#{wallet_balance} #{@config.coinname_short}"),
      Discord::EmbedField.new(name: "Current Percentage", value: "#{current_percentage}%"),
      Discord::EmbedField.new(name: "Goal Percentage", value: "#{goal_percentage}%"),
    ]
  end

  private def wait_for_balance_change(old_balance : BigDecimal, compare : Compare)
    time = Time.now

    new_balance = 0

    loop do
      return if (Time.now - time) > 10.minutes
      new_balance = @tip.node_balance(0)
      break if new_balance > old_balance if compare.bigger?
      break if new_balance < old_balance if compare.smaller?
      sleep 1
    end

    embed = Discord::Embed.new(
      title: "Success",
      colour: 0x00ff00_u32,
      timestamp: Time.now,
      fields: [Discord::EmbedField.new(name: "New wallet balance", value: "#{new_balance} #{@config.coinname_short}")]
    )
    post_embed_to_webhook(embed, @config.admin_webhook)
  end
end
