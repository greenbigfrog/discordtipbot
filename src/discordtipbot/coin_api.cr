require "bitcoin_rpc"

class CoinApi
  @type : String

  def initialize(@config : Config, @log : Logger)
    @log.debug("#{config.coinname_short}: Initializing Coin Interaction API for #{@config.coinname_full} with type #{@config.coin_api_type}")

    @type = @config.coin_api_type

    # For RPC communication we are using https://github.com/citizen428/bitcoin_rpc
    @rpc = BitcoinRpc.new(@config.rpc_url, @config.rpc_username, @config.rpc_password)
    @log.debug(@rpc.getinfo)
    # elsif @type == "blockio"
    # @blockio = Blockio::Client.new(@config.blockio_api_key)
  end

  def withdraw(address : String, amount : String, comment : String)
    if @type == "rpc"
      @rpc.sendtoaddress(address, amount, comment)
    end
  end

  def new_address
    @rpc.getnewaddress
  end

  def get_received_by_address(address : String)
    @rpc.getreceivedbyaddress(address)
  end

  def list_transactions
    @rpc.listtransactions
  end
end
