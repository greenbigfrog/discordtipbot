class SystemStats
  def call(payload, ctx)
    stats = GC.stats
    stats_string = String.build do |string|
      string << "```cr\n"
      string << "heap_size:      " << (stats.heap_size / 1024.0 / 1024.0).round(2) << "MB\n"
      string << "free_bytes:     " << (stats.free_bytes / 1024.0 / 1024.0).round(2) << "MB\n"
      string << "unmapped_bytes: " << (stats.unmapped_bytes / 1024.0 / 1024.0).round(2) << "MB\n"
      string << "bytes_since_gc: " << (stats.bytes_since_gc / 1024.0 / 1024.0).round(2) << "MB\n"
      string << "total_bytes:    " << (stats.total_bytes / 1024.0 / 1024.0).round(2) << "MB\n"
      string << "```"
    end
    stats_field = Discord::EmbedField.new(
      "gc stats",
      stats_string,
      true)

    cache = ctx[Discord::Client].cache.not_nil!

    total_members = cache.members.map { |_guild, members| members.size }.sum
    cache_string = String.build do |string|
      string << "```cr\n"
      string << "users:       " << cache.users.size << "\n"
      string << "channels:    " << cache.channels.size << "\n"
      string << "guilds:      " << cache.guilds.size << "\n"
      string << "members:     " << total_members << "\n"
      string << "roles:       " << cache.roles.size << "\n"
      string << "dm_channels: " << cache.dm_channels.size << "\n"
      string << "```"
    end
    cache_field = Discord::EmbedField.new(
      "cache totals",
      cache_string,
      true)

    ctx[Discord::Client].create_message(
      payload.channel_id,
      "**bot statistics**",
      Discord::Embed.new(
        description: "**uptime:** `#{Time.now - START_TIME}`",
        fields: [stats_field, cache_field]))

    yield
  end
end
