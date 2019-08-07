require "kemal"
require "kemal-csrf"
require "kemal-session"
require "oauth2"
require "kemal-session-redis"

require "../data/**"

require "mosquito"
require "../jobs/deposit"

# require "big/json"
# require "pg"
# require "pg/pg_ext/big_decimal"
# require "./discordtipbot/config"
# require "./discordtipbot/premium"
# require "discordcr"

# TODO solve version conflict for
# add_handler CSRF.new

add_handler AuthHandler.new

Kemal::Session.config do |config|
  config.secret = ENV["SECRET"]
  config.timeout = 10.minutes
  config.engine = Kemal::Session::RedisEngine.new(host: "redis", port: 6379)
end

macro default_render(file)
  render("src/website/views/#{{{file}}}", "src/website/layouts/default.ecr")
end

class Website
  def self.run
    # redirect_uri = "http://127.0.0.1:3000/auth/callback/"
    redirect_uri = "https://d396a3cc.ngrok.io/auth/callback/"

    discord_auth = DiscordOAuth2.new(ENV["DISCORD_CLIENT_ID"], ENV["DISCORD_CLIENT_SECRET"], redirect_uri + "discord")
    twitch_auth = TwitchOAuth2.new(ENV["TWITCH_CLIENT_ID"], ENV["TWITCH_CLIENT_SECRET"], redirect_uri + "twitch")

    get "/" do |env|
      default_render("index.ecr")
    end

    get "/balance" do |env|
      user = env.session.bigint?("user_id")
      halt env, status_code: 403 unless user.is_a?(Int64)
      default_render("balance.ecr")
    end

    get "/deposit" do |env|
      user = env.session.bigint?("user_id")
      halt env, status_code: 403 unless user.is_a?(Int64)
      default_render("deposit.ecr")
    end

    get "/statistics" do |env|
      default_render("statistics.ecr")
    end

    get "/link_accounts" do |env|
      user = env.session.bigint?("user_id")
      halt env, status_code: 403 unless user.is_a?(Int64)
      default_render("link_accounts.ecr")
    end

    get "/admin" do |env|
      user = env.session.bigint?("user_id")
      halt env, status_code: 403 unless user.is_a?(Int64)

      # Admins only
      halt env, status_code: 500 unless user == 163607982473609216
      default_render("admin.cr")
    end

    # get "/redirect_auth" do |env|
    #   #       <<-HTML
    #   # <meta charset="UTF-8">
    #   # <meta http-equiv="refresh" content="1; url=http://127.0.0.1:3000/auth">

    #   # <script>
    #   # setTimeout(function(){
    #   #   window.location.href = "http://127.0.0.1:3000/auth"
    #   #   }, 5000);
    #   # </script>

    #   # <title>Page Redirection</title>

    #   # If you are not redirected automatically, follow the <a href='http://127.0.0.1:3000/auth'>link to example</a>
    #   # HTML
    # end

    get "/login" do |env|
      default_render("login.ecr")
    end

    get "/auth/:platform" do |env|
      case env.params.url["platform"]
      when "discord" then env.redirect(discord_auth.authorize_uri("identify"))
      when "twitch"  then env.redirect(twitch_auth.authorize_uri(""))
      else                halt env, status_code: 400
      end
    end

    get "/auth/callback/:platform" do |env|
      case env.params.url["platform"]
      when "twitch"
        user = twitch_auth.get_user_id_with_authorization_code(env.params.query)
        env.session.bigint("twitch", user)
        user_id = Data::Account.read(:twitch, user).id.to_i64
      when "discord"
        user = discord_auth.get_user_id_with_authorization_code(env.params.query)
        env.session.bigint("discord", user)
        user_id = Data::Account.read(:discord, user).id.to_i64
      else
        halt env, status_code: 400
      end

      env.session.bigint("user_id", user_id)

      env.redirect(env.session.string?("origin") || "/")
    end

    get "/logout" do |env|
      env.session.destroy
      env.redirect("/")
    end

    # walletnotify=curl --retry 10 -X POST http://website:3000/walletnotify?coin=0&tx=%s
    get "/walletnotify" do |env|
      coin = Data::Coin.read(env.params.query["coin"].to_i32)
      tx = env.params.query["tx"]

      Data::Deposit.create(tx, coin, :new)
    end

    # get "/docs" do |env|
    #   # env.redirect("/docs/index.html")
    #   env.redirect("https://github.com/greenbigfrog/discordtipbot/tree/master/docs")
    # end

    # post "/webhook/:coin" do |env|
    #   headers = env.request.headers
    #   json = env.params.json
    #   coin = env.params.url["coin"]

    #   halt env, status_code: 403 unless headers["Authorization"]? == data[coin].dbl_auth

    #   unless json["type"] == "upvote"
    #     puts "Received test webhook call"
    #     halt env, status_code: 204
    #   end
    #   query = json["query"]?
    #   params = HTTP::Params.parse(query.lchop('?')) if query.is_a?(String)
    #   server = params["server"]? if params

    #   user = json["user"]
    #   halt env, status_code: 503 unless user.is_a?(String)
    #   user = user.to_u64

    #   if server
    #     data[coin].extend_premium(Premium::Kind::Guild, server.to_u64, 30.minutes)
    #     msg = "Thanks for voting. Extended premium of #{server} by 15 **x2** minutes"
    #   else
    #     data[coin].extend_premium(Premium::Kind::User, user, 2.hour)
    #     msg = "Thanks for voting. Extended your own personal global premium by 1 **x2** hours"
    #   end

    #   if coin == "dogecoin"
    #     str = "1 DOGE"
    #     amount = 1
    #   else
    #     str = "5 ECA"
    #     amount = 5
    #   end
    #   data[coin].db.exec(SQL, user, amount)

    #   msg = "#{msg}\nAs a christmas present you've received twice as much premium time as well as #{str} courtesy of <@163607982473609216>"

    #   queue.push(Msg.new(coin, user, msg))
    # end

    get "/qr/:link" do |env|
      link = env.params.url["link"]
      env.redirect("https://chart.googleapis.com/chart?cht=qr&chs=300x300&chld=L%7C1&chl=#{link}")
    end

    Kemal.run
  end
end
