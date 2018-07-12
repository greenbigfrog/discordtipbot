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

    @bot.on_message_create do |msg|
      next if msg.author.id.to_u64 == bot_id

      content = msg.content

      if private?(msg)
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

    @bot.on_ready do
      @log.info("#{@config.coinname_short}: #{@config.coinname_full} bot received READY")

      # Make use of the status to display info
      spawn do
        sleep 10
        Discord.every(1.minutes) do
          update_game("#{@config.prefix}help | Serving #{@cache.users.size} users in #{@cache.guilds.size} guilds")
        end
      end
    end

    # Add user to active_users_cache on new message unless bot user
    @bot.on_message_create do |msg|
      next if msg.content.match @prefix_regex
      @active_users_cache.touch(msg.channel_id.to_u64, msg.author.id.to_u64, msg.timestamp.to_utc) unless msg.author.bot
    end

    # Check if it's time to send off (or on) site
    spawn do
      Discord.every(10.seconds) do
        check_and_notify_if_its_time_to_send_back_onsite
        check_and_notify_if_its_time_to_send_offsite
      end
    end

    # Handle new guilds and owner notifying etc
    @streaming = false

    @bot.on_ready do |payload|
      # Only fire on first READY, or if ID cache was cleared
      next unless @unavailable_guilds.empty? && @available_guilds.empty?
      @streaming = true
      @unavailable_guilds.concat payload.guilds.map(&.id.to_u64)
    end

    @bot.on_guild_create do |payload|
      if @streaming
        @available_guilds.add payload.id.to_u64

        # Done streaming
        if @available_guilds == @unavailable_guilds
          # Process guilds at a rate
          @cache.guilds.each do |_id, guild|
            handle_new_guild(guild)
            sleep 0.1
          end

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

    @bot.on_guild_create do |payload|
      @presence_cache.handle_presence(payload.presences)
    end

    @bot.on_presence_update do |presence|
      @presence_cache.handle_presence(presence)

      @cache.cache(Discord::User.new(presence.user)) if presence.user.full?
    end

    # receive wallet transactions and insert into coin_transactions
    spawn do
      server = HTTP::Server.new do |context|
        next unless context.request.method == "POST"
        @tip.insert_tx(context.request.query_params["tx"])
      end
      server.bind_tcp(@config.walletnotify_port)
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

    # Check for pending withdrawals every X seconds
    spawn do
      Discord.every(30.seconds) do
        users = @tip.process_pending_withdrawals
        users.each do |x|
          begin
            @bot.create_message(@cache.resolve_dm_channel(x.to_u64), "Your withdrawal just got processed" + Emoji::Check)
          end
        end
      end
    end

    # warn users that the tipbot shouldn't be used as wallet if their balance exceeds @config.high_balance
    spawn do
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
    spawn do
      Discord.every(60.minutes) do
        @active_users_cache.prune
      end
    end
  end

  private def handle_new_guild(guild : Discord::Guild | Discord::Gateway::GuildCreatePayload)
    @tip.add_server(guild.id.to_u64)

    unless @tip.get_config(guild.id.to_u64, "contacted")
      string = "Hey! Someone just added me to your guild (#{guild.name}). By default, raining and soaking are disabled. Configure the bot using `#{@config.prefix}config [rain/soak/mention] [on/off]`. If you have any further questions, please join the support guild at http://tipbot.gbf.re"
      begin
        contact = @bot.create_message(@cache.resolve_dm_channel(guild.owner_id), string)
      rescue
        @log.error("#{@config.coinname_short}: Failed contacting #{guild.owner_id}")
      end
      @tip.update_config("contacted", true, guild.id.to_u64) if contact
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

  private def private?(msg : Discord::Message)
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
    return reply(msg, "**ALARM**: This is an admin only command!") unless @config.admins.includes?(msg.author.id.to_u64)
    return reply(msg, "**ERROR**: This command can only be used in DMs") unless private?(msg)

    info = @tip.get_info
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

    return reply(msg, "**ERROR**: As a design choice you aren't allowed to tip Bot accounts") if bot(to)

    return reply(msg, "**ERROR**: Are you trying to tip yourself!?") if id == msg.author.id.to_u64

    return reply(msg, "**ERROR**: The user you are trying to tip isn't able to receive tips") if @config.ignored_users.includes?(id)

    amount = amount(msg, cmd[2])
    return reply(msg, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to tip at least #{@config.min_tip} #{@config.coinname_short}") if amount < @config.min_tip

    case @tip.transfer(from: msg.author.id.to_u64, to: id, amount: amount, memo: "tip")
    when true
      reply(msg, "#{msg.author.username} tipped **#{amount} #{@config.coinname_short}** to **#{to.username}**")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when "error"
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    end
  end

  # Basically just tip greenbigfrog internally
  def donate(msg : Discord::Message, cmd_string : String)
    cmd_usage = "`#{@config.prefix}donate [amount] [message]`"
    # cmd[0]: trigger, cmd[1]: amount, cmd[2..size]: message
    cmd = cmd_string.split(" ")

    return reply(msg, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: Please donate at least #{@config.min_tip} #{@config.coinname_short} at once!") if amount < @config.min_tip unless cmd[1] == "all"

    case @tip.transfer(from: msg.author.id.to_u64, to: 163607982473609216_u64, amount: amount, memo: "donation")
    when true
      reply(msg, "**#{msg.author.username} donated #{amount} #{@config.coinname_short}!**")

      fields = [Discord::EmbedField.new(name: "Amount", value: "#{amount} #{@config.coinname_short}"),
                Discord::EmbedField.new(name: "User", value: "#{msg.author.username}##{msg.author.discriminator}; <@#{msg.author.id.to_u64}>")]
      fields << Discord::EmbedField.new(name: "Message", value: cmd[2..cmd.size].join(" ")) if cmd[2]?

      embed = Discord::Embed.new(
        title: "Donation",
        thumbnail: Discord::EmbedThumbnail.new("https://cdn.discordapp.com/avatars/#{msg.author.id.to_u64}/#{msg.author.avatar}.png"),
        colour: 0x6600ff_u32,
        timestamp: Time.now,
        fields: fields
      )
      post_embed_to_webhook(embed, @config.general_webhook)
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when "error"
      reply(msg, "**ERROR**: Please try again later")
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

    amount = amount - @config.txfee if cmd[2] == "all"

    return reply(msg, "**ERROR**: You have to withdraw at least #{@config.min_withdraw}") if amount <= @config.min_withdraw

    address = cmd[1]

    case @tip.withdraw(msg.author.id.to_u64, address, amount)
    when "insufficient balance"
      reply(msg, "**ERROR**: You tried withdrawing too much. Also make sure you've got enough balance to cover the Transaction fee as well: #{@config.txfee} #{@config.coinname_short}")
    when "invalid address"
      reply(msg, "**ERROR**: Please specify a valid #{@config.coinname_full} address")
    when "internal address"
      reply(msg, "**ERROR**: Withdrawing to an internal address isn't permitted")
    when false
      reply(msg, "**ERROR**: There was a problem trying to withdraw. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      string = String.build do |io|
        io.puts "Pending withdrawal of **#{amount} #{@config.coinname_short}** to **#{address}**. *Processing shortly*" + Emoji::Cursor
        io.puts "For security reasons large withdrawals have to be processed manually right now" if @tip.node_balance < amount
      end
      reply(msg, string)
    end
  end

  # return deposit address
  def deposit(msg : Discord::Message)
    notif = reply(msg, "Sent deposit address in a DM") unless private?(msg)
    begin
      address = @tip.get_address(msg.author.id.to_u64)
      embed = Discord::Embed.new(
        footer: Discord::EmbedFooter.new("I love you! ❤"),
        image: Discord::EmbedImage.new("https://chart.googleapis.com/chart?cht=qr&chs=300x300&chld=L%7C1&chl=#{@config.uri_scheme}:#{address}")
      )
      @bot.create_message(@cache.resolve_dm_channel(msg.author.id.to_u64), "Your deposit address is: **#{address}**\nPlease keep in mind, that this address is for **one time use only**. After every deposit your address will reset! Don't use this address to receive from faucets, pools, etc.\nDeposits take **#{@config.confirmations} confirmations** to get credited!\n*#{TERMS}*", embed)
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
        next unless @presence_cache.online?(x.user.id.to_u64)
        users << x.user.id.to_u64 unless x.user.id.to_u64 == msg.author.id.to_u64
        @cache.cache(x.user)
      end
    end

    # TODO only soak people that can view the channel

    users = users - @config.ignored_users.to_a

    return reply(msg, "No one wants to get wet right now :sob:") unless users.size > 1

    if (users.size * @config.min_soak) > @config.min_soak_total
      targets = users.sample((amount / @config.min_soak).to_i32)
    else
      targets = users
    end
    targets.reject! { |x| x == nil }

    case @tip.multi_transfer(from: msg.author.id.to_u64, users: targets, total: amount, memo: "soak")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when false
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      amount_each = BigDecimal.new(amount / targets.size).round(8)

      string = build_user_string(get_config_mention(msg), targets)

      reply(msg, "**#{msg.author.username}** soaked a total of **#{amount_each * targets.size} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
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

    case @tip.multi_transfer(from: msg.author.id.to_u64, users: authors, total: amount, memo: "rain")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when false
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      amount_each = BigDecimal.new(amount / authors.size).round(8)

      string = build_user_string(get_config_mention(msg), authors)

      reply(msg, "**#{msg.author.username}** rained a total of **#{amount_each * authors.size} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
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

    case @tip.transfer(from: msg.author.id.to_u64, to: user, amount: amount, memo: "lucky")
    when true
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
    reply(msg, "#{msg.author.username} has a confirmed balance of **#{@tip.get_balance(msg.author.id.to_u64)} #{@config.coinname_short}**")
  end

  # Config command (available to admins and respective server owner)
  def config(msg : Discord::Message, cmd_string : String)
    reply(msg, "Since it's hard to identify which server you want to configure if you run these commands in DMs, please rather use them in the respective server") if private?(msg)

    return reply(msg, "**ALARM**: This command can only be used by the guild owner") unless @cache.resolve_guild(guild_id(msg)).owner_id == msg.author.id || @config.admins.includes?(msg.author.id.to_u64)

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
    return unless info.is_a?(Hash(String, JSON::Any))

    reply(msg, "Current Block Count (known to the node): **#{info["blocks"]}**")
  end

  def connections(msg : Discord::Message)
    info = @tip.get_info
    return unless info.is_a?(Hash(String, JSON::Any))

    reply(msg, "The node has **#{info["connections"]} Connections**")
  end

  def admin(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ALARM**: This is an admin only command! You have been reported!") unless @config.admins.includes?(msg.author.id.to_u64)
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
    return reply(msg, "**ALARM**: This is an admin only command! You have been reported!") unless @config.admins.includes?(id)

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

  def offsite(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: This command only works in DMs") unless private?(msg) unless msg.channel_id.to_u64 == 421752342262579201

    id = msg.author.id.to_u64
    return reply(msg, "**ALARM**: This is an admin only command!") unless @config.admins.includes?(id)

    cmd_usage = String.build do |io|
      io.puts "This command allows the storage of coins off site"
      io.puts
      io.puts "- `address` Send coins here to deposit them again"
      io.puts "- `send` Take coins out of the bot"
      io.puts "- `bal` Check your current balance for the offsite part"
    end

    # cmd[0] = "offsite", cmd[1]: category
    cmd = cmd_string.split(" ")

    if cmd.size < 2
      return reply(msg, cmd_usage)
    end

    case cmd[1]
    when "address"
      reply(msg, "Send coins here to put them back in the bot: **#{@tip.get_offsite_address(id)}**")
    when "send"
      # cmd[2]: address, cmd[3]: amount
      return reply(msg, "`#{@config.prefix}offsite send [address] [amount]`") unless cmd.size == 4

      amount = amount(msg, cmd[3])
      return reply(msg, "**ERROR**: Please specify a valid amount") if amount.nil?

      case @tip.offsite_withdrawal(id, amount, cmd[2])
      when "Invalid Address"
        reply(msg, "You specified an invalid address")
      when "Insufficient Funds"
        reply(msg, "Insufficient funds. Try a smaller amount")
      when true
        reply(msg, "Success!")
      else
        reply(msg, "Something went horribly wrong.")
      end
    when .starts_with?("bal")
      reply(msg, "Your current offsite balance is **#{@tip.get_offsite_balance(msg.author.id.to_u64)} #{@config.coinname_short}**\n*(This does not include unconfirmed transactions)*")
    when "info"
      fields = Array(Discord::EmbedField).new

      @tip.get_offsite_balances.each do |user|
        fields << Discord::EmbedField.new(name: ZWS, value: "<@#{user[:userid]}>: #{user[:balance]} #{@config.coinname_short}")
      end

      embed = Discord::Embed.new(
        title: "Info",
        colour: 0x9933ff_u32,
        timestamp: Time.now,
        fields: fields
      )
      @bot.create_message(msg.channel_id, "", embed)
    when "status"
      users = @tip.total_db_balance.round(2)
      wallet = @tip.node_balance.round(2)

      embed = Discord::Embed.new(
        title: "Status",
        colour: 0x00ccff_u32,
        timestamp: Time.now,
        fields: [
          Discord::EmbedField.new(name: "Wallet Balance", value: "#{wallet} #{@config.coinname_short}"),
          Discord::EmbedField.new(name: "Users Balance", value: "#{users} #{@config.coinname_short}"),
          Discord::EmbedField.new(name: "Ideal Wallet Balance Range", value: "#{users * BigDecimal.new(0.25)}..#{users * BigDecimal.new(0.35)}"),
          Discord::EmbedField.new(name: "Current Percentage", value: "#{((wallet / users) * 100).round(4)}%"),
        ]
      )
      @bot.create_message(msg.channel_id, "​", embed)
    else
      reply(msg, cmd_usage)
    end
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

  private def bot(user : Discord::User)
    bot_status = user.bot
    if bot_status
      return false if @config.whitelisted_bots.includes?(user.id)
    end
    bot_status
  end

  private def check_and_notify_if_its_time_to_send_offsite
    wallet = @tip.node_balance(@config.confirmations)
    users = @tip.db_balance
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
