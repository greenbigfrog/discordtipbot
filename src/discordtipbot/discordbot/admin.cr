class Admin
  def initialize(@tip : TipBot, @config : Config)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    # cmd[0] = type, cmd[1] = user
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Current total user balances: **#{@tip.db_balance}**") if cmd.empty?

    case cmd[0]
    when "unclaimed"
      node = @tip.node_balance
      return if node.nil?
      unclaimed = node - (@tip.deposit_sum - @tip.withdrawal_sum)

      return client.create_message(msg.channel_id, "**NOTICE:** *This command doesn't make any sense in combination with offsite.*\n
      	Unclaimed coins: **#{unclaimed}** #{@config.coinname_short}")
    when .starts_with?("bal")
      return client.create_message(msg.channel_id, "**ERROR**: You forgot to supply an ID to check balance of") unless cmd[1]?
      bal = @tip.get_balance(cmd[1].to_u64)
      client.create_message(msg.channel_id, "**#{cmd[1]}**'s balance is: **#{bal}** #{@config.coinname_short}")
    end
    yield
  end
end
