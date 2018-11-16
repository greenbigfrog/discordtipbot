class DiscordBot
  def handle_guilds
    # Handle new guilds and owner notifying etc
    @streaming = false

    @bot.on_ready(ErrorCatcher.new) do |payload|
      # Only fire on first READY, or if ID cache was cleared
      next unless @unavailable_guilds.empty? && @available_guilds.empty?
      @streaming = true
      @unavailable_guilds.concat payload.guilds.map(&.id.to_u64)
    end

    @bot.on_guild_create(ErrorCatcher.new) do |payload|
      if @streaming
        @available_guilds.add payload.id.to_u64

        # Done streaming
        if @available_guilds == @unavailable_guilds
          # Process guilds at a rate
          @cache.guilds.each do |_id, guild|
            handle_new_guild(guild)
            sleep 0.1
          end

          # Any guild after this is new, not streaming anymore
          @streaming = false
          @log.debug("#{@config.coinname_short}: Done streaming/Cacheing guilds after #{Time.now - START_TIME}")
        end
      else
        # Brand new guild
        owner = @cache.resolve_user(payload.owner_id)
        embed = Discord::Embed.new(
          title: payload.name,
          thumbnail: Discord::EmbedThumbnail.new("https://cdn.discordapp.com/icons/#{payload.id}/#{payload.icon}.png"),
          colour: 0x00ff00_u32,
          timestamp: Time.now,
          fields: [
            Discord::EmbedField.new(name: "Owner", value: "#{owner.username}##{owner.discriminator}; <@#{owner.id}>"),
            Discord::EmbedField.new(name: "Membercount", value: payload.member_count.to_s),
          ]
        )
        post_embed_to_webhook(embed, @config.general_webhook) if handle_new_guild(payload)
      end
    end

    @bot.on_guild_create(ErrorCatcher.new) do |payload|
      @presence_cache.handle_presence(payload.presences)
    end
  end

  private def handle_new_guild(guild : Discord::Guild | Discord::Gateway::GuildCreatePayload)
    @tip.add_server(guild.id.to_u64)

    unless @tip.get_config(guild.id.to_u64, "contacted")
      string = "Hey! Someone just added me to your guild (#{guild.name}). By default, raining and soaking are disabled. Configure the bot using `#{@config.prefix}config [rain/soak/mention] [on/off]`. If you have any further questions, please join the support guild at http://tipbot.gbf.re"
      begin
        contact = @bot.create_message(@cache.resolve_dm_channel(guild.owner_id), string)
      rescue
        @log.error("#{@config.coinname_short}: Failed contacting #{guild.owner_id}")
      end
      @tip.update_config("contacted", true, guild.id.to_u64) if contact
      return true
    end
    false
  end
end
