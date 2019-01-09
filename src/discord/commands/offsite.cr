class Offsite
  include Amount

  def initialize(@tip : TipBot, @config : Config)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    id = msg.author.id.to_u64

    cmd_usage = <<-DOC
    Usage: `#{@config.prefix}offsite [detail]`
    This command allows the storage of coins off site

    - `address` Send coins here to deposit them again
    - `send` Take coins out of the bot
    - `bal` Check your current balance for the offsite part
    DOC

    # cmd[0]: category
    cmd = ctx[Command].command

    if cmd.size < 1
      return client.create_message(msg.channel_id, cmd_usage)
    end

    case cmd[0]
    when "address"
      client.create_message(msg.channel_id, "Send coins here to put them back in the bot: **#{@tip.get_offsite_address(id)}**")
    when "send"
      # cmd[1]: address, cmd[2]: amount
      return client.create_message(msg.channel_id, "`#{@config.prefix}offsite send [address] [amount]`") unless cmd.size == 3

      amount = parse_amount(:discord, msg.author.id.to_u64, cmd[2])
      return client.create_message(msg.channel_id, "**ERROR**: Please specify a valid amount") if amount.nil?

      case @tip.offsite_withdrawal(id, amount, cmd[1])
      when "Invalid Address"
        client.create_message(msg.channel_id, "You specified an invalid address")
      when "Insufficient Funds"
        client.create_message(msg.channel_id, "Insufficient funds. Try a smaller amount")
      when true
        client.create_message(msg.channel_id, "Success!")
      else
        client.create_message(msg.channel_id, "Something went horribly wrong.")
      end
    when .starts_with?("bal")
      client.create_message(msg.channel_id, "Your current offsite balance is **#{@tip.get_offsite_balance(msg.author.id.to_u64)} #{@config.coinname_short}**\n*(This does not include unconfirmed transactions)*")
    when "info"
      fields = Array(Discord::EmbedField).new

      @tip.get_offsite_balances.each do |user|
        fields << Discord::EmbedField.new(name: ZWS, value: "<@#{user[:userid]}>: #{user[:balance]} #{@config.coinname_short}")
      end

      embed = Discord::Embed.new(
        title: "Info",
        colour: 0x9933ff_u32,
        timestamp: Time.now,
        fields: fields
      )
      client.create_message(msg.channel_id, "", embed)
    when "status"
      users = @tip.total_db_balance.round(2)
      wallet = @tip.node_balance.round(2)

      embed = Discord::Embed.new(
        title: "Status",
        colour: 0x00ccff_u32,
        timestamp: Time.now,
        fields: [
          Discord::EmbedField.new(name: "Wallet Balance", value: "#{wallet} #{@config.coinname_short}"),
          Discord::EmbedField.new(name: "Users Balance", value: "#{users} #{@config.coinname_short}"),
          Discord::EmbedField.new(name: "Ideal Wallet Balance Range", value: "#{users * BigDecimal.new(0.25)}..#{users * BigDecimal.new(0.35)}"),
          Discord::EmbedField.new(name: "Current Percentage", value: "#{((wallet / users) * 100).round(4)}%"),
        ]
      )
      client.create_message(msg.channel_id, "​", embed)
    else
      client.create_message(msg.channel_id, cmd_usage)
    end
    yield
  end
end
