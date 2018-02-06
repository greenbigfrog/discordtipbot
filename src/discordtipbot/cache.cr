class Cache
  # Container for a snowflake and the last time it was seen
  record Entry, id : UInt64, seen : Time do
    def ==(other)
      id == other.id
    end

    def hash
      id.hash
    end

    def older_than?(age : Time::Span)
      Time.now > seen + age
    end
  end

  @cache = {} of UInt64 => Set(Entry)

  def initialize(@ttl : Time::Span)
  end

  # Marks the `user_id` as being observed in `channel_id` at the given `time`
  def touch(channel_id : UInt64, user_id : UInt64, time = Time.now)
    entry = Entry.new(user_id, time)
    set = @cache[channel_id] ||= Set(Entry).new
    set.delete(entry) if set.includes?(entry)
    set.add(entry)
  end

  # Returns the set of observed entries in the given `channel_id` that have not expired.
  def resolve(channel_id : UInt64)
    set = @cache[channel_id]
    prune_set(set)
    set
  end

  # Clears all cached sets of expired entries
  def prune
    @cache.each do |_channel_id, set|
      prune_set(set)
    end
  end

  private def prune_set(set : Set(Entry))
    set.each do |entry|
      set.delete(entry) if entry.older_than?(@ttl)
    end
  end
end
