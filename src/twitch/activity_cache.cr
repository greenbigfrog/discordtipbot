class ActivityCache
  # Container for a snowflake and the last time it was seen
  record Entry, id : Int64, seen : Time do
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

  @cache = {} of Int32 => Set(Entry)

  def initialize(@ttl : Time::Span)
  end

  # Marks the `user_id` as being observed in `room_id` at the given `time`
  def touch(room_id : Int32, user_id : Int64, time = Time.now)
    entry = Entry.new(user_id, time)
    return if entry.older_than?(@ttl)
    set = @cache[room_id] ||= Set(Entry).new
    set.delete(entry) if set.includes?(entry)
    set.add(entry)
  end

  # Only marks `user_id` as being observed in `room_id` if `time` is newer then latest entry
  def add_if_youngest(room_id : Int32, user_id : Int64, time : Time)
    entry = Entry.new(user_id, time)
    return if entry.older_than?(@ttl)
    set = @cache[room_id] ||= Set(Entry).new
    set.delete(entry) if set.any? { |x| x == entry && entry > x }
    set.add(entry)
  end

  # Returns the set of observed entries in the given `room_id` that have not expired.
  def resolve(room_id : Int32)
    prune(room_id) if @cache[room_id]?
  end

  def resolve_to_id(room_id : Int32)
    resolve(room_id).try &.map(&.id)
  end

  # Clears cached sets of expired entries for give room_id
  def prune(room_id : Int32)
    prune_set(@cache[room_id])
  end

  # Clears all cached set of expired entries
  def prune
    @cache.each do |room_id, set|
      prune_set(@cache[room_id])
    end
  end

  private def prune_set(set : Set(Entry))
    set.each do |entry|
      set.delete(entry) if entry.older_than?(@ttl)
    end
    set
  end
end
