struct Statistics
  DB.mapping({
    transactions: {type: Int64?, key: "transaction_count"},
    total:        {type: BigDecimal?, key: "transaction_sum"},
    tips:         {type: BigDecimal?, key: "tip_sum"},
    soaks:        {type: BigDecimal?, key: "soak_sum"},
    rains:        {type: BigDecimal?, key: "rain_sum"},
  })

  @@ttl : Time::Span = 10.minutes

  class_getter last = Time.utc_now

  def self.read
    Statistics.from_rs(DATA.query("SELECT * FROM statistics")).last
  end

  def self.update
    return unless Time.utc_now > @@last + @@ttl
    DATA.exec("REFRESH MATERIALIZED VIEW statistics")
    @@last = Time.utc_now
  end
end
