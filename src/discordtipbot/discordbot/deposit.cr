class Deposit
  def initialize(@tip : TipBot, @config : Config)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache
    return unless cache
    unless cache.resolve_channel(msg.channel_id).try &.type == Discord::ChannelType::DM
      notif = client.create_message(msg.channel_id, "Sent deposit address in a DM")
    end
    begin
      address = @tip.get_address(msg.author.id.to_u64)
      embed = Discord::Embed.new(
        footer: Discord::EmbedFooter.new("I love you! ❤"),
        image: Discord::EmbedImage.new("https://chart.googleapis.com/chart?cht=qr&chs=300x300&chld=L%7C1&chl=#{@config.uri_scheme}:#{address}")
      )
      client.create_message(cache.resolve_dm_channel(msg.author.id.to_u64), "Your deposit address is: **#{address}**\nPlease keep in mind, that this address is for **one time use only**. After every deposit your address will reset! Don't use this address to receive from faucets, pools, etc.\nDeposits take **#{@config.confirmations} confirmations** to get credited!\n*#{TERMS}*", embed)
    rescue
      client.create_message(msg.channel_id, "**ERROR**: Could not send deposit details in a DM. Enable `allow direct messages from server members` in your privacy settings")
      return unless notif.is_a?(Discord::Message)
      client.delete_message(notif.channel_id, notif.id)
    end
    yield
  end
end
