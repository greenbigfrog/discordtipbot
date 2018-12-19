require "kemal"
require "big/json"
require "pg"
require "pg/pg_ext/big_decimal"
require "./discordtipbot/config"
require "./discordtipbot/premium"
require "discordcr"

class Coin
  include Premium

  getter db : DB::Database
  getter bot : Discord::Client
  getter cache : Discord::Cache
  getter dbl_auth : String

  def initialize(@db, @bot, @cache, @dbl_auth)
  end
end

class Msg
  getter coin : String
  getter user : UInt64
  getter msg : String

  def initialize(@coin, @user, @msg)
  end
end

Config.load(ARGV[0])

data = Hash(String, Coin).new
queue = Deque(Msg).new

spawn do
  loop do
    if x = queue.shift?
      begin
        channel = data[x.coin].cache.resolve_dm_channel(x.user)
        data[x.coin].bot.create_message(channel, x.msg)
      rescue ex
        puts "Unable to DM #{x.user}\n#{ex.inspect_with_backtrace}"
      end
    end
    sleep 2
  end
end

Config.current.each do |_, config|
  next unless auth = config.dbl_auth
  db = DB.open(config.database_url.split('?')[0] + "?initial_pool_size=1&max_pool_size=1&max_idle_pool_size=1")
  bot = Discord::Client.new(token: config.discord_token, client_id: config.discord_client_id)
  cache = Discord::Cache.new(bot)
  bot.cache = cache
  data[config.coinname_full.downcase] = Coin.new(db, bot, cache, auth)
end

get "/" do
  "Discord Tip Bot Website. WIP"
end

post "/webhook/:coin" do |env|
  headers = env.request.headers
  json = env.params.json
  coin = env.params.url["coin"]

  halt env, status_code: 403 unless headers["Authorization"]? == data[coin].dbl_auth

  unless json["type"] == "upvote"
    puts "Received test webhook call"
    halt env, status_code: 204
  end
  query = json["query"]?
  params = HTTP::Params.parse(query.lchop('?')) if query.is_a?(String)
  server = params["server"]? if params

  user = json["user"]
  halt env, status_code: 503 unless user.is_a?(String)
  user = user.to_u64

  if server
    data[coin].extend_premium(Premium::Kind::Guild, server.to_u64, 15.minutes)
    msg = "Thanks for voting. Extended premium of #{server} by 15 minutes"
  else
    data[coin].extend_premium(Premium::Kind::User, user, 1.hour)
    msg = "Thanks for voting. Extended your own personal global premium by 1 hour"
  end

  queue.push(Msg.new(coin, user, msg))
end

get "/qr/:link" do |env|
  link = env.params.url["link"]
  env.redirect("https://chart.googleapis.com/chart?cht=qr&chs=300x300&chld=L%7C1&chl=#{link}")
end

Kemal.run do |conf|
  conf.env = "production"
end
