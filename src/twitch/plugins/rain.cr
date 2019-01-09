module ChatBot::Plugins::Rain
  extend self
  include Amount
  include StringSplit

  def bind(bot, config, twitch, active_users_cache)
    bot.on do |msg|
      raise NO_USER_ID unless id = msg.user_id
      raise NO_ROOM_ID unless room = msg.room_id
      active_users_cache.touch(room, id)
    end

    bot.on(message: /^#{config.prefix}active/, doc: {"active", "Displays the amount of currently active users"}) do |msg|
      raise NO_USER_ID unless id = msg.user_id
      raise NO_ROOM_ID unless room = msg.room_id

      authors = active_users_cache.resolve_to_id(room)
      authors.try &.delete(id)

      next bot.reply(msg, "There are no active users right now!") if authors.nil? || authors.empty?

      # TODO differ if one or multiple active users
      bot.reply(msg, "There are currently #{authors.size} active users")
    end

    bot.on(message: /^#{config.prefix}rain/, doc: {"rain", "rain [amount]. Splits the amount equally between all active users"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)
      raise NO_USER_ID unless from = msg.user_id
      raise NO_ROOM_ID unless room = msg.room_id

      cmd_usage = "#{config.prefix}rain [amount]"

      # cmd[0]: trigger, cmd[1]: amount
      cmd = msg.message.try &.split(" ")
      next bot.reply(msg, ChatBot.mention(name, "Please try again! #{cmd_usage}")) unless cmd && cmd.size > 1

      authors = active_users_cache.resolve_to_id(room)
      authors.try &.delete(from)

      next bot.reply(msg, "You can't rain right now, because there's no one to make wet!") if authors.nil? || authors.empty?

      amount = parse_amount(:twitch, from, cmd[1])
      next bot.reply(msg, ChatBot.mention(name, "Please specify a valid amount")) unless amount
      next bot.reply(msg, ChatBot.mention(name, "You have to tip at least #{config.min_tip} #{config.short}")) unless amount >= config.min_tip

      # TODO get rid of static coin
      res = Data::Account.multi_transfer(total: amount, coin: :doge, from: from, to: authors, platform: :twitch, memo: :rain)
      if res.is_a?(Data::TransferError)
        next bot.reply(msg, ChatBot.mention(name, "Insufficient balance")) if res.reason == "insufficient balance"
        bot.reply(msg, ChatBot.mention(name, "There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{config.prefix}support"))
      else
        amount_each = BigDecimal.new(amount / authors.size).round(8)

        string = String.build do |io|
          authors.each do |id|
            user = twitch.user(id)
            io << '@'
            io << (user.display_name || user.login)
            io << ", "
          end
        end
        string = string.rchop(", ")

        reply = "rained a total of #{amount_each * authors.size} #{config.coinname_short} (#{amount_each} #{config.coinname_short} each) onto #{string}"
        if reply.bytesize > 510 # compare to 512 Bytes
          msgs = split(reply)
          msgs.each { |x| bot.reply(msg, ChatBot.mention(name, x)) }
        else
          bot.reply(msg, ChatBot.mention(name, reply))
        end
      end
    end
  end
end
