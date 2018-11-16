class DiscordBot
  def offsite(msg : Discord::Message, cmd_string : String)
    return unless private_channel?(msg) unless msg.channel_id.to_u64 == 421752342262579201

    id = msg.author.id.to_u64
    return if admin_alarm?(msg)

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
end
