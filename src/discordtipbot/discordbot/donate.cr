class DiscordBot
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
end
