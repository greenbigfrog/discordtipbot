class TipBot
  include Premium

  getter db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @db = DB.open(@config.database_url) # + "?initial_pool_size=10&max_pool_size=10&max_idle_pool_size=10")
    @coin_api = CoinApi.new(@config, @log)
  end

  def transfer(from : UInt64, to : UInt64, amount : BigDecimal, memo : String)
    @log.debug("#{@config.coinname_short}: Attempting to transfer #{amount} #{@config.coinname_full} from #{from} to #{to}")
    ensure_user(from)
    ensure_user(to)

    return "insufficient balance" if balance(from) < amount

    @db.transaction do |tx|
      begin
        sql = "INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ($1, $2, $3, $4)"
        transaction = tx.connection.exec(sql, memo, from, to, amount)

        if transaction.rows_affected == 1
          @log.debug("#{@config.coinname_short}: Transfered #{amount} #{@config.coinname_full} from #{from} to #{to}")
        else
          @log.error("#{@config.coinname_short}: Failed to transfer #{amount} from #{from} to #{to}")
          return "error"
        end

        update_balance(from, tx.connection)
        update_balance(to, tx.connection)

        @log.debug("#{@config.coinname_short}: Calculated balances for #{from} and #{to}")
      rescue ex : PQ::PQError
        @log.error(ex)
        tx.rollback
        @log.error("#{@config.coinname_short}: PQError during transfer #{memo} from #{from} to #{to}")
        return "error"
      end
    end
    true
  end

  def withdraw(from : UInt64, address : String, amount : BigDecimal)
    @log.debug("#{@config.coinname_short}: Attempting to withdraw #{amount} #{@config.coinname_full} from #{from} to #{address}")
    ensure_user(from)
    return "insufficient balance" if balance(from) < amount + @config.txfee

    return "invalid address" unless @coin_api.validate_address(address)

    return "internal address" if @coin_api.internal?(address)
    puts "b"

    @db.transaction do |tx|
      begin
        memo = "withdrawal: #{address}"
        @log.debug("#{@config.coinname_short}: Added withdrawal of #{amount} from #{from} to #{address} to queue")

        tx.connection.exec("INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ($1, $2, 0, $3)", memo, from, amount + @config.txfee)
        tx.connection.exec("INSERT INTO withdrawals(from_id, amount, address) VALUES ($1, $2, $3)", from, amount, address)
        update_balance(from, tx.connection)
      rescue ex : PQ::PQError
        tx.rollback
        @log.error(ex)
        @log.error("#{@config.coinname_short}: PQError while attempting to withdraw #{amount} #{@config.coinname_short} to #{address} for #{from}")
        return false
      end
    end
    true
  end

  def process_pending_withdrawals
    users = Hash(UInt64, String).new

    return users if self.pending_withdrawal_sum > self.node_balance(@config.confirmations)
    record = {id: Int32, from_id: Int64, address: String, amount: BigDecimal}
    pending = @db.query_all("SELECT id, from_id, address, amount FROM withdrawals WHERE status = 'pending'", as: record)
    pending.each do |x|
      begin
        hash = @coin_api.withdraw(x[:address], x[:amount], "Withdrawal for #{x[:from_id]}")
      rescue ex
        @log.error(ex)
        @log.error("#{@config.coinname_short}: Something went wrong while processing withdrawals")
        next
      end
      @db.exec("UPDATE withdrawals SET status = 'processed' WHERE id = $1", x[:id])
      @log.debug("#{@config.coinname_short}: Processed withdrawal of #{x[:amount]} for #{x[:from_id]} to #{x[:address]}")
      users[x[:from_id].to_u64] = hash.to_s
    end
    users
  end

  def offsite_withdrawal(user : UInt64, amount : BigDecimal, address : String)
    return "Invalid Address" unless @coin_api.validate_address(address)

    begin
      @coin_api.withdraw(address, amount, "Offsite withdrawal for #{user}")
    rescue exception
      msg = exception.message
      raise "No Exception Message" unless msg
      return "Insufficient Funds" if JSON.parse(msg)["code"] == -6 # Insufficient Funds
    end

    @db.exec("INSERT INTO offsite(memo, userid, amount) VALUES ('withdrawal', $1, $2)", user, amount)

    @log.debug("#{@config.coinname_short}: Offsite withdrawal for #{user}, with #{amount} to #{address}")
    true
  end

  def multi_transfer(from : UInt64, users : Set(UInt64) | Array(UInt64), total : BigDecimal, memo : String)
    @log.debug("#{@config.coinname_short}: Attempting to multitransfer #{total} #{@config.coinname_full} from #{from} to #{users}")
    # We don't have to ensure_user here, since it's redundant
    # For performance reasons we still can check for sufficient balance
    balance = balance(from)

    # TODO set mode to down as soon rounding modes are available in crystal
    amount = BigDecimal.new(total / users.size).round(8)
    # TODO get rid of temporary fix below
    # This only applies if thanks to rounding the total amount
    # is higher then the sum of the split up balance
    amount = BigDecimal.new(total / users.size).round(7) if amount * users.size > total
    return "insufficient balance" if balance < total

    users.each do |x|
      return false unless self.transfer(from, x, amount, memo)
    end
    @log.debug("#{@config.coinname_short}: Multitransfered #{total} from #{from} to #{users}")
    true
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

  def get_offsite_address(user : UInt64)
    @log.debug("#{@config.coinname_short}: Attempting to get new offsite address for #{user}")
    ensure_user(user)

    address = @db.query_one?("SELECT address FROM offsite_addresses WHERE userid=$1", user, as: String?)

    if address.nil?
      address = @coin_api.new_address

      @db.exec("INSERT INTO offsite_addresses (address, userid) VALUES ($1, $2)", address, user)
      @log.debug("#{@config.coinname_short}: New offsite address for #{user}: #{address}")
    end
    address
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

  def update_config(memo : String, status : Bool | BigDecimal | String, server : UInt64)
    return false unless CONFIG_COLUMNS.includes?(memo)
    begin
      @db.exec("UPDATE config SET #{memo} = $1 WHERE serverid = $2", status, server)
    rescue PQ::PQError
      false
    end
  end

  def clear_config(memo : String, server : UInt64)
    @db.exec("UPDATE config SET #{memo} = '' WHERE serverid = $1", server)
  end

  def add_server(id : UInt64)
    @db.exec("INSERT INTO config (serverid) VALUES($1) ON CONFLICT DO NOTHING", id)
  end

  def contacted(guild : UInt64)
    @db.query_one?("SELECT contacted FROM config WHERE serverid = $1", guild, as: Bool?) || false
  end

  def db_balance
    @db.query_one("SELECT SUM (balance) FROM accounts", as: BigDecimal)
  end

  def node_balance(confirmations = 0)
    @coin_api.balance(confirmations)
  end

  def pending_withdrawal_sum
    @db.query_one("SELECT SUM (amount) FROM withdrawals WHERE status = 'pending'", as: BigDecimal?) || BigDecimal.new(0)
  end

  def pending_coin_transactions
    (@db.query_one("SELECT SUM(1) FROM coin_transactions WHERE status = 'new'", as: Int64?) || 0) > 0
  end

  def total_db_balance
    db_balance + pending_withdrawal_sum
  end

  def withdrawal_sum
    @db.query_one("SELECT SUM (amount) FROM transactions WHERE memo LIKE 'withdrawal:%'", as: BigDecimal)
  end

  def deposit_sum
    @db.query_one("SELECT SUM (amount) FROM transactions WHERE memo LIKE 'deposit%'", as: BigDecimal)
  end

  def insert_tx(txhash : String)
    tx = @coin_api.get_transaction(txhash).as_h
    return unless tx.is_a?(Hash(String, JSON::Any))
    details_array = tx["details"].as_a
    return unless details_array.is_a?(Array(JSON::Any))
    return if details_array.nil?

    details_array.each do |details|
      details = details.as_h
      return unless details.is_a?(Hash(String, JSON::Any))

      if details["category"] == "receive"
        @db.exec("INSERT INTO coin_transactions (txhash, status) VALUES($1, $2) ON CONFLICT DO NOTHING", txhash, "new")
      end
    end
  end

  def check_deposits
    txlist = @db.query_all("SELECT txhash FROM coin_transactions WHERE status=$1", "new", as: String)
    return if txlist.empty?

    users = Array(UInt64).new

    txlist.each do |transaction|
      tx = @coin_api.get_transaction(transaction).as_h
      next unless tx.is_a?(Hash(String, JSON::Any))

      confirmations = tx["confirmations"].as_i
      next unless confirmations >= @config.confirmations

      details_array = tx["details"].as_a
      next unless details_array.is_a?(Array(JSON::Any))

      details_array.each do |details|
        details = details.as_h
        next unless details.is_a?(Hash(String, JSON::Any))

        next unless details["category"] == "receive"

        address = details["address"].as_s

        amount = details["amount"].as_f
        amount = BigDecimal.new(amount)

        query = @db.query_all("SELECT userid FROM accounts WHERE address=$1", address, as: Int64?)
        next if query.nil?

        if (query == [0] || query.empty?)
          if check_offsite_deposits(address, amount)
            update = update_coin_transaction(transaction, "offsite")
            @log.debug("#{@config.coinname_short}: Returned offsite deposit at #{transaction}")
          else
            update = update_coin_transaction(transaction, "never")
            @log.debug("#{@config.coinname_short}: Invalid deposit at #{transaction}")
          end
        end

        # only continue if update.nil? (No changes)
        next unless update.nil?

        userid = query[0]
        next if userid.nil?

        db = @db.transaction do
          @db.exec("INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ($1, 0, $2, $3)", "deposit (#{transaction})", userid.to_u64, amount)
          update_coin_transaction(transaction, "credited to #{userid}")
        end
        if db
          update_balance(userid.to_u64)
          delete_deposit_address(userid.to_u64)

          users << userid.to_u64
          @log.debug("#{@config.coinname_short}: #{userid} deposited #{amount} #{@config.coinname_short} in TX #{transaction}")
        end
      end
    end

    return users
  end

  def check_offsite_deposits(address : String, amount : BigDecimal)
    query = @db.query_one?("SELECT userid FROM offsite_addresses WHERE address=$1", address, as: Int64)
    return false if query.nil?

    db.exec("INSERT INTO offsite(memo, userid, amount) VALUES ('deposit', $1, $2)", query, amount)
    true
  end

  def insert_history_deposits
    txlist = @coin_api.list_transactions(1000).as_a

    return unless txlist.is_a?(Array(JSON::Any))
    return unless txlist.size > 0

    txlist.each do |tx|
      tx = tx.as_h
      next unless tx.is_a?(Hash(String, JSON::Any))

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

  def get_offsite_balance(user : UInt64)
    sql = <<-SQL
        SELECT (
          (SELECT COALESCE( SUM (amount), 0) FROM offsite WHERE userid=$1 AND memo = 'deposit')
          - (SELECT COALESCE( SUM (amount), 0) FROM offsite WHERE userid=$1 AND memo = 'withdrawal')
        ) AS sum
    SQL
    @db.query_one(sql, user, as: BigDecimal)
  end

  def get_offsite_balances
    sql = <<-SQL
        SELECT userid,
        SUM(CASE WHEN memo = 'deposit' THEN amount ELSE 0 END) -
                 SUM(CASE WHEN memo = 'withdrawal' THEN amount ELSE 0 END) AS balance
        FROM offsite
        GROUP BY userid
    SQL

    @db.query_all(sql, as: {userid: Int64, balance: BigDecimal})
  end

  private def delete_deposit_address(user : UInt64)
    @db.exec("UPDATE accounts SET address=null WHERE userid=$1", user)
  end

  private def update_coin_transaction(transaction : String, memo : String)
    @db.exec("UPDATE coin_transactions SET status=$1 WHERE txhash=$2", memo, transaction)
  end

  private def ensure_user(user : UInt64)
    @log.debug("#{@config.coinname_short}: Ensuring user: #{user}")
    @db.exec("INSERT INTO accounts(userid) VALUES ($1) ON CONFLICT DO NOTHING", user)
  end

  private def update_balance(id : UInt64, tx : DB::Connection? = nil)
    sql = <<-SQL
    UPDATE accounts SET balance=(
      SELECT (
          (SELECT COALESCE( SUM (amount), 0) FROM transactions WHERE to_id=$1)
          - (SELECT COALESCE( SUM (amount), 0) FROM transactions WHERE from_id=$1)
      ) AS sum)
    WHERE userid=$1;
    SQL
    if tx
      tx.exec(sql, id)
    else
      @db.exec(sql, id)
    end
  end

  private def balance(id : UInt64)
    @db.query_one?("SELECT balance FROM accounts WHERE userid=$1", id, as: BigDecimal?) || BigDecimal.new
  end
end
