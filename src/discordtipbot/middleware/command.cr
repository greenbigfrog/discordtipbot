class Command
  getter command : Array(String) = Array(String).new

  getter time : Time = Time.utc_now

  def initialize(@cmd : String | Array(String), @prefix_char : Char | String)
  end

  def call(payload, ctx)
    @time = Time.utc_now

    cache = ctx[Discord::Client].cache.not_nil!
    cmd = @cmd
    if cmd.is_a?(Array(String))
      cmd_regex = ""
      cmd.each { |x| cmd_regex += "#{x}|" }
      cmd_regex = cmd_regex.chomp('|')
    end

    if cache.resolve_channel(payload.channel_id).type == Discord::ChannelType::DM
      match = payload.content.match(/^(#{cmd_regex})(?<command>.*)/) if cmd_regex
      match = payload.content.match(/^(#{cmd})(?<command>.*)/) unless cmd.is_a?(Array(String))
    end

    unless match
      prefix = /^(#{Regex.escape(@prefix_char)}|<@!?#{cache.resolve_current_user.id}> +)(#{cmd_regex || cmd})(?<command>.*)/
      match = payload.content.match(prefix)
    end

    if match
      cmd = match.named_captures["command"].try &.split(' ', remove_empty: true)
      @command = cmd if cmd
      yield
    end
  end
end
