class BotAdmin
  def initialize(@config : Config)
  end

  def call(msg, ctx)
    if @config.admins.includes?(msg.author.id.to_u64)
      yield
    else
      ctx[Discord::Client].create_message(msg.channel_id, "**ALARM**: This is an admin only command! You have been reported!")
    end
  end
end
