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

    prefix: String,

    coinname_full: String,
    coinname_short: String,

    min_tip: Float32,
    min_soak: Float32,
    min_rain: Float32,
    min_withdraw: Float32,

    admins: Array(Int64)
  )
end
