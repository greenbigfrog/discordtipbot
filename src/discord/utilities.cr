# Mixin for wrapping various common tasks
module Utilities
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
