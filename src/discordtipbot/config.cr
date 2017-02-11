require "json"

class Config
  JSON.mapping(
    database_url: String,

    discord_token: String,
    discord_client_id: UInt64,

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
