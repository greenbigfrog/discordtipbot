module ChatBot::Plugins::Ping
  extend self

  def bind(bot, prefix)
    bind_ping_command(bot, prefix)
    bind_ping(bot)
  end

  def bind_ping(bot)
    bot.on("PING") do |m|
      bot.pong(m.message)
    end
  end

  def bind_ping_command(bot, prefix)
    bot.on(PRIVWHISP, message: /^#{prefix}ping/, doc: {"ping", "respond with pong"}) do |msg|
      bot.reply(msg, "Pong. The current time is #{Time.now}")
    end
  end
end
