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
end

class Data::User
  DB.mapping(
    userid: Int64,
    balance: BigDecimal,
    address: String?,
    created_time: Time
  )
end
