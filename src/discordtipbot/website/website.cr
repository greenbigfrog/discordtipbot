require "kemal"
require "oauth2"
require "./middleware/*"

class Website
  def initialize(config : Config)
    redirect_uri = "http://127.0.0.1:3000/auth/callback"

    auth = DiscordOAuth2.new(ENV["CLIENT_ID"], ENV["CLIENT_SECRET"], redirect_uri)
    data = Data.new(config)

    get "/auth/" do |env|
      env.redirect(auth.authorize_uri("identify"))
    end

    get "/auth/callback" do |env|
      user = auth.get_user(env.params.query)
      res = data.get_user(user.id.to_u64)
      "#{user.username} has a balance of #{res.balance} #{config.coinname_short}, and has been using the bot since #{res.created_time}"
    end

    Kemal.run
  end
end
