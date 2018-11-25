class Balance
  def initialize(@tip : TipBot, @config : Config)
  end

  def call(msg, ctx)
    ctx[Discord::Client].create_message(msg.channel_id, "#{msg.author.username} has a confirmed balance of **#{@tip.get_balance(msg.author.id.to_u64)} #{@config.coinname_short}**")
    yield
  end
end
