require "./rest"
require "./mappings/*"

module Twitch
  class Client
    include REST

    getter token : String
    getter client_id : String

    def initialize(@token, @client_id)
      @token = "Bearer" + @token
    end

    def user?(name : String)
      begin
        true if get_user_by_login(name)
      rescue EMPTY_RESULT
        false
      end
    end

    def user(name : String)
      get_user_by_login(name)
    end

    def user(id : Int64)
      get_user_by_id(id)
    end
  end
end
