class Tip
  include Utilities

  def initialize(@tip : TipBot, @config : Config)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client].not_nil!

    cmd_usage = "`#{@config.prefix}tip [@user] [amount]`"
    # cmd[0]: user, cmd[1]: amount
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size >= 2

    match = USER_REGEX.match(cmd[0])
    id = match["id"].try &.to_u64 if match

    err = "**ERROR**: Please specify the user you want to tip! #{cmd_usage}"
    return client.create_message(msg.channel_id, err) unless id
    begin
      to = client.cache.try &.resolve_user(id)
    rescue
      return client.create_message(msg.channel_id, err)
    end

    return unless to

    return client.create_message(msg.channel_id, "**ERROR**: As a design choice you aren't allowed to tip Bot accounts") if bot?(to)

    return client.create_message(msg.channel_id, "**ERROR**: Are you trying to tip yourself!?") if id == msg.author.id.to_u64

    return client.create_message(msg.channel_id, "**ERROR**: The user you are trying to tip isn't able to receive tips") if @config.ignored_users.includes?(id)

    amount = ctx[Amount].amount(msg, cmd[1])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    min_tip = ctx[ConfigMiddleware].get_decimal_config(msg, "min_tip")
    return client.create_message(msg.channel_id, "**ERROR**: You have to tip at least #{min_tip} #{@config.coinname_short}") if amount < min_tip

    case @tip.transfer(from: msg.author.id.to_u64, to: id, amount: amount, memo: "tip")
    when true
      client.create_message(msg.channel_id, "#{msg.author.username} tipped **#{amount} #{@config.coinname_short}** to **#{to.username}**")
    when "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: Insufficient balance")
    when "error"
      client.create_message(msg.channel_id, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    end
    yield
  end
end
