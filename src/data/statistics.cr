struct Data::Statistics
  DB.mapping(
    transaction_count: Int64?,
    transaction_sum: BigDecimal?,
    total: BigDecimal?,
    tip_sum: BigDecimal?,
    soak_sum: BigDecimal?,
    rain_sum: BigDecimal?
  )

  @@ttl : Time::Span = 10.minutes

  class_getter last = Time.utc_now

  def self.read
    DATA.query_one("SELECT * FROM statistics", as: Statistics)
  end

  def self.update
    now = Time.utc_now
    return unless now > @@last + @@ttl
    DATA.exec("REFRESH MATERIALIZED VIEW statistics")
    @@last = now
  end
end
