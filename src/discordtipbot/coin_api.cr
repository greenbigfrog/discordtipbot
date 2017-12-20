require "bitcoin_rpc"

class CoinApi
  def initialize(@config, @log : Logger)
    @log.debug("Initializing Coin Interaction API for #{@coin} with type #{@type}")

    if @type == "rpc"
      # For RPC communication we are using https://github.com/citizen428/bitcoin_rpc
      @rpc = BitcoinRpc.new(@config.rpc_url, @config.rpc_username, @config.rpc_password)
      #   elsif @type == "blockio"
      #     @blockio = Blockio::Client.new(@config.blockio_api_key)
    end
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
