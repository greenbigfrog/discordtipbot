require "./enum"

struct Data::DepositAddress
  DB.mapping(
    active: Bool,
    account_id: Int32,
    coin: Int32,
    address: String,
    created_time: Time
  )

  def self.read_or_create(coin : Coin, user : Account)
    address = nil
    DATA.transaction do |tx|
      db = tx.connection
      begin
        address = db.query_one?("SELECT address FROM deposit_addresses WHERE active = true AND account_id = $1 AND coin = $2", user.id, coin.id, as: String)
        return address unless address.nil?

        api = CoinApi.new(coin, Logger.new(STDOUT))
        address = api.new_address

        db.exec("INSERT INTO deposit_addresses (account_id, coin, address, active) VALUES ($1, $2, $3, true)", user.id, coin.id, address)
        LOG.info("Generated new address for user #{user} and coin #{coin.name_short}: #{address}")
      rescue ex : PQ::PQError
        LOG.warn(ex.inspect_with_backtrace)
        tx.rollback
        return Error.new
      end
    end
    address
  end

  def self.read(address : String) : self?
    DATA.query_one?("SELECT * FROM deposit_addresses WHERE address = $1", address, as: self)
  end

  def self.read_all_active_for_account(account_id : Int32)
    DATA.query_all("SELECT * FROM deposit_addresses WHERE active = true AND account_id = $1", account_id, as: self)
  end

  def deactivate
    @active = false
    DATA.exec("UPDATE deposit_addresses SET active = false WHERE address = $1", @address)
  end
end
