class Withdraw
  include Amount

  def initialize(@tip : TipBot, @config : Config)
  end

  def call(msg, ctx)
    cmd_usage = "#{@config.prefix}withdraw [address] [amount]"
    client = ctx[Discord::Client]

    # cmd[0]: address, cmd[1]: amount
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "**ERROR**: Usage: #{cmd_usage}") if cmd.size < 2

    amount = parse_amount(:discord, msg.author.id.to_u64, cmd[1])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") if amount.nil?

    amount = amount - @config.txfee if cmd[1] == "all"
    return client.create_message(msg.channel_id, "**ERROR**: You have to withdraw at least #{@config.min_withdraw}") if amount <= @config.min_withdraw

    address = cmd[0]

    case @tip.withdraw(msg.author.id.to_u64, address, amount)
    when "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: You tried withdrawing too much. Also make sure you've got enough balance to cover the Transaction fee as well: #{@config.txfee} #{@config.coinname_short}")
    when "invalid address"
      client.create_message(msg.channel_id, "**ERROR**: Please specify a valid #{@config.coinname_full} address")
    when "internal address"
      client.create_message(msg.channel_id, "**ERROR**: Withdrawing to an internal address isn't permitted")
    when false
      client.create_message(msg.channel_id, "**ERROR**: There was a problem trying to withdraw. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      string = String.build do |io|
        io.puts "Pending withdrawal of **#{amount} #{@config.coinname_short}** to **#{address}**. *Processing shortly*" + Emoji::CURSOR
        io.puts "For security reasons large withdrawals have to be processed manually right now" if @tip.node_balance < amount
      end
      client.create_message(msg.channel_id, string)
    end
    yield
  end
end
