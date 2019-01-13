require "../data/coin"
require "../data/guild"

class NewGuildJob < Mosquito::QueuedJob
  params config_id : Int64, coin : Int32, guild_name : String, owner : Int64

  def perform
    string = <<-STR
    Thanks for adding me to your server `#{guild_name}`. By default, raining and soaking and other features are disabled by default.
    Configure the bot by visiting https://tipbot.info/config?coin=#{coin}&config=#{config_id}.
    If you have any further questions, please get in touch with us at #{SUPPORT}
    STR

    discord_token = Data::Coin.read_discord_token(coin)
    bot = Discord::Client.new(discord_token)

    begin
      bot.create_message(bot.create_dm(owner.to_u64).id, string)
    rescue ex : Discord::CodeException
      if ex.message.starts_with?("403")
        log "Unable to send new guild info to #{owner} for \"#{guild_name}\""
        return
      else
        raise ex
      end
    end
  end
end
