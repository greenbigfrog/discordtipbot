class PSQL
  def initialize(@db : DB::Database, @config : Config)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    cmd = ctx[Command].command.join(' ')
    return client.create_message(msg.channel_id, "No SQL query specified") if cmd.empty?
    return client.create_message(msg.channel_id, "DROPing isn't allowed") if cmd.match /drop/i

    # args = ["-d#{@config.coinname_full.downcase}"]
    # args.push "-c#{cmd}"
    # str = Process.new("psql", args: args, input: Process::Redirect::Inherit,
    #   output: Process::Redirect::Pipe, error: Process::Redirect::Inherit).output.gets_to_end

    # return client.create_message(msg.channel_id,
    #   "**Output too big. Sending first 1.5k characes.**\n```#{str[0..1500]}```") if str.size > 2000

    # client.create_message(msg.channel_id, "```#{str}```")
    client.create_message(msg.channel_id, "This command has been disabled for now")
    yield
  end
end
