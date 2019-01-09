require "http"
require "json"
require "./mappings/*"

module Twitch
  # Mixin for interacting with Twitch's REST API
  module REST
    SSL_CONTEXT = OpenSSL::SSL::Context::Client.new
    API_BASE    = "https://api.twitch.tv/helix"

    EMPTY_RESULT = Exception.new("Empty Result")

    # Executes an HTTP request against the API_BASE url
    def request(method : String, route : String, version = "5", headers = HTTP::Headers.new, body : String? = nil)
      headers["Authorization"] = @token
      headers["Client-ID"] = @client_id

      response = HTTP::Client.exec(
        method,
        API_BASE + route,
        headers,
        tls: SSL_CONTEXT
      )

      response.body
    end

    def get_user_by_login(login : String)
      response = request(
        "GET",
        "/users?login=" + login
      )

      list = UserList.from_json(response)
      raise EMPTY_RESULT if list.data.empty?

      list.data.first
    end

    def get_user_by_id(id : Int64)
      response = request(
        "GET",
        "/users?id=" + id.to_s
      )

      list = UserList.from_json(response)
      raise EMPTY_RESULT if list.data.empty?

      list.data.first
    end
  end
end
