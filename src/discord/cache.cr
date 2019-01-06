class Discord::Cache
  setter users
  setter channels
  setter guilds
  setter members
  setter roles
  setter dm_channels
  setter guild_roles
  setter guild_channels

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
