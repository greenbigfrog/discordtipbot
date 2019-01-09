module ChatBot::Plugins::Whisper
  extend self

  def bind(bot)
    bind_whisper(bot)
  end

  def bind_whisper(bot)
    bot.on("WHISPER") do |msg|
      bot.reply(msg, "Currently the bot isn't fully functional in Whispers. If the bot shouldn't respond this is intentional. Please just head to any other channel the bot is in and use it there.")
    end
  end
end
