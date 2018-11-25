class Donate
  def initialize(@tip : TipBot, @config : Config, @webhook : Discord::Client)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    cmd_usage = "`#{@config.prefix}donate [amount] [message]`"
    # cmd[0]: amount, cmd[1..size]: message
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size > 0

    amount = ctx[Amount].amount(msg, cmd[0])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return client.create_message(msg.channel_id, "**ERROR**: Please donate at least #{@config.min_tip} #{@config.coinname_short} at once!") if amount < @config.min_tip unless cmd[0] == "all"

    case @tip.transfer(from: msg.author.id.to_u64, to: 163607982473609216_u64, amount: amount, memo: "donation")
    when true
      client.create_message(msg.channel_id, "**#{msg.author.username} donated #{amount} #{@config.coinname_short}!**")

      fields = [Discord::EmbedField.new(name: "Amount", value: "#{amount} #{@config.coinname_short}"),
                Discord::EmbedField.new(name: "User", value: "#{msg.author.username}##{msg.author.discriminator}; <@#{msg.author.id.to_u64}>")]
      fields << Discord::EmbedField.new(name: "Message", value: cmd[1..cmd.size].join(" ")) if cmd[1]?

      embed = Discord::Embed.new(
        title: "Donation",
        thumbnail: Discord::EmbedThumbnail.new("https://cdn.discordapp.com/avatars/#{msg.author.id.to_u64}/#{msg.author.avatar}.png"),
        colour: 0x6600ff_u32,
        timestamp: Time.now,
        fields: fields
      )
      webhook = @config.general_webhook
      @webhook.execute_webhook(webhook.id, webhook.token, embeds: [embed])
    when "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: Insufficient balance")
    when "error"
      client.create_message(msg.channel_id, "**ERROR**: Please try again later")
    end
    yield
  end
end
