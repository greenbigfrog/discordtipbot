require "json"

class Config
  JSON.mapping({
    database_url:  String,
    chat_password: String,

    prefix: String,

    short: String,

    min_tip:      BigDecimal,
    min_withdraw: BigDecimal,

    confirmations: Int64,

    rpc_url:      String,
    rpc_username: String,
    rpc_password: String,

    coinname_short: String,
    coinname_full:  String,

    walletnotify_port: Int32,

    oauth_token: String,
    oauth_id:    String,
  })
end
