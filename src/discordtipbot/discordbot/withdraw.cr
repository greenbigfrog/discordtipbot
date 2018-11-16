class DiscordBot
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
end
