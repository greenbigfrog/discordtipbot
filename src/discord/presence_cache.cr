# Stores all online users
class PresenceCache
  getter users : Set(UInt64) = Set(UInt64).new

  def delete(user : Discord::PartialUser)
    users.delete(user.id.to_u64)
  end

  def add(user : Discord::PartialUser)
    users.add(user.id.to_u64)
  end

  def online?(user : UInt64)
    users.includes?(user)
  end

  def handle_presence(payload : Array(Discord::Presence))
    payload.each do |x|
      handle_presence(x)
    end
  end

  def handle_presence(presence : Discord::Presence | Discord::Gateway::PresenceUpdatePayload)
    if presence.status == "online"
      add(presence.user)
    else
      delete(presence.user)
    end
  end
end
