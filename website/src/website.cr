require "kemal"
require "discordcr"
require "oauth2"
require "./middleware/*"

redirect_uri = "http://127.0.0.1:3000/auth/callback"

auth = DiscordOAuth2.new(ENV["CLIENT_ID"], ENV["CLIENT_SECRET"], redirect_uri)

get "/auth/" do |env|
  env.redirect(auth.authorize_uri("identify"))
end

get "/auth/callback" do |env|
  user = auth.get_user(env.params.query)
  pp user
end

Kemal.run
