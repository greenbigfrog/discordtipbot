class Balance
  def initialize(@config : Config)
  end

  def call(msg, ctx)
    ctx[Discord::Client].create_message(msg.channel_id, "#{msg.author.username} has a confirmed balance of **#{Data::Account.read(:discord, msg.author.id.to_u64.to_i64).balance(:doge)} #{@config.coinname_short}**")
    yield
  end
end
