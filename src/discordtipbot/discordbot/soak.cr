class Soak
  include DiscordMiddleware::CachedRoutes
  include Utilities

  def initialize(@tip : TipBot, @config : Config, @cache : Discord::Cache, @presence_cache : PresenceCache)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!

    return unless guild_id = get_channel(client, msg.channel_id).guild_id
    guild_id = guild_id.to_u64

    unless ctx[ConfigMiddleware].get_config(msg, "soak")
      return client.create_message(msg.channel_id, "The owner of this server has disabled #{@config.prefix}soak. You can contact them and ask them to enable it as they should have received a DM with instructions")
    end

    cmd_usage = "#{@config.prefix}soak [amount]"

    # cmd[0]: amount
    cmd = ctx[Command].command
    return client.create_message(msg.channel_id, cmd_usage) unless cmd.size > 0

    amount = ctx[Amount].amount(msg, cmd[0])
    return client.create_message(msg.channel_id, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    min_soak = ctx[ConfigMiddleware].get_decimal_config(msg, "min_soak")
    min_soak_total = ctx[ConfigMiddleware].get_decimal_config(msg, "min_soak_total")
    return client.create_message(msg.channel_id, "**ERROR**: You have to soak at least **#{min_soak_total} #{@config.coinname_short}**") unless amount >= min_soak_total

    users = Array(UInt64).new
    last_id = 0_u64

    loop do
      new_users = client.list_guild_members(guild_id, after: last_id)
      break if new_users.size == 0
      last_id = new_users.last.user.id
      new_users.reject!(&.user.bot)
      new_users.each do |x|
        next unless @presence_cache.online?(x.user.id.to_u64)
        users << x.user.id.to_u64 unless x.user.id.to_u64 == msg.author.id.to_u64
        cache.cache(x.user)
      end
    end

    # TODO only soak people that can view the channel

    users = users - @config.ignored_users.to_a

    return client.create_message(msg.channel_id, "No one wants to get wet right now :sob:") unless users.size > 1

    if (users.size * min_soak) > amount
      # TODO enable user sampling as soon as crystal bug is fixed
      targets = users # .sample((amount / min_soak).to_i64)
    else
      targets = users
    end
    targets.reject! { |x| x == nil }

    case @tip.multi_transfer(from: msg.author.id.to_u64, users: targets, total: amount, memo: "soak")
    when "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: Insufficient balance")
    when false
      client.create_message(msg.channel_id, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      amount_each = BigDecimal.new(amount / targets.size).round(8)

      string = build_user_string(ctx[ConfigMiddleware].get_config(msg, "mention") || false, targets)

      client.create_message(msg.channel_id, "**#{msg.author.username}** soaked a total of **#{amount_each * targets.size} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
    end
    yield
  end
end
