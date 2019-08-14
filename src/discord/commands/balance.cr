class Balance
  def initialize(@coin : TB::Data::Coin)
  end

  def call(msg, ctx)
    ctx[Discord::Client].create_message(msg.channel_id, "#{msg.author.username} has a confirmed balance of **#{TB::Data::Account.read(:discord, msg.author.id.to_u64.to_i64).balance(@coin)} #{@coin.name_short}**")
    yield
  end
end
