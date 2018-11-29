require "bitcoin_rpc"

class CoinApi
  @type : String
  @rpc : BitcoinRpc

  def initialize(@config : Config, @log : Logger)
    @log.debug("#{config.coinname_short}: Initializing Coin Interaction API for #{@config.coinname_full} with type #{@config.coin_api_type}")

    @type = @config.coin_api_type

    rpc = nil
    i = 1
    while rpc.nil?
      begin
        rpc = BitcoinRpc.new(@config.rpc_url, @config.rpc_username, @config.rpc_password)
        rpc.getinfo
      rescue ex
        @log.warn("Unable to connect to Coin Daemon. Going to wait #{i} seconds before retrying")
        rpc = nil
        sleep (i = Math.min(i*2, 10))
      end
    end
    raise "rpc was still nil" if rpc.nil?
    @rpc = rpc

    @log.debug("#{config.coinname_short}: #{@rpc.getinfo}")
  end

  def get_info
    @rpc.get_info
  end

  def withdraw(address : String, amount : BigDecimal, comment : String)
    @rpc.send_to_address(address, amount.to_f64, comment)
  end

  def new_address
    @rpc.get_new_address
  end

  def get_received_by_address(address : String)
    @rpc.get_received_by_address(address)
  end

  def list_transactions(count : Int32)
    @rpc.list_transactions("", count)
  end

  def validate_address(address : String)
    a = address_info(address)
    return unless a
    a["isvalid"].as_bool
  end

  def internal?(address : String)
    a = address_info(address)
    return unless a
    a["ismine"].as_bool
  end

  def balance(confirmations = 0) : BigDecimal
    bal = @rpc.get_balance("*", confirmations)

    BigDecimal.new(bal.to_s) || BigDecimal.new(0)
  end

  def get_transaction(tx : String)
    @rpc.get_transaction(tx)
  end

  private def address_info(address : String)
    info = @rpc.validate_address(address).as_h
    return unless info.is_a?(Hash(String, JSON::Any))
    info
  end
end
