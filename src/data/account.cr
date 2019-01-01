struct Data::Account
  DB.mapping(
    id: Int64,
    twitch_id: Int64,
    discord_id: Int64,
    created_time: Time
  )

  def self.ensure_discord_user(id : Int64)
    ensure_user("discord_id", id)
  end

  def self.ensure_twitch_user(id : Int64)
    ensure_user("twitch_id", id)
  end

  private def self.ensure_user(field : String, id : Int64)
    DB.exec("INSERT INTO accounts(#{field}) VALUES ($1) ON CONFLICT DO NOTHING", id)
  end
end
