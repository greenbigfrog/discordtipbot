class DiscordBot
  def display_info_in_status
    @bot.on_ready(ErrorCatcher.new) do
      @log.info("#{@config.coinname_short}: #{@config.coinname_full} bot received READY")

      # Make use of the status to display info
      raven_spawn do
        sleep 10
        Discord.every(1.minutes) do
          update_game("#{@config.prefix}help | Serving #{@cache.users.size} users in #{@cache.guilds.size} guilds")
        end
      end
    end
  end

  private def update_game(name : String)
    @bot.status_update("online", Discord::GamePlaying.new(name, 0_i64))
  end
end
