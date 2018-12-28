module Discord
  class Cache
    setter users
    setter channels
    setter guilds
    setter members
    setter roles
    setter dm_channels
    setter guild_roles
    setter guild_channels
  end

  class SharedCache
    def initialize
      @users = Hash(UInt64, User).new
      @channels = Hash(UInt64, Channel).new
      @guilds = Hash(UInt64, Guild).new
      @members = Hash(UInt64, Hash(UInt64, GuildMember)).new
      @roles = Hash(UInt64, Role).new

      @dm_channels = Hash(UInt64, UInt64).new

      @guild_roles = Hash(UInt64, Array(UInt64)).new
      @guild_channels = Hash(UInt64, Array(UInt64)).new
    end

    def bind(cache : Discord::Cache)
      cache.guilds = @guilds
      cache.channels = @channels
      cache.users = @users
      cache.members = @members
      cache.roles = @roles
      cache.dm_channels = @dm_channels
      cache.guild_roles = @guild_roles
      cache.guild_channels = @guild_channels
    end
  end
end
