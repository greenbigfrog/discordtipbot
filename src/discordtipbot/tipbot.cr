class TipBot
  @db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @db = DB.open(@config.database_url)
    @coin_api = CoinApi.new(@config, @log)
  end

  def transfer(from : UInt64, to : UInt64, amount : Float32)
    @log.debug("#{@config.coinname_short}: Attempting to transfer #{amount} #{@config.coinname_full} from #{from} to #{to}")
    ensure_user(from)
    ensure_user(to)
    raise "Insufficient Balance" if balance(from) < amount
    @db.transaction do |tx|
      tx.connection.exec("INSERT INTO transactions(memo, from_id, to_id, amount) VALUES ('tip', #{from}, #{to}, #{amount});")
      @log.debug("#{@config.coinname_short}: Transfered #{amount} #{@config.coinname_full} from #{from} to #{to}")
    end
    update_balance(from)
    update_balance(to)
  end

  def withdraw(from : UInt64, address : String, amount : Float32)
    @log.debug("#{@config.coinname_short}: Attempting to withdraw #{amount} #{@config.coinname_full} from #{from} to #{address}")
    ensure_user(from)
    raise "Insufficient Balance" if balance(from) < amount
    db.transaction do |tx|
      tx.connection.exec("INSERT INTO transactions VALUES ('withdrawal', #{from})")
      @coin_api.withdraw(address, amount, "Withdrawal for #{from}")
      @log.debug("#{@config.coinname_short}: Withdrew #{amount} from #{from} to #{address}")
    end
    update_balance(from)
  end

  def multi_transfer(from : UInt64, users : Array[UInt64], total : Float32)
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
    res = @db.query("SELECT address FROM accounts WHERE userid=#{user}").read(String)
    if res.empty?
      res = @coin_api.new_address
      @log.debug("#{@config.coinname_short}: New address for #{user}: #{res}")
    end
  end

  def get_balance(user : UInt64)
    ensure_user(user)
    balance(user)
  end

  def get_info
    @coin_api.get_info
  end

  private def ensure_user(user : UInt64)
    @log.debug("#{@config.coinname_short}: Ensuring user: #{user}")
    @db.transaction do |tx|
      db = tx.connection
      db.exec("INSERT INTO accounts(userid) VALUES (#{user})") unless db.exec("SELECT * FROM accounts WHERE userid=#{user}").rows_affected > 0
    end
  end

  private def update_balance(id : UInt64)
    @db.exec("UPDATE accounts SET balance = ((SELECT count(amount) FROM transactions WHERE to_id = #{id}) - (SELECT count(amount) FROM transactions WHERE from_id = #{id})) WHERE userid = #{id};")
  end

  private def balance(id : UInt64)
    @db.query("SELECT balance FROM accounts WHERE userid=#{id}").read(Float32)
  end
end
