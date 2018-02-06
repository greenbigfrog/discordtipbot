require "spec"
require "../src/discordtipbot/activity_cache.cr"

describe ActivityCache::Entry do
  it "compares with another entry with the same ID" do
    result = ActivityCache::Entry.new(0_u64, Time.now) == ActivityCache::Entry.new(0_u64, Time.now + 1.second)
    result.should be_true
  end

  it "can be used properly in a set" do
    set = Set(ActivityCache::Entry).new
    set.add ActivityCache::Entry.new(0_u64, Time.now)
    set.add ActivityCache::Entry.new(0_u64, Time.now)
    set.add ActivityCache::Entry.new(1_u64, Time.now)
    set.size.should eq 2
  end

  describe "#older_than?" do
    it "compares the current time to age" do
      time = Time.now
      ActivityCache::Entry.new(0_u64, time).older_than?(1.second).should be_false
      ActivityCache::Entry.new(0_u64, time - 2.seconds).older_than?(1.second).should be_true
    end
  end
end

describe ActivityCache do
  it "initializes" do
    ActivityCache.new(1.second)
  end

  describe "#touch" do
    it "makes a new entry" do
      cache = ActivityCache.new(1.second)
      cache.touch(0_u64, 1_u64).should be_a Set(ActivityCache::Entry)
    end

    it "stores the most recent entry" do
      cache = ActivityCache.new(2.seconds)
      time = Time.now
      cache.touch(0_u64, 1_u64, time)
      set = cache.touch(0_u64, 1_u64, time + 1.seconds)
      set.try &.first.seen.should eq time + 1.seconds
    end
  end

  describe "#resolve" do
    it "returns a set with all non-expired entries" do
      cache = ActivityCache.new(1.second)
      time = Time.now
      cache.touch(0_u64, 1_u64, time)
      cache.touch(0_u64, 1_u64, time + 2.seconds)
      cache.resolve(0_u64).try &.size.should eq 1
    end
  end

  describe "#prune" do
    it "removes all expired entries across all keys" do
      cache = ActivityCache.new(1.second)
      time = Time.now
      cache.touch(0_u64, 1_u64, time - 2.seconds)
      cache.touch(1_u64, 1_u64, time - 2.seconds)
      cache.prune
      cache.resolve(0_u64).try &.empty?.should be_true
      cache.resolve(1_u64).try &.empty?.should be_true
    end
  end
end
