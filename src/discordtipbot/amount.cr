module Amount
  def parse_amount(msg, string) : BigDecimal?
    if string == "all"
      # @tip.get_balance(msg.author.id.to_u64)
      get_balance(msg)
    elsif string == "half"
      BigDecimal.new(get_balance(msg) / 2).round(8)
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

  private def get_balance(msg)
    Data::Account.read(:discord, msg.author.id.to_u64.to_i64).balance(:doge)
  end
end
