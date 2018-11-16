class DiscordBot
  # return deposit address
  def deposit(msg : Discord::Message)
    notif = reply(msg, "Sent deposit address in a DM") unless private_channel?(msg)
    begin
      address = @tip.get_address(msg.author.id.to_u64)
      embed = Discord::Embed.new(
        footer: Discord::EmbedFooter.new("I love you! ❤"),
        image: Discord::EmbedImage.new("https://chart.googleapis.com/chart?cht=qr&chs=300x300&chld=L%7C1&chl=#{@config.uri_scheme}:#{address}")
      )
      @bot.create_message(@cache.resolve_dm_channel(msg.author.id.to_u64), "Your deposit address is: **#{address}**\nPlease keep in mind, that this address is for **one time use only**. After every deposit your address will reset! Don't use this address to receive from faucets, pools, etc.\nDeposits take **#{@config.confirmations} confirmations** to get credited!\n*#{TERMS}*", embed)
    rescue
      reply(msg, "**ERROR**: Could not send deposit details in a DM. Enable `allow direct messages from server members` in your privacy settings")
      return unless notif.is_a?(Discord::Message)
      @bot.delete_message(notif.channel_id, notif.id)
    end
  end
end
