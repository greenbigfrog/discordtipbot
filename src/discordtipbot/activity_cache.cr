class ActivityCache
  # Container for a snowflake and the last time it was seen
  record Entry, id : UInt64, seen : Time do
    def ==(other)
      id == other.id
    end

    def <(other)
      seen < other.seen
    end

    def >(other)
      seen > other.seen
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
    return if entry.older_than?(@ttl)
    set = @cache[channel_id] ||= Set(Entry).new
    set.delete(entry) if set.includes?(entry)
    set.add(entry)
  end

  # Only marks `user_id` as being observed in `channel_id` if `time` is newer then latest entry
  def add_if_youngest(channel_id : UInt64, user_id : UInt64, time : Time)
    entry = Entry.new(user_id, time)
    return if entry.older_than?(@ttl)
    set = @cache[channel_id] ||= Set(Entry).new
    set.delete(entry) if set.any? { |x| x == entry && entry > x }
    set.add(entry)
  end

  # Returns the set of observed entries in the given `channel_id` that have not expired.
  def resolve(channel_id : UInt64)
    prune(channel_id) if @cache[channel_id]?
  end

  def resolve_to_id(channel_id : UInt64)
    resolve(channel_id).try &.map(&.id)
  end

  # Clears cached sets of expired entries for give channel_id
  def prune(channel_id : UInt64)
    prune_set(@cache[channel_id])
  end

  # Clears all cached set of expired entries
  def prune
    @cache.each do |channel_id, _|
      prune_set(@cache[channel_id])
    end
  end

  private def prune_set(set : Set(Entry))
    set.each do |entry|
      set.delete(entry) if entry.older_than?(@ttl)
    end
    set
  end
end
