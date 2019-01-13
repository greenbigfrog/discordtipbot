struct Data::Discord::Guild
  DB.mapping(
    id: Int64,

    guild_id: Int64,
    coin: Int32,

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

  def self.read_config_id(id : Int64, coin : Coin)
    DATA.query_one("SELECT id FROM guilds WHERE guild_id = $1 AND coin = $2", id, coin.id, as: Int64)
  end

  def self.new?(id : Int64, coin : Coin)
    DATA.query_one?(<<-SQL, id, coin.id, as: Bool)
    INSERT INTO guilds(guild_id, coin)
    VALUES ($1, $2)
    ON CONFLICT ON CONSTRAINT guilds_guild_id_coin_key
    DO UPDATE SET coin = guilds.coin RETURNING (xmax = 0) AS inserted;
    SQL
  end

  def self.read_prefix(id : Int64, coin : Coin)
    DATA.query_one?("SELECT prefix FROM guilds, configs WHERE guild_id = $1 AND coin = $2", id, coin.id, as: String?)
  end

  def self.read_config(id : Int64, coin : Coin, field : String) : Bool?
    DATA.query_one?("SELECT #{field} FROM guilds, configs WHERE guild_id = $1 AND coin = $2", id, coin.id, as: Bool?)
  end

  def self.update_prefix(id : Int64, coin : Coin, prefix : String?)
    update_config(id, coin, "prefix", prefix)
  end

  def self.update_config(id : Int64, coin : Coin, key : String, value : String?)
    DATA.exec(<<-SQL, value, id, coin.id)
    INSERT INTO configs(id, #{key})
    VALUES (
      (SELECT id FROM guilds WHERE guild_id = $2 AND coin = $3),
      $1
    )
    ON CONFLICT (id) DO
      UPDATE SET #{key} = $1;
    SQL
  end

  def self.read_decimal_config(id : Int64, coin : Coin, field : String) : BigDecimal?
    DATA.query_one?("SELECT #{field} FROM guilds, configs WHERE guild_id = $1 AND coin = $2", id, coin.id, as: BigDecimal?)
  end
end
