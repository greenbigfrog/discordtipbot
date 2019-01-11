struct Data::Guild
  DB.mapping(
    id: Int64,
    contacted: Bool,
    created_time: Time
  )

  def self.read(id : Int64)
    DATA.query_one?("SELECT * FROM guilds WHERE id = $1", id, as: self)
  end

  # returns `true` if guild doesn't exist in db and it has been inserted
  def self.new?(id : Int64)
  end
end
