class Amount
  def initialize(@tip : TipBot)
  end

  def call(payload, ctx)
    yield
  end

  def amount(msg, string) : BigDecimal?
    if string == "all"
      @tip.get_balance(msg.author.id.to_u64)
    elsif string == "half"
      BigDecimal.new(@tip.get_balance(msg.author.id.to_u64) / 2).round(8)
    elsif string == "rand"
      BigDecimal.new(Random.rand(1..6))
    elsif string == "bigrand"
      BigDecimal.new(Random.rand(1..42))
    elsif m = /(?<amount>^[0-9,\.]+)/.match(string)
      begin
        return nil unless string == m["amount"]
        BigDecimal.new(m["amount"]).round(8)
      rescue InvalidBigDecimalException
      end
    end
  end
end
