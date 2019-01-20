struct Data::Withdrawal
  DB.mapping(
    id: Int32,
    pending: Bool,
    coin: Int32,
    user_id: Int64,
    address: String,
    amount: BigDecimal,
    transaction: Int64,
    created_time: Time
  )

  def self.create(coin : Coin, user_id : Int32, address : String, amount : BigDecimal, transaction : Int32, db : DB::Connection = DATA.connection)
    db.query_one("INSERT INTO withdrawals(coin, user_id, address, amount, transaction) VALUES ($1, $2, $3, $4, $5) RETURNING id", coin.id, user_id, address, amount, transaction, as: Int32)
  end

  def self.read(id : Int32)
    DATA.query_one("SELECT * FROM withdrawals WHERE id = $1", id, as: self)
  end

  def self.read_pending_withdrawals
    DATA.query_all("SELECT * FROM withdrawals WHERE pending = true", as: self)
  end

  def self.update_pending(id : Int32, status : Bool)
    DATA.exec("UPDATE withdrawals SET pending = $1 WHERE id = $2", status, id)
  end
end
