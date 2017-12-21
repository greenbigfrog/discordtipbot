class TipBot
  @db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @db = DB.open(@config.database_url)
    @coin_api = CoinApi.new(@config, @log)
  end

  def transfer(from : UInt64, to : UInt64, amount : Float32)
    @log.debug("Attempting to transfer #{amount} #{@config.coinname_full} from #{from} to #{to}")
    self.ensure_user(from)
    self.ensure_user(to)
    sql = <<-SQL
        INSERT INTO transactions VALUES ('tip', #{from}, #{to}, #{amount});
        UPDATE accounts SET balance = ((SELECT count(amount) FROM transactions WHERE to_id = #{from}) - (SELECT count(amount) FROM transactions WHERE from_id = #{from})) WHERE userid = #{from};
        UPDATE accounts SET balance = ((SELECT count(amount) FROM transactions WHERE to_id = #{from}) - (SELECT count(amount) FROM transactions WHERE from_id = #{from})) WHERE userid = #{to};
        SQL
    db.transaction do |tx|
      tx.exec(sql)
      @log.debug("Transfered #{amount} #{@config.coinname_full} from #{from} to #{to}")
    end
  end

  def withdraw(from : UInt64, address : String, amount : Float32)
    @log.debug("Attempting to withdraw #{amount} #{@config.coinname_full} from #{from} to #{address}")
    self.ensure_user(from)
    sql = <<-SQL
            INSERT INTO transactions VALUES ('withdrawal', #{from})
    SQL
    db.transaction do |tx|
      tx.exec(sql)
      @coin_api.withdraw(address, amount, "Withdrawal for #{from}")
    end
  end

  def multi_transfer(from : UInt64, users : Array[UInt64], total : Float32)
    @log.debug("Attempting to multitransfer #{total} #{@config.coinname_full} from #{from} to #{users}")
    # We don't have to ensure_user here, since it's redundant
    db.transaction do |tx|
      users.each do |x|
        self.transfer(from, x, (total/users.size))
      end
    end
  end

  def get_address(user : UInt64)
    @log.debug("Attempting to get deposit address for #{user}")
    self.ensure_user(user)
    sql = <<-SQL
        SELECT address FROM accounts WHERE userid=#{user}
    SQL
    db.transaction do |tx|
      res = tx.exec(sql)
      if res.empty?
        res = @coin_api.new_address
      end
    end
  end

  def get_balance(user : UInt64)
    self.ensure_user(user)
    db.exec("SELECT balance FROM accounts WHERE userid=#{user}")
  end

  private def ensure_user(user : UInt64)
    @debug.log("Ensuring user: #{user}")
    db.transaction do |tx|
      tx.exec("INSERT INTO accounts(userid) VALUES (#{user})") if tx.exec("SELECT * FROM accounts WHERE userid=#{user}")
    end
  end
end
