private macro define_string_getter(*strings)
  def get(some_string)
    case some_string
    {% for string in strings %}
    when {{ string }} then @{{ string.id }}
    {% end %}
    else
      raise "Value not found"
    end
  end
end

struct Data::Coin
  define_string_getter("default_min_soak", "default_min_soak_total",
    "default_min_rain", "default_min_rain_total",
    "default_min_tip", "default_min_lucky")

  DB.mapping(
    id: Int32,

    discord_token: String?,
    discord_client_id: String?,

    twitch_chat_password: String?,
    twitch_oauth_token: String?,
    twitch_oauth_id: String?,

    prefix: String,

    dbl_auth: String?,
    dbl_stats: String?,
    botsgg_token: String?,

    admins: Array(Int64),
    ignored_users: Array(Int64),
    whitelisted_bots: Array(Int64),

    rpc_url: String,
    rpc_username: String,
    rpc_password: String,

    uri_scheme: String,

    tx_fee: BigDecimal,

    name_short: String,
    name_long: String,

    default_min_soak: BigDecimal,
    default_min_soak_total: BigDecimal,

    default_min_rain: BigDecimal,
    default_min_rain_total: BigDecimal,

    default_min_tip: BigDecimal,
    default_min_lucky: BigDecimal,

    high_balance: BigDecimal,

    created_time: Time
  )

  def self.read
    DATA.query_all("SELECT * FROM coins", as: self)
  end

  def self.read_discord_token(coin : Int32)
    DATA.query_one("SELECT discord_token FROM coins WHERE id = $1", coin, as: String)
  end
end
