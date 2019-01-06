class DiscordBot
  def active(msg : Discord::Message)
    authors = active_users(msg)
    return reply(msg, "No active users!") if authors.nil? || authors.empty?

    singular = (authors.size == 1)
    reply(msg, "There #{singular ? "is" : "are"} **#{authors.size}** active user#{singular ? "" : "s"} ATM")
  end

  private def active_users(msg : Discord::Message)
    cache_users(msg) if Time.now - START_TIME < 10.minutes

    authors = @active_users_cache.resolve_to_id(msg.channel_id.to_u64)
    return unless authors
    authors.delete(msg.author.id.to_u64)
    authors - @config.ignored_users.to_a
  end

  private def cache_users(msg : Discord::Message)
    trigger_typing(msg)

    msgs = Array(Discord::Message).new
    channel = @bot.get_channel(msg.channel_id)
    last_id = channel.last_message_id
    before = Time.now - 10.minutes

    loop do
      new_msgs = @bot.get_channel_messages(msg.channel_id, before: last_id)
      if new_msgs.size < 50
        new_msgs.each { |x| msgs << x }
        break
      end
      last_id = new_msgs.last.id
      new_msgs.each { |x| msgs << x }
      break if new_msgs.last.timestamp < before
    end

    msgs.each do |x|
      next if x.author.bot
      next if x.content.match @prefix_regex
      @active_users_cache.add_if_youngest(x.channel_id.to_u64, x.author.id.to_u64, x.timestamp.to_utc)
    end
  end
end
