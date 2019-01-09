# require "../../data/**"

class DiscordBot
  include Amount

  def rain(msg, ctx)
    unless ctx[ConfigMiddleware].get_config(msg, "rain")
      return reply(msg, "The owner of this server has disabled #{@config.prefix}rain. You can contact them and ask them to enable it as they should have received a DM with instructions")
    end

    cmd_usage = "#{@config.prefix}rain [amount]"

    # cmd[0]: amount
    cmd = ctx[Command].command

    return reply(msg, "Invalid Command usage: `#{cmd_usage}`") if cmd.empty?

    amount = parse_amount(:discord, msg.author.id.to_u64, cmd[0])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    min_rain = ctx[ConfigMiddleware].get_decimal_config(msg, "min_rain")
    min_rain_total = ctx[ConfigMiddleware].get_decimal_config(msg, "min_rain_total")
    return reply(msg, "**ERROR**: You have to rain at least #{min_rain_total} #{@config.coinname_short}") if amount < min_rain_total

    authors = active_users(msg)
    return reply(msg, "**ERROR**: There is nobody to rain on!") if authors.nil? || authors.empty?

    authors = authors.sample((amount / min_rain).to_i32) if (authors.size * min_rain) > amount

    # case @tip.multi_transfer(from: msg.author.id.to_u64, users: authors, total: amount, memo: "rain")
    # when "insufficient balance"
    #   reply(msg, "**ERROR**: Insufficient balance")
    # when false
    #   reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    # when true
    #   amount_each = BigDecimal.new(amount / authors.size).round(8)

    #   string = build_user_string(ctx[ConfigMiddleware].get_config(msg, "mention"), authors)

    #   reply(msg, "**#{msg.author.username}** rained a total of **#{amount_each * authors.size} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
    # end

    authors = authors.map { |x| x.to_i64 }

    # TODO get rid of static coin
    res = Data::Account.multi_transfer(total: amount, coin: :doge, from: msg.author.id.to_u64.to_i64, to: authors, platform: :discord, memo: :rain)
    if res.is_a?(Data::TransferError)
      return reply(msg, "**ERROR**: Insufficient balance") if res.reason == "insufficient balance"
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    else
      amount_each = BigDecimal.new(amount / authors.size).round(8)

      string = build_user_string(ctx[ConfigMiddleware].get_config(msg, "mention") || false, authors)

      channel_id = msg.channel_id

      reply = "**#{msg.author.username}** rained a total of **#{amount_each * authors.size} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}"
      if reply.size > 2000
        msgs = split(reply)
        msgs.each { |x| @bot.create_message(channel_id, x) }
      else
        reply(msg, reply)
      end
    end
  end
end
