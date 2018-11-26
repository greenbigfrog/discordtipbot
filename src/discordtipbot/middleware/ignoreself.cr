class IgnoreSelf
  @bot_id : Discord::Snowflake | Nil

  def initialize(@config : Config)
  end

  def call(msg, ctx)
    @bot_id = ctx[Discord::Client].cache.try &.resolve_current_user.id unless @bot_id
    user = msg.author
    unless user.id == @bot_id
      if user.bot
        return unless @config.whitelisted_bots.includes?(user.id)
      end
      yield
    end
  end
end
