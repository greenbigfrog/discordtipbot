class Statistics
  @db : DB::Database
  @ttl : Time::Span

  getter transactions : Int64?
  getter total : BigDecimal?
  getter tips : BigDecimal?
  getter soaks : BigDecimal?
  getter rains : BigDecimal?
  getter last = Time.utc_now

  def initialize(@db)
    @ttl = 1.minutes
    update_statistics
  end

  private def update_statistics
    @transactions = @db.query_one("SELECT SUM(1) FROM transactions", as: Int64)
    @total = @db.query_one("SELECT SUM(amount) FROM transactions", as: BigDecimal)
    @tips = @db.query_one("SELECT SUM(amount) FROM transactions WHERE memo='tip'", as: BigDecimal)
    @soaks = @db.query_one("SELECT SUM(amount) FROM transactions WHERE memo='soak'", as: BigDecimal)
    @rains = @db.query_one("SELECT SUM(amount) FROM transactions WHERE memo='rain'", as: BigDecimal)
    @last = Time.utc_now
  end

  def update
    return unless Time.utc_now > @last + @ttl
    update_statistics
  end
end
