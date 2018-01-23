class TipBot
  @db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @db = DB.open(@config.database_url + "?max_pool_size=10")
    @coin_api = CoinApi.new(@config, @log)
  end

  def transfer(from : UInt64, to : UInt64, amount : BigDecimal, memo : String)
    @log.debug("#{@config.coinname_short}: Attempting to transfer #{amount} #{@config.coinname_full} from #{from} to #{to}")
    ensure_user(from)
    ensure_user(to)

    return "insufficient balance" if balance(from) < amount

    sql = "INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ($1, $2, $3, $4)"
    tx = @db.exec(sql, memo, from, to, amount)

    if tx.rows_affected == 1
      @log.debug("#{@config.coinname_short}: Transfered #{amount} #{@config.coinname_full} from #{from} to #{to}")
    else
      @log.error("#{@config.coinname_short}: Failed to transfer #{amount} from #{from} to #{to}")
      return "error"
    end

    update_balance(from)
    update_balance(to)

    @log.debug("#{@config.coinname_short}: Calculated balances for #{from} and #{to}")
    return "success"
  end

  def withdraw(from : UInt64, address : String, amount : BigDecimal)
    @log.debug("#{@config.coinname_short}: Attempting to withdraw #{amount} #{@config.coinname_full} from #{from} to #{address}")
    ensure_user(from)
    return "insufficient balance" if balance(from) < amount + @config.txfee

    return "invalid address" unless @coin_api.validate_address(address)

    return "internal address" if @coin_api.internal?(address)

    if tx = @coin_api.withdraw(address, amount, "Withdrawal for #{from}")
      memo = "withdrawal: #{address}; #{tx}"
      @db.exec("INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ($1, $2, 0, $3)", memo, from, amount + @config.txfee)
      @log.debug("#{@config.coinname_short}: Withdrew #{amount} from #{from} to #{address} in TX #{tx}")
    else
      @log.error("#{@config.coinname_short}: Failed to withdraw!")
      return false
    end
    update_balance(from)
    return true
  end

  def multi_transfer(from : UInt64, users : Set(UInt64) | Array(UInt64), total : BigDecimal, memo : String)
    @log.debug("#{@config.coinname_short}: Attempting to multitransfer #{total} #{@config.coinname_full} from #{from} to #{users}")
    # We don't have to ensure_user here, since it's redundant
    # For performance reasons we still can check for sufficient balance
    return "insufficient balance" if balance(from) < total
    return @db.transaction do |tx|
      users.each do |x|
        self.transfer(from, x, (total/users.size), memo)
      end
      @log.debug("#{@config.coinname_short}: Multitransfered #{total} from #{from} to #{users}")
    end
  end

  def get_address(user : UInt64)
    @log.debug("#{@config.coinname_short}: Attempting to get deposit address for #{user}")
    ensure_user(user)

    address = @db.query_one("SELECT address FROM accounts WHERE userid=$1", user, as: String?)
    if address.nil?
      address = @coin_api.new_address

      sql = <<-SQL
      UPDATE accounts
      SET address = ( CASE
                        WHEN address IS NULL THEN $1
                        ELSE ''
                      END )
      WHERE userid = $2
      SQL

      @db.exec(sql, address, user)
      @log.debug("#{@config.coinname_short}: New address for #{user}: #{address}")
    end
    return address
  end

  def get_balance(user : UInt64)
    ensure_user(user)
    balance(user)
  end

  def get_info
    @coin_api.get_info
  end

  def validate_address(address : String)
    @coin_api.validate_address(address)
  end

  def get_config(server : UInt64, memo : String)
    case memo
    when "soak"
      @db.query_one("SELECT soak FROM config WHERE serverid = $1", server, as: Bool?) || false
    when "mention"
      @db.query_one("SELECT mention FROM config WHERE serverid = $1", server, as: Bool?) || false
    when "rain"
      @db.query_one("SELECT rain FROM config WHERE serverid = $1", server, as: Bool?) || false
    when "contacted"
      @db.query_one("SELECT contacted FROM config WHERE serverid = $1", server, as: Bool?) || false
    else
      false
    end
  end

  def update_config(memo : String, status : Bool, server : UInt64)
    case memo
    when "mention"
      @db.exec("UPDATE config SET mention=$1 WHERE serverid=$2", status, server)
    when "soak"
      @db.exec("UPDATE config SET soak=$1 WHERE serverid=$2", status, server)
    when "rain"
      @db.exec("UPDATE config SET rain=$1 WHERE serverid=$2", status, server)
    when "contacted"
      @db.exec("UPDATE config SET contacted=$1 WHERE serverid=$2", status, server)
    end
  end

  def add_server(id : UInt64)
    @db.exec("INSERT INTO config (serverid) SELECT $1 WHERE NOT EXISTS (SELECT serverid FROM config WHERE serverid = $1)", id)
  end

  def db_balance
    @db.query_one("SELECT SUM (balance) FROM accounts", as: BigDecimal)
  end

  def node_balance
    @coin_api.balance
  end

  def insert_tx(txhash : String)
    tx = @coin_api.get_transaction(txhash)
    return unless tx.is_a?(Hash(String, JSON::Type))
    details_array = tx["details"]
    return unless details_array.is_a?(Array(JSON::Type))
    return if details_array.nil?

    details_array.each do |details|
      return unless details.is_a?(Hash(String, JSON::Type))

      if details["category"] == "receive"
        @db.exec("INSERT INTO coin_transactions (txhash, status) SELECT $1, $2 WHERE NOT EXISTS (SELECT txhash FROM coin_transactions WHERE txhash=$1)", txhash, "new")
      end
    end
  end

  def check_deposits
    txlist = @db.query_all("SELECT txhash FROM coin_transactions WHERE status=$1", "new", as: String)
    return if txlist.empty?

    users = Array(UInt64).new

    txlist.each do |transaction|
      tx = @coin_api.get_transaction(transaction)
      next unless tx.is_a?(Hash(String, JSON::Type))

      confirmations = tx["confirmations"]
      next if confirmations.nil?
      next unless confirmations.is_a?(Int64)
      next unless confirmations >= @config.confirmations

      details_array = tx["details"]
      next unless details_array.is_a?(Array(JSON::Type))
      next if details_array.nil?

      details_array.each do |details|
        next unless details.is_a?(Hash(String, JSON::Type))

        next unless details["category"] == "receive"

        query = @db.query_all("SELECT userid FROM accounts WHERE address=$1", details["address"], as: Int64?)
        next if query.nil?

        update = update_coin_transaction(transaction, "never") if (query == [0] || query.empty?)
        # only continue if update.nil? (No changes)
        unless update.nil?
          @log.debug("#{@config.coinname_short}: Invalid deposit at #{transaction}")
          next
        end

        userid = query[0]
        next if userid.nil?

        db = @db.transaction do
          @db.exec("INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ($1, 0, $2, $3)", "deposit (#{transaction})", userid.to_u64, details["amount"])
          update_coin_transaction(transaction, "credited to #{userid}")
        end
        if db
          update_balance(userid.to_u64)
          delete_deposit_address(userid.to_u64)

          users << userid.to_u64
          @log.debug("#{@config.coinname_short}: #{userid} deposited #{details["amount"]} #{@config.coinname_short} in TX #{transaction}")
        end
      end
    end

    return users
  end

  def insert_history_deposits
    txlist = @coin_api.list_transactions(10)
    return unless txlist.is_a?(Array(JSON::Type))
    return unless txlist.size > 0

    users = Array(UInt64).new

    txlist.each do |tx|
      next unless tx.is_a?(Hash(String, JSON::Type))

      category = tx["category"]
      next if category.nil?
      next unless category == "receive"

      # check if tx already in coin_transactions
      exe = @db.query_all("SELECT txhash FROM coin_transactions WHERE txhash=$1", tx["txid"], as: String?)
      next unless exe.empty? || exe == [0]

      insert_tx(tx["txid"].to_s)
    end
  end

  def get_high_balance(high_balance : Int32)
    @db.query_all("SELECT userid FROM accounts WHERE balance > $1", high_balance, as: Int64)
  end

  private def delete_deposit_address(user : UInt64)
    @db.exec("UPDATE accounts SET address=null WHERE userid=$1", user)
  end

  private def update_coin_transaction(transaction : String, memo : String)
    @db.exec("UPDATE coin_transactions SET status=$1 WHERE txhash=$2", memo, transaction)
  end

  private def ensure_user(user : UInt64)
    @log.debug("#{@config.coinname_short}: Ensuring user: #{user}")
    unless @db.query_one?("SELECT 1 FROM accounts WHERE userid = $1", user, as: Int32?)
      @db.exec("INSERT INTO accounts(userid) VALUES ($1)", user)
      @log.debug("#{@config.coinname_short}: Added user #{user}")
    end
  end

  private def update_balance(id : UInt64)
    sql = <<-SQL
    UPDATE accounts SET balance=(
      SELECT (
          (SELECT COALESCE( SUM (amount), 0) FROM transactions WHERE to_id=$1)
          - (SELECT COALESCE( SUM (amount), 0) FROM transactions WHERE from_id=$1)
      ) AS sum)
    WHERE userid=$1;
    SQL

    @db.exec(sql, id)
  end

  private def balance(id : UInt64)
    @db.query_one("SELECT balance FROM accounts WHERE userid=$1", id, as: BigDecimal)
  end
end
