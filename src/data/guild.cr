struct Data::Guild
  DB.mapping(
    id: Int32,
    coin: Int32,

    contacted: Bool,

    created_time: Time,

    prefix: String?,

    mention: Bool,
    soak: Bool,
    rain: Bool,

    min_soak: BigDecimal?,
    min_soak_total: BigDecimal?,

    min_rain: BigDecimal?,
    min_rain_total: BigDecimal?,

    min_tip: BigDecimal?,
    min_lucky: BigDecimal?
  )

  def self.read(id : Int64, coin : Coin)
    DATA.query_one?("SELECT * FROM guilds WHERE id = $1 AND coin = $2", id, coin, as: self)
  end

  def self.read_prefix(id : Int64, coin : Coin)
    DATA.query_one?("SELECT prefix FROM guilds WHERE id = $1 AND coin = $2", id, coin.id, as: String)
  end

  def self.read_config(id : Int64, coin : Coin, field : String) : Bool?
    DATA.query_one?("SELECT #{field} FROM guilds WHERE id = $1 AND coin = $2", id, coin.id, as: Bool?)
  end

  def self.update_prefix(id : Int64, coin : Coin, value : String?)
    DATA.exec("UPDATE guilds SET prefix = $1 WHERE id = $2 AND coin = $3", value, id, coin.id)
  end

  def self.read_decimal_config(id : Int64, coin : Coin, field : String) : BigDecimal?
    DATA.query_one?("SELECT #{field} FROM guilds WHERE id = $1 AND coin = $2", id, coin.id, as: BigDecimal?)
  end
end
