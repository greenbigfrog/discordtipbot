class Data
  getter db : DB::Database

  def initialize(@config : Config)
    @db = DB.open(@config.database_url + "?max_pool_size=10")
  end

  def get_user(id : UInt64)
    sql = <<-SQL
    SELECT userid, balance, address, created_time
    FROM accounts
    WHERE userid = $1
    SQL

    @db.query_one(sql, id, as: Data::User)
  end

  def statistics
    @db.query_one("SELECT * FROM statistics", as: Statistics)
  end

  def get_transactions(user : UInt64)
    @db.query_all("SELECT * FROM transactions WHERE to_id = $1 OR from_id = $1", user, as: Data::Transaction)
  end
end

class Data::Transaction
  DB.mapping(
    id: Int32,
    memo: String,
    from_id: Int64,
    to_id: Int64,
    amount: BigDecimal,
    time: Time
  )
end

class Data::User
  DB.mapping(
    userid: Int64,
    balance: BigDecimal,
    address: String?,
    created_time: Time
  )
end
