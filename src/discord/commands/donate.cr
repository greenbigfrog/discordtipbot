require "../../jobs/webhook"

class Donate
  include Amount

  def initialize(@coin : Data::Coin, @webhook : Discord::Client)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    cmd_usage = "`#{@coin.prefix}donate [amount] [message]`"
    # cmd[0]: amount, cmd[1..size]: message
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size > 0

    amount = parse_amount(@coin, :discord, msg.author.id.to_u64, cmd[0])
    return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return client.create_message(msg.channel_id, "**ERROR**: Please donate at least #{@coin.default_min_tip} #{@coin.name_short} at once!") if amount < @coin.default_min_tip unless cmd[0] == "all"

    res = Data::Account.donate(amount: amount, coin: @coin, from: msg.author.id.to_u64.to_i64, platform: :discord)
    if res.is_a?(Data::Error)
      return client.create_message(msg.channel_id, "**ERROR**: Insufficient balance") if res.reason == "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: Please try again later")
    else
      client.create_message(msg.channel_id, "**#{msg.author.username} donated #{amount} #{@coin.name_short}!**")

      fields = [Discord::EmbedField.new(name: "Amount", value: "#{amount} #{@coin.name_short}"),
                Discord::EmbedField.new(name: "User", value: "#{msg.author.username}##{msg.author.discriminator}; <@#{msg.author.id.to_u64}>")]
      fields << Discord::EmbedField.new(name: "Message", value: cmd[1..cmd.size].join(" ")) if cmd[1]?

      embed = Discord::Embed.new(
        title: "Donation",
        thumbnail: Discord::EmbedThumbnail.new("https://cdn.discordapp.com/avatars/#{msg.author.id.to_u64}/#{msg.author.avatar}.png"),
        colour: 0x6600ff_u32,
        timestamp: Time.now,
        fields: fields
      )
      WebhookJob.new(webhook_type: "general", embed: embed.to_json).enqueue
    end
    yield
  end
end
