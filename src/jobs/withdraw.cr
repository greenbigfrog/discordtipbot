module Mosquito::Serializers::Primitives
  def deserialize_big_decimal(num)
    BigDecimal.new(num)
  end

  def serialize_big_decimal(num)
    num.to_s
  end
end

require "../common/coin_api"
require "../data/account"
require "../data/withdrawal"

class WithdrawalJob < Mosquito::QueuedJob
  params platform : String, destination : String, coin : Int32, user : Int32, address : String, amount : BigDecimal

  def perform
    cfg = Data::Coin.read(coin)
    api = CoinApi.new(cfg, Logger.new(STDOUT))
    account = Data::Account.read(user)

    reserve_amount = amount + cfg.tx_fee

    insufficient_balance = "Please make sure you also have sufficient balance to cover the (temporary) transaction fee of #{cfg.tx_fee}. The fee will be updated after withdrawal."

    return send_msg(platform, cfg, "Please supply a valid address") unless api.validate_address(address)
    return send_msg(platform, cfg, "Please tip the other user instead of trying to send to an internal address") if api.internal?(address)

    res = account.withdraw(reserve_amount, cfg, address)
    if res.is_a?(Data::Error)
      case res.reason
      when "insufficient balance" then return send_msg(platform, cfg, "Insufficient balance. #{insufficient_balance}")
      when nil                    then return send_msg(platform, cfg, "Something went wrong unexpectedly. Please try again later")
      end
    end
    send_msg(platform, cfg, "Withdrawal of #{amount} is now pending. (#{cfg.tx_fee} have been reserved, and will be returned according to actual transaction cost)\n Should be processed in a few minutes.")

    spawn do
      id = res
      raise "Something went wrong" unless id.is_a?(Int32)

      w = Data::Withdrawal.read(id)
      loop do
        w = Data::Withdrawal.read(id)

        break if w.pending == false
        sleep 5.seconds
      end
      send_msg(platform, cfg, "Your withdrawal of #{w.amount} has been processed.")
    end
  end

  private def send_msg(platform : String, coin : Data::Coin, msg : String)
    case platform
    when "discord" then Discord::Client.new(coin.discord_token.not_nil!).create_message(destination.to_u64, msg)
    when "twitch" then log "Not implemented yet" # TODO
    end
  end
end
