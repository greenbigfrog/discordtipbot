class Withdraw
  include TB::Amount

  def initialize(@coin : TB::Data::Coin)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    if client.cache.try &.resolve_channel(msg.channel_id).type != Discord::ChannelType::DM
      client.create_message(msg.channel_id, "Withdrawing only works in DMs")
    end

    cmd_usage = "#{@coin.prefix}withdraw [address] [amount]"

    # cmd[0]: address, cmd[1]: amount
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "**ERROR**: Usage: #{cmd_usage}") if cmd.size < 2

    amount = parse_amount(@coin, :discord, msg.author.id.to_u64, cmd[1])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") if amount.nil?

    amount = amount - @coin.tx_fee if cmd[1] == "all"
    # return client.create_message(msg.channel_id, "**ERROR**: You have to withdraw at least #{@coin.min_withdraw}") if amount <= @coin.min_withdraw

    address = cmd[0]

    account = TB::Data::Account.read(:discord, msg.author.id.to_u64.to_i64)
    TB::Worker::WithdrawalJob.new(platform: "discord", destination: msg.channel_id.to_s, coin: @coin.id, user: account.id, address: address, amount: amount).enqueue
    yield
  end
end
