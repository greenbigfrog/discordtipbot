require "./converters"

module Twitch
  struct UserList
    JSON.mapping({data: Array(User)})
  end

  struct User
    JSON.mapping({
      id:           {type: UInt64, converter: ID::Converter},
      login:        String,
      display_name: String,
    })
  end
end

module ID::Converter
  def self.from_json(value : JSON::PullParser) : UInt64
    UInt64.new(value.read_string)
  end
end
