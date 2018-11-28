require "kemal"
require "big/json"
require "pg"
require "pg/pg_ext/big_decimal"
require "./discordtipbot/config"

Config.load(ARGV[0])

database = Hash(String, DB::Database).new

Config.current.each do |_, config|
  database[config.coinname_full.downcase] = DB.open(config.database_url + "?max_pool_size=10")
end

get "/" do
  "You should not be accessing this."
end

post "/webhook/:coin" do |env|
  headers = env.request.headers
  json = env.params.json

  halt env, status_code: 403 unless headers["Authorization"]? == "ABC"

  halt env, status_code: 204 unless json["type"] == "upvote"

  coin = env.params.url["coin"]
  query = json["query"]?
  params = HTTP::Params.parse(query.lchop('?')) if query.is_a?(String)
  server = params["server"]? if params

  if server
    extend_premium(database[coin], server.to_u64, 15.minutes)
  else
    # TODO handle if there's no server param
    halt env, status_code: 503
  end
end

def set_premium(db : DB::Database, guild_id : UInt64, till : Time)
  db.exec("UPDATE config SET premium = true, premium_till = $1 WHERE serverid = $2", till, guild_id)
end

def extend_premium(db : DB::Database, guild_id : UInt64, extend_by : Time::Span)
  current = status_premium(db, guild_id)
  if current
    till = current + extend_by
  else
    till = Time.utc_now + extend_by
  end
  set_premium(db, guild_id, till)
end

def status_premium(db : DB::Database, guild_id : UInt64)
  db.query_one?("SELECT premium_till FROM config WHERE serverid = $1", guild_id, as: Time?)
end

Kemal.run do |conf|
  conf.env = "production"
end
