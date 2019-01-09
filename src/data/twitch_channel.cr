module Data
  struct TwitchChannel
    DB.mapping(
      id: Int32,
      name: String,
      created_at: Time
    )

    # Adds a new channel to join the next time
    def self.create(name : String)
      DATA.exec(<<-SQL, name)
      INSERT INTO channels(name) VALUES ($1)
        ON CONFLICT DO NOTHING
      SQL
    end

    # Gets a Set of all channels
    def self.read
      DATA.query_all("SELECT * FROM channels", as: self)
    end

    def self.read_names
      DATA.query_all("SELECT name FROM channels", as: String)
    end

    # Deletes a channel
    def self.delete(name : String)
      DATA.exec("DELETE FROM channels WHERE name = $1", name)
    end
  end
end
