class Deposit
  include DiscordMiddleware::CachedRoutes

  def initialize(@coin : TB::Data::Coin)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!

    unless get_channel(client, msg.channel_id).type.dm?
      notif = client.create_message(msg.channel_id, "Sent deposit address in a DM")
    end

    address = TB::Data::DepositAddress.read_or_create(@coin, TB::Data::Account.read(:discord, msg.author.id.to_u64.to_i64))
    if address.is_a?(TB::Data::Error)
      return client.create_message(msg.channel_id, "Something went wrong. Please try again later, or request help at #{TB::SUPPORT}")
    end

    begin
      embed = Discord::Embed.new(
        image: Discord::EmbedImage.new("https://tipbot.info/qr/#{@coin.uri_scheme}:#{address}")
      )
      client.create_message(cache.resolve_dm_channel(msg.author.id.to_u64), "Your deposit address is: **#{address}**\nPlease keep in mind, that this address is for **one time use only**. After every deposit your address will reset! Don't use this address to receive from faucets, pools, etc.\nDeposits take **#{@coin.confirmations} confirmations** to get credited!\n*#{TB::TERMS}*", embed)
    rescue
      client.create_message(msg.channel_id, "**ERROR**: Could not send deposit details in a DM. Enable `allow direct messages from server members` in your privacy settings")
      return unless notif.is_a?(Discord::Message)
      client.delete_message(notif.channel_id, notif.id)
    end
    yield
  end
end
