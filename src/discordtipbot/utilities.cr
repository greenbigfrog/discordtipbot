# Mixin for wrapping various common tasks
module Utilities
  # Utility for splitting a long string over 2000 characters into multiple messages
  def split(msg : String, message_break : String | Char = ' ', max_length : Int32 = 2000)
    msgs = Array(String).new

    # Break up the message into parts which are less than max_length characters each
    while (msg.size > max_length)
      # Calculate where to break the message and then record it
      first_break = msg[0, max_length].rindex(message_break) || max_length
      msgs << msg[0, first_break]

      # Find the index of the next space after the first_break
      next_break = msg.index(message_break, first_break).try { |v| v + 1 } || 0

      # If the next space is more than max_length away just record it as the break first_break.
      # FIXME: This will cause problems if a word is longer than max_length as it will shorten
      #          the word because it will not fit into a single message.
      next_break = first_break if next_break < first_break || next_break > first_break + max_length

      # Split the message at this next space to prepare it for the following iteration
      msg = msg[next_break, msg.size - next_break]
    end
    msgs << msg

    msgs
  end

  # Builds a comma seperated list of user names or mentions
  def build_user_string(mention : Bool, users : Set(Int64) | Array(Int64))
    string = String.build do |str|
      if mention
        users.each { |x| str << "<@#{x}>, " }
      else
        users.each { |x| str << "#{@cache.resolve_user(x.to_u64).username}, " }
      end
    end
    string.rchop(", ")
  end

  def bot?(user : Discord::User)
    bot_status = user.bot
    if bot_status
      return false if @config.whitelisted_bots.includes?(user.id)
    end
    bot_status
  end
end
