struct Account
  DB.mapping(
    id: Int64,
    twitch_id: Int64,
    discord_id: Int64,
    created_time: Time
  )

  def ensure_discord_user(id : Int64)
    # TODO
  end
end
