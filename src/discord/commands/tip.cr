class Tip
  include Utilities
  include TB::Amount

  def initialize(@coin : TB::Data::Coin)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client].not_nil!

    cmd_usage = "`#{@coin.prefix}tip [@user] [amount]`"
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

    return client.create_message(msg.channel_id, "**ERROR**: The user you are trying to tip isn't able to receive tips") if @coin.ignored_users.includes?(id)

    amount = parse_amount(@coin, :discord, msg.author.id.to_u64, cmd[1])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    min_tip = ctx[ConfigMiddleware].get_decimal_config(msg, "min_tip")
    return client.create_message(msg.channel_id, "**ERROR**: You must tip at least #{min_tip} #{@coin.name_short}!") if amount < min_tip

    # TODO get rid of static coin
    res = TB::Data::Account.transfer(amount: amount, coin: @coin, from: msg.author.id.to_u64.to_i64, to: id.to_u64.to_i64, platform: :discord, memo: :tip)
    if res.is_a?(TB::Data::Error)
      return client.create_message(msg.channel_id, "**ERROR**: Insufficient Balance") if res.reason == "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: There was a problem trying to transfer funds#{res.reason ? " (#{res.reason})" : nil}. Please try again later. If the problem persists, please visit the support server at #{TB::SUPPORT}")
    else
      client.create_message(msg.channel_id, "#{msg.author.username} tipped **#{amount} #{@coin.name_short}** to **#{to.username}**")
    end

    yield
  end
end
