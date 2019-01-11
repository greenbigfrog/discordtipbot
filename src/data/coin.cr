struct Data::Coin
  DB.mapping(
    id: Int32,

    rpc_url: String,
    rpc_username: String,
    rpc_password: String,

    name_short: String,
    name_long: String,

    default_min_soak: BigDecimal,
    default_min_soak_total: BigDecimal,

    default_min_rain: BigDecimal,
    default_min_rain_total: BigDecimal,

    default_min_tip: BigDecimal,
    default_min_lucky: BigDecimal,

    created_time: Time
  )

  def self.create(rpc_url, rpc_username, rpc_password,
                  name_short, name_long,
                  default_min_soak, default_min_soak_total,
                  default_min_rain, default_min_rain_total,
                  default_min_tip, default_min_lucky)
    sql = <<-SQL
  	INSERT INTO coins(
  		rpc_url, rpc_username, rpc_password,
  		name_short, name_long,
  		default_min_soak, default_min_soak_total,
    	default_min_rain, default_min_rain_total,
    	default_min_tip, default_min_lucky
   	)
   	VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
  	SQL

    DATA.exec(sql, rpc_url, rpc_username, rpc_password,
      name_short, name_long,
      default_min_soak, default_min_soak_total,
      default_min_rain, default_min_rain_total,
      default_min_tip, default_min_lucky)
  end

  def self.read
    DATA.query_all("SELECT * FROM coins", as: Coin)
  end
end
