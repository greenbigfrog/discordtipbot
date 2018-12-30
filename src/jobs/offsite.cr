class CheckOffsiteStuff < Mosquito::QueuedJob
  include Utilities

  params coinname : String
  params prefix : String
  params admin_webhook : String

  def perform
    client = Discord::Client.new("")
    # tipbot = Tip
    check_and_notify_if_its_time_to_send_back_onsite(client, coinname, prefix, admin_webhook)
    check_and_notify_if_its_time_to_send_offsite(client, coinname, prefix, admin_webhook)
  end

  private def check_and_notify_if_its_time_to_send_offsite(client : Discord::Client, coinname : String, prefix : String, admin_webhook : String)
    wallet = @tip.node_balance(@config.confirmations)
    users = @tip.db_balance
    return if wallet == 0 || users == 0
    goal_percentage = BigDecimal.new(0.25)

    if (wallet / users) > 0.4
      return if @tip.pending_withdrawal_sum > @tip.node_balance
      missing = wallet - (users * goal_percentage)
      return if @tip.pending_coin_transactions
      current_percentage = ((wallet / users) * 100).round(4)
      embed = Discord::Embed.new(
        title: "It's time to send some coins off site",
        description: "Please remove **#{missing} #{@config.coinname_short}** from the bot and to your own wallet! `#{@config.prefix}offsite send`",
        colour: 0x0066ff_u32,
        timestamp: Time.now,
        fields: offsite_fields(users, wallet, current_percentage, goal_percentage * 100)
      )
      post_embed_to_webhook(embed, @config.admin_webhook)
      wait_for_balance_change(wallet, Compare::Smaller)
    end
  end

  private def check_and_notify_if_its_time_to_send_back_onsite(client : Discord::Client, coinname : String, prefix : String, admin_webhook : String)
    wallet = @tip.node_balance(0)
    users = @tip.db_balance
    return if wallet == 0 || users == 0
    goal_percentage = BigDecimal.new(0.35)

    if (wallet / users) < 0.2 || @tip.pending_withdrawal_sum > @tip.node_balance
      missing = wallet - (users * goal_percentage)
      missing = missing - @tip.pending_withdrawal_sum if @tip.pending_withdrawal_sum > @tip.node_balance
      current_percentage = ((wallet / users) * 100).round(4)
      embed = Discord::Embed.new(
        title: "It's time to send some coins back to the bot",
        description: "Please deposit **#{missing} #{@config.coinname_short}** to the bot (your own `#{@config.prefix}offsite address`)",
        colour: 0xff0066_u32,
        timestamp: Time.now,
        fields: offsite_fields(users, wallet, current_percentage, goal_percentage * 100)
      )
      post_embed_to_webhook(embed, @config.admin_webhook)
      wait_for_balance_change(wallet, Compare::Bigger)
    end
  end

  private def offsite_fields(user_balance : BigDecimal, wallet_balance : BigDecimal, current_percentage, goal_percentage)
    [
      Discord::EmbedField.new(name: "Current Total User Balance", value: "#{user_balance} #{@config.coinname_short}"),
      Discord::EmbedField.new(name: "Current Wallet Balance", value: "#{wallet_balance} #{@config.coinname_short}"),
      Discord::EmbedField.new(name: "Current Percentage", value: "#{current_percentage}%"),
      Discord::EmbedField.new(name: "Goal Percentage", value: "#{goal_percentage}%"),
    ]
  end

  private def wait_for_balance_change(old_balance : BigDecimal, compare : Compare)
    time = Time.now

    new_balance = 0

    loop do
      return if (Time.now - time) > 10.minutes
      new_balance = @tip.node_balance(0)
      break if new_balance > old_balance if compare.bigger?
      break if new_balance < old_balance if compare.smaller?
      sleep 1
    end

    embed = Discord::Embed.new(
      title: "Success",
      colour: 0x00ff00_u32,
      timestamp: Time.now,
      fields: [Discord::EmbedField.new(name: "New wallet balance", value: "#{new_balance} #{@config.coinname_short}")]
    )
    post_embed_to_webhook(embed, @config.admin_webhook)
  end
end
