require "kemal"
require "kemal-csrf"
require "kemal-session"
require "oauth2"
require "./middleware/*"

# TODO solve version conflict for
# add_handler CSRF.new

Kemal::Session.config do |config|
  config.secret = ENV["SECRET"]
  config.timeout = 10.minutes
  # TODO use redis: config.engine = redis
end

class Website
  def initialize(config : Config)
    redirect_uri = "http://127.0.0.1:3000/auth/callback"

    auth = DiscordOAuth2.new(ENV["CLIENT_ID"], ENV["CLIENT_SECRET"], redirect_uri)
    data = Data.new(config)

    get "/" do
      render("src/discordtipbot/website/views/main.ecr", "src/discordtipbot/website/views/layouts/layout.ecr")
    end

    get "/redirect_auth" do |env|
      <<-HTML
<meta charset="UTF-8">
<meta http-equiv="refresh" content="1; url=http://127.0.0.1:3000/auth">
 
<script>
setTimeout(function(){
  window.location.href = "http://127.0.0.1:3000/auth"
  }, 2000);
</script>
 
<title>Page Redirection</title>
 
If you are not redirected automatically, follow the <a href='http://127.0.0.1:3000/auth'>link to example</a>
HTML
    end

    get "/auth" do |env|
      env.redirect(auth.authorize_uri("identify"))
    end

    get "/auth/callback" do |env|
      access_token = auth.get_access_token(env.params.query)
      env.session.string("access_token", access_token.access_token)

      env.redirect(env.session.string?("origin") || "/")
    end

    get "/balance" do |env|
      token = env.session.string?("access_token")
      env.session.string("origin", env.request.resource)
      env.redirect("/redirect_auth") unless token.is_a?(String)
      if token
        user = auth.get_user(token)
        res = data.get_user(user.id.to_u64)
        "#{user.username} has a balance of #{res.balance} #{config.coinname_short}, and has been using the bot since #{res.created_time}"
      end
    end

    get "/logout" do |env|
      env.session.destroy
      "You have been logged out"
    end

    Kemal.run
  end
end
