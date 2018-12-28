require "./utilities"
require "discordcr-middleware/middleware/cached_routes"
require "discordcr-middleware/middleware/permissions"
require "humanize_time"
require "bot_list"

USER_REGEX      = /<@!?(?<id>\d+)>/
START_TIME      = Time.now
TERMS           = "In no event shall this bot or its dev be responsible for any loss, theft or misdirection of funds."
ZWS             = "​" # There is a zero width space stored here
PREMIUM_CONFIG  = ["min_soak", "min_soak_total", "min_rain", "min_rain_total", "min_tip", "prefix"]
CONFIG_COLLUMNS = ["soak", "rain", "mention", "contacted"] + PREMIUM_CONFIG
SUPPORT         = "<https://contact.tipbot.info>"

class DiscordBot
  include Utilities

  @unavailable_guilds = Set(UInt64).new
  @available_guilds = Set(UInt64).new

  def initialize(@bot : Discord::Client, @cache : Discord::Cache, @config : Config, @log : Logger)
    @log.debug("#{@config.coinname_short}: starting bot: #{@config.coinname_full}")
    @tip = TipBot.new(@config, @log)
    @active_users_cache = ActivityCache.new(10.minutes)
    @presence_cache = PresenceCache.new
    @webhook = Discord::Client.new("")

    bot_id = @cache.resolve_current_user.id
    @prefix_regex = /^(?:#{'\\' + @config.prefix}|<@!?#{bot_id}> ?)(?<cmd>.*)/

    admin = DiscordMiddleware::Permissions.new(Discord::Permissions::Administrator, "**Permission Denied.** User must have %permissions%")
    rl = MW::RateLimiter.new
    error = ErrorCatcher.new
    config = ConfigMiddleware.new(@tip, @config)
    typing = TriggerTyping.new

    @bot.on_message_create(error, config, Command.new("ping"),
      rl, Ping.new)
    @bot.on_message_create(error, config, Command.new("withdraw"),
      rl, Withdraw.new(@tip, @config))
    @bot.on_message_create(error, config, Command.new(["deposit", "address"]),
      rl, Deposit.new(@tip, @config))
    @bot.on_message_create(error, config, Command.new("soak"),
      rl, NoPrivate.new, typing, Soak.new(@tip, @config, @cache, @presence_cache))
    @bot.on_message_create(error, config, Command.new("tip"),
      rl, NoPrivate.new, Tip.new(@tip, @config))
    @bot.on_message_create(error, config, Command.new("donate"),
      rl, Donate.new(@tip, @config, @webhook))
    @bot.on_message_create(error, config, Command.new(["balance", "bal"]),
      rl, Balance.new(@tip, @config))
    @bot.on_message_create(error, config, Command.new("\u{1f4be}"),
      rl, SystemStats.new)
    @bot.on_message_create(error, config, Command.new("offsite"),
      rl, OnlyPrivate.new, BotAdmin.new(@config), Offsite.new(@tip, @config))
    @bot.on_message_create(error, config, Command.new("admin"),
      rl, OnlyPrivate.new, BotAdmin.new(@config), Admin.new(@tip, @config))
    @bot.on_message_create(error, config, Command.new("config"),
      rl, NoPrivate.new, admin, ConfigCommand.new(@tip))
    @bot.on_message_create(error, config, Command.new("checkconfig"),
      rl, CheckConfig.new)
    @bot.on_message_create(error, config, Command.new("prefix"),
      rl, NoPrivate.new, admin, PremiumOnly.new, Prefix.new(@tip))
    @bot.on_message_create(error, config, Command.new("premium"),
      rl, BotAdmin.new(@config), PremiumCmd.new(@tip))
    @bot.on_message_create(error, config, Command.new("vote"),
      rl, Vote.new)
    @bot.on_message_create(error, config, Command.new("psql"),
      rl, BotAdmin.new(@config), PSQL.new(@tip.db, @config))
    @bot.on_message_create(error, config, Command.new("lucky"),
      rl, NoPrivate.new) { |msg, ctx| lucky(msg, ctx) }
    @bot.on_message_create(error, config, Command.new("rain"),
      rl, NoPrivate.new) { |msg, ctx| rain(msg, ctx) }
    @bot.on_message_create(error, config, Command.new("active"),
      rl, NoPrivate.new) { |msg, _| active(msg) }
    @bot.on_message_create(error, config, Command.new("statistics"), rl) do |msg, _|
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
    @bot.on_message_create(error, config,
      Command.new("exit"), rl, BotAdmin.new(@config)) do |msg, _|
      @log.warn("#{@config.coinname_short}: Shutdown requested by #{msg.author.id}")
      sleep 1
      exit
    end
    @bot.on_message_create(error, config,
      Command.new("stats"), rl) do |msg, _|
      guilds = @cache.guilds.size
      cached_users = @cache.users.size
      users = @cache.guilds.values.map { |x| x.member_count || 0 }.sum

      reply(msg, "The bot is in #{guilds} Guilds and sees #{users} users (of which #{cached_users} users are guaranteed unique)\n*(This is for all bots running in this process on this shard. TL;DR It's broken)*")
    end
    @bot.on_message_create(error, config,
      Command.new(["reload_conf", "load_conf"]), rl, BotAdmin.new(@config)) do |msg, ctx|
      # Currently the same coins have to be present in both the old and new config file

      # cmd [0] = path
      cmd = ctx[Command].command

      path = cmd[0]? || ARGV[0]

      begin
        Config.reload(path)
      rescue ex
        next reply(msg, "There was an issue loading config from `#{path}`\n```cr\n#{ex.inspect_with_backtrace}```")
      end
      @config = Config.current[@config.coinname_short]
      reply(msg, "Loaded config from #{path}")
    end
    @bot.on_message_create(error, config,
      Command.new("getinfo"), rl, BotAdmin.new(@config), OnlyPrivate.new) do |msg, _|
      info = @tip.get_info.as_h
      next unless info.is_a?(Hash(String, JSON::Any))

      embed = Array(Discord::EmbedField).new

      info.map do |key, val|
        embed << Discord::EmbedField.new(key, val.to_s, true) unless val.to_s.empty?
      end

      @bot.create_message(msg.channel_id, ZWS, Discord::Embed.new(fields: embed))
    end
    @bot.on_message_create(error, config,
      Command.new("help"), rl) do |msg, _|
      # TODO rewrite help command
      cmds = {"ping", "uptime", "tip", "soak", "rain", "active", "balance", "terms", "withdraw", "deposit", "support", "github", "invite"}
      string = String.build do |str|
        cmds.each { |x| str << "`" + @config.prefix + x + "`, " }
      end

      string = string.rchop(", ")

      reply(msg, "Currently the following commands are available: #{string}")
    end

    @bot.on_message_create(error) do |msg|
      content = msg.content

      if private_channel?(msg)
        content = @config.prefix + content unless content.match(@prefix_regex)
      end

      next unless match = content.match(@prefix_regex)
      next unless cmd = match.named_captures["cmd"]

      case cmd
      when .starts_with? "terms"
        reply(msg, TERMS)
      when .starts_with? "blocks"
        info = @tip.get_info
        next unless info.is_a?(JSON::Any)
        reply(msg, "Current Block Count (known to the node): **#{info["blocks"]}**")
      when .starts_with? "connections"
        info = @tip.get_info
        next unless info.is_a?(JSON::Any)
        reply(msg, "The node has **#{info["connections"]} Connections**")
      when .starts_with? "support"
        reply(msg, "For support please visit <http://tipbot.gbf.re>")
      when .starts_with? "github"
        reply(msg, "To contribute to the development of the tipbot visit <https://github.com/greenbigfrog/discordtipbot/>")
      when .starts_with? "invite"
        reply(msg, "You can add this bot to your own guild using following URL: <https://discordapp.com/oauth2/authorize?&client_id=#{@config.discord_client_id}&scope=bot>")
      when .starts_with? "uptime"
        reply(msg, "Bot has been running for #{Time.now - START_TIME}")
      end
    end

    @bot.on_ready(error) do
      @log.info("#{@config.coinname_short}: #{@config.coinname_full} bot received READY")

      # Make use of the status to display info
      raven_spawn do
        sleep 10
        Discord.every(1.minutes) do
          update_game("#{@config.prefix}help | Serving #{@cache.users.size} users in #{@cache.guilds.size} guilds")
        end
      end
    end

    @bot.on_ready(error) do
      # Disable stats posting with `export STATS=sth`
      next if ENV["STATS"]?
      sleep 1.minute
      bot_list = BotList::Client.new(@bot)
      bot_list.add_provider(BotList::DBotsDotOrgProvider.new(@config.dbl_stats)) if @config.dbl_stats
      bot_list.add_provider(BotList::DBotsDotGGProvider.new(@config.botsgg_token)) if @config.botsgg_token

      bot_list.update_every(30.minutes)
    end

    # Add user to active_users_cache on new message unless bot user
    @bot.on_message_create(error) do |msg|
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

    # Handle new guilds and owner notifying etc
    @streaming = false

    @bot.on_ready(error) do |payload|
      # Only fire on first READY, or if ID cache was cleared
      next unless @unavailable_guilds.empty? && @available_guilds.empty?
      @streaming = true
      @unavailable_guilds.concat payload.guilds.map(&.id.to_u64)
    end

    @bot.on_guild_create(error) do |payload|
      if @streaming
        @available_guilds.add payload.id.to_u64

        # Done streaming
        if @available_guilds == @unavailable_guilds
          @cache.guilds.each do |_id, guild|
            handle_new_guild(guild)
          end
          sleep 1

          # Any guild after this is new, not streaming anymore
          @streaming = false
          @log.debug("#{@config.coinname_short}: Done streaming/Cacheing guilds after #{Time.now - START_TIME}")
        end
      else
        # Brand new guild
        owner = @cache.resolve_user(payload.owner_id)
        embed = Discord::Embed.new(
          title: payload.name,
          thumbnail: Discord::EmbedThumbnail.new("https://cdn.discordapp.com/icons/#{payload.id}/#{payload.icon}.png"),
          colour: 0x00ff00_u32,
          timestamp: Time.now,
          fields: [
            Discord::EmbedField.new(name: "Owner", value: "#{owner.username}##{owner.discriminator}; <@#{owner.id}>"),
            Discord::EmbedField.new(name: "Membercount", value: payload.member_count.to_s),
          ]
        )
        post_embed_to_webhook(embed, @config.general_webhook) if handle_new_guild(payload)
      end
    end

    @bot.on_guild_create(error) do |payload|
      @presence_cache.handle_presence(payload.presences)
    end

    @bot.on_presence_update(error) do |presence|
      @presence_cache.handle_presence(presence)

      @cache.cache(Discord::User.new(presence.user)) if presence.user.full?
    end

    # receive wallet transactions and insert into coin_transactions
    raven_spawn do
      server = HTTP::Server.new do |context|
        next unless context.request.method == "POST"
        @tip.insert_tx(context.request.query_params["tx"])
      end
      server.bind_tcp("0.0.0.0", @config.walletnotify_port)
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
        users.each do |id, hash|
          begin
            @bot.create_message(@cache.resolve_dm_channel(id), "Your withdrawal just got processed #{Emoji::CHECK}\n*Transaction ID: #{hash}*")
          rescue
            @log.warn("#{@config.coinname_short}: Unable to send confirmation message to #{id}, while processing pending withdrawals")
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
        @tip.clear_expired_premium
      end
    end
  end

  private def handle_new_guild(guild : Discord::Guild | Discord::Gateway::GuildCreatePayload)
    id = guild.id.to_u64

    @tip.add_server(id)

    unless @tip.contacted(id)
      string = "Hey! Someone just added me to your guild (#{guild.name}). By default, raining and soaking are disabled. Configure the bot using `#{@config.prefix}config [rain/soak/mention] [on/off]`. If you have any further questions, please join the support guild at http://tipbot.gbf.re"
      begin
        contact = @bot.create_message(@cache.resolve_dm_channel(guild.owner_id), string)
      rescue
        @log.error("#{@config.coinname_short}: Failed contacting #{guild.owner_id}")
      end
      @tip.update_config("contacted", true, id) if contact
      return true
    end
    false
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

  private def update_game(name : String)
    @bot.status_update("online", Discord::GamePlaying.new(name, 0_i64))
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
