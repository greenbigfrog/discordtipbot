class Tip
  include Utilities
  include Amount

  def initialize(@config : Config)
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

    amount = parse_amount(:discord, msg.author.id.to_u64, cmd[1])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    # TODO get rid of static coin
    res = Data::Account.transfer(amount: amount, coin: :doge, from: msg.author.id.to_u64.to_i64, to: id.to_u64.to_i64, platform: :discord, memo: :tip)
    if res.is_a?(Data::TransferError)
      return client.create_message(msg.channel_id, "**ERROR**: Insufficient Balance") if res.reason == "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: There was a problem trying to transfer funds#{res.reason ? " (#{res.reason})" : nil}. Please try again later. If the problem persists, please visit the support server at #{SUPPORT}")
    else
      client.create_message(msg.channel_id, "#{msg.author.username} tipped **#{amount} #{@config.coinname_short}** to **#{to.username}**")
    end

    yield
  end
end
