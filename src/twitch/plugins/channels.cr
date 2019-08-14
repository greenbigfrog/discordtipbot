module ChatBot::Plugins::Channels
  extend self

  def bind(bot, prefix, twitch, coin)
    bind_join(bot, prefix, twitch, coin)
    bind_part(bot, prefix, coin)
  end

  def bind_join(bot, prefix, twitch, coin)
    bot.on(PRIVWHISP, message: /^#{prefix}join/, doc: {"join", "join [#channel] a given channel"}) do |msg|
      channel = msg.message.try &.split(" ").try &.[1]?

      next bot.reply(msg, "Please specify a channel to join") unless channel
      next bot.reply(msg, "Please specify a actually valid channel") unless twitch.user?(channel)

      next bot.reply(msg, "Only can join channel if Owner of Channel") unless ChatBot.extract_nick(msg.source) == channel

      bot.join(Crirc::Protocol::Chan.new("##{channel}"))

      TB::Data::TwitchChannel.create(channel, coin)

      bot.reply(msg, "Bot joined #{channel}")

      # TODO add link to some wiki page to reply
    end
  end

  def bind_part(bot, prefix, coin)
    bot.on("PRIVMSG", message: /^#{prefix}part/, doc: {"part", "part [channel]. Leave a given channel"}) do |msg|
      author = ChatBot.extract_nick(msg.source)
      next bot.reply(msg, "Only can leave channel if Owner of Channel") unless "##{author}" == msg.arguments

      bot.reply(msg, "Leaving channel!")
      bot.part(Crirc::Protocol::Chan.new("#{msg.arguments}"), "not sure if this works")

      TB::Data::TwitchChannel.delete(author, coin)
    end
  end
end
