require "json"

class Config
  JSON.mapping(
    database_url: String,

    discord_token: String,
    discord_client_id: UInt64,

    coin_api_type: String,

    blockio_api_key: String,

    rpc_url: String,
    rpc_username: String,
    rpc_password: String,
    confirmations: Int64,

    walletnotify_port: Int32,

    prefix: String,

    coinname_full: String,
    coinname_short: String,

    uri_scheme: String,

    txfee: BigDecimal,

    min_tip: BigDecimal,
    min_soak: BigDecimal,
    min_soak_total: BigDecimal,
    min_rain_total: BigDecimal,
    min_withdraw: BigDecimal,

    high_balance: Int32,

    admins: Array(UInt64),
    ignored_users: Set(UInt64),

    webhook_id: UInt64,
    webhook_token: String
  )
end
