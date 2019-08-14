require "tb"

class ProcessWithdrawalsJob < Mosquito::PeriodicJob
  run_every 1.minute

  def perform
    input = Hash(Int32, Array(Tuple(Int32, String, BigDecimal, Int64))).new
    TB::Data::Withdrawal.read_pending_withdrawals.each do |x|
      input[x.coin] = Array(Tuple(Int32, String, BigDecimal, Int64)).new unless input[x.coin]?
      input[x.coin] << {x.id, x.address, x.amount, x.transaction}
    end

    return log "No withdrawals to process. Succeeding early" if input.empty?

    log "These transactions/withdrawals are pending: #{input}"

    TB::Data::Coin.read.each do |coin|
      rpc = TB::CoinApi.new(coin, Logger.new(STDOUT), backoff: false)
      final = Hash(String, BigDecimal).new

      transactions = input[coin.id]
      next if transactions.empty?

      transactions.each do |x|
        # Increase amount if duplicate address
        next final[x[1]] += x[2] if final[x[1]]?

        final[x[1]] = x[2]
      end

      log "Performing transaction for coin #{coin.name_short}: #{final}"

      tx = rpc.send_many(final)

      fee_per_transaction = rpc.get_transaction(tx)["fee"].as_f / transactions.size
      transactions.each do |x|
        TB::Data::Withdrawal.update_pending(x[0], false)
        fee = -1 * (coin.tx_fee.to_f64 + fee_per_transaction)
        TB::Data::Transaction.update_fee(x[3], BigDecimal.new(fee))
      end
    end
  end
end
