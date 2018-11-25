class PermissionMiddleware
  include DiscordMiddleware::CachedRoutes
  # The permissions a user has in a direct message
  DM_PERMISSIONS = Discord::Permissions.flags(
    ManageChannels,
    AddReactions,
    ReadMessages,
    SendMessages,
    SendTTSMessages,
    EmbedLinks,
    AttachFiles,
    ReadMessageHistory,
    MentionEveryone,
    UseExternalEmojis,
    Connect,
    Speak,
    UseVAD
  )

  def initialize(@permissions : Discord::Permissions)
  end

  # Returns the member's base permissions on the guild
  # :nodoc:
  def base_permissions_for(member, in guild)
    return Discord::Permissions::All if guild.owner_id == member.user.id

    perms = Discord::Permissions::None

    guild.roles.each do |role|
      if member.roles.includes?(role.id) || role.id == guild.id
        perms |= role.permissions
      end
    end

    return Discord::Permissions::All if perms.administrator?

    perms
  end

  # Returns the applicable overwrite permissions
  # :nodoc:
  def overwrites_for(member, in channel, with base_permissions)
    return Discord::Permissions::All if base_permissions.administrator?

    if overwrites = channel.permission_overwrites
      # @everyone overwrite
      overwrites.find { |o| o.id == channel.guild_id && o.type == "role" }.try do |o|
        base_permissions &= ~o.deny
        base_permissions |= o.allow
      end

      # Role overwrites
      allow = Discord::Permissions::None
      deny = Discord::Permissions::None
      overwrites.each do |o|
        if member.roles.includes?(o.id) && o.type == "role"
          allow |= o.allow
          deny |= o.deny
        end
      end

      base_permissions &= ~deny
      base_permissions |= allow

      # User overwrite
      overwrites.find { |o| o.id == member.user.id && o.type == "user" }.try do |o|
        base_permissions &= ~o.deny
        base_permissions |= o.allow
      end
    end

    base_permissions
  end

  def call(payload : Discord::Message, context : Discord::Context)
    client = context[Discord::Client]
    channel = get_channel(client, payload.channel_id.to_u64)
    user_id = payload.author.id.to_u64

    if guild_id = channel.guild_id.try &.to_u64
      guild = get_guild(client, guild_id)

      # Pass if the user is the owner of the guild
      return yield if guild.owner_id == user_id

      member = get_member(client, guild_id, user_id)
      permissions = base_permissions_for(member, in: guild)

      # Pass if user has an administrator role
      return yield if permissions.administrator?

      # Evaluate channel overwrites
      overwrites = overwrites_for(member, in: channel, with: permissions)

      return yield if (@permissions & overwrites) == @permissions
      client.create_message(channel.id, "Permission denied. Must have #{@permissions}")
    else
      return yield if (@permissions & DM_PERMISSIONS) == @permissions
      client.create_message(channel.id, "Permission denied. Must have #{@permissions}")
    end
  end
end
