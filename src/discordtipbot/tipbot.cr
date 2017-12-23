class TipBot
  @db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @db = DB.open(@config.database_url)
    @coin_api = CoinApi.new(@config, @log)
  end

  def transfer(from : UInt64, to : UInt64, amount : Float64)
    @log.debug("#{@config.coinname_short}: Attempting to transfer #{amount} #{@config.coinname_full} from #{from} to #{to}")
    ensure_user(from)
    ensure_user(to)

    return "insufficient balance" if balance(from) < amount

    tx = @db.exec("INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ('tip', $1, $2, $3);", from, to, amount)
    if tx.rows_affected == 1
      @log.debug("#{@config.coinname_short}: Transfered #{amount} #{@config.coinname_full} from #{from} to #{to}")
    else
      @log.error("#{@config.coinname_short}: Failed to transfer #{amount} from #{from} to #{to}")
      return "error"
    end
    update_balance(from)
    update_balance(to)
    return "success"
    @log.debug("#{@config.coinname_short}: Calculated balances for #{from} and #{to}")
  end

  def withdraw(from : UInt64, address : String, amount : Float64)
    @log.debug("#{@config.coinname_short}: Attempting to withdraw #{amount} #{@config.coinname_full} from #{from} to #{address}")
    ensure_user(from)
    return "insufficient balance" if balance(from) < amount + @config.txfee

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

  def multi_transfer(from : UInt64, users : Array[UInt64], total : Float64)
    @log.debug("#{@config.coinname_short}: Attempting to multitransfer #{total} #{@config.coinname_full} from #{from} to #{users}")
    # We don't have to ensure_user here, since it's redundant
    # For performance reasons we still can check for sufficient balance
    raise "Insufficient Balance" if balance(from) < amount
    @db.transaction do |tx|
      users.each do |x|
        self.transfer(from, x, (total/users.size))
      end
      @log.debug("#{config.coinname_short}: Multitransfered #{total} from #{from} to #{users}")
    end
  end

  def get_address(user : UInt64)
    @log.debug("#{@config.coinname_short}: Attempting to get deposit address for #{user}")
    ensure_user(user)

    address = @db.query_one("SELECT address FROM accounts WHERE userid=$1", user, &.read(String | Nil))
    if address.nil?
      address = @coin_api.new_address
      @db.exec("UPDATE accounts SET address=$1 WHERE userid=$2", address, user)
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

  private def ensure_user(user : UInt64)
    @log.debug("#{@config.coinname_short}: Ensuring user: #{user}")
    @db.exec("INSERT INTO accounts(userid) VALUES ($1)", user) if @db.query_all("SELECT count(*) FROM accounts WHERE userid = $1", user, &.read(Int64)) == [0]
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
    @db.query_all("SELECT balance FROM accounts WHERE userid=$1", id, &.read(Float64))[0] || 0.0
  end
end
