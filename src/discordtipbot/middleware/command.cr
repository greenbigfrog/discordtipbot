class Command
  include DiscordMiddleware::CachedRoutes

  getter name : String
  getter command : Array(String) = Array(String).new
  getter time : Time = Time.utc_now

  def initialize(@cmd : String | Array(String))
    cmd = @cmd
    @name = cmd.is_a?(String) ? cmd : cmd.first
  end

  def call(payload, ctx)
    @time = Time.utc_now
    cmd = @cmd
    if cmd.is_a?(Array(String))
      cmd_regex = ""
      cmd.each { |x| cmd_regex += "#{x}|" }
      cmd_regex = cmd_regex.chomp('|')
    end

    client = ctx[Discord::Client]

    if get_channel(client, payload.channel_id).type.dm?
      match = payload.content.match(/^(#{cmd_regex})(?<command>.*)/) if cmd_regex
      match = payload.content.match(/^(#{cmd})(?<command>.*)/) unless cmd.is_a?(Array(String))
    end

    unless match
      cache = client.cache.not_nil!
      prefix_char = ctx[ConfigMiddleware].get_prefix(payload)
      prefix = /^(#{Regex.escape(prefix_char)}|<@!?#{cache.resolve_current_user.id}> +)(#{cmd_regex || cmd})(?<command>.*)/
      match = payload.content.match(prefix)
    end

    if match
      cmd = match.named_captures["command"].try &.split(' ', remove_empty: true)
      @command = cmd if cmd
      yield
    end
  end
end
