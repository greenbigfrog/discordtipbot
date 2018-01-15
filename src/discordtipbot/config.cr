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

    txfee: Float64,

    min_tip: Float64,
    min_soak: Float64,
    min_soak_total: Float64,
    min_rain_total: Float64,
    min_withdraw: Float64,

    admins: Array(UInt64)
  )
end
