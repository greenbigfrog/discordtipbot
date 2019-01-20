require "./enum"

struct Data::Transaction
  DB.mapping(
    id: Int32,

    coin: Int32,

    # memo: Data::TransactionMemo,

    amount: BigDecimal,

    account_id: Int32,

    address: String?,
    coin_transaction_id: String?,

    time: Time
  )

  # def self.read(id : Int64)
  #   DATA.query_one?("SELECT * FROM transactions WHERE id = $1", id, as: self)
  # end

  def self.read_amount(id : Int64)
    DATA.query_one?("SELECT amount FROM transactions WHERE id = $1", id, as: BigDecimal)
  end

  def self.update_fee(id : Int64, adjust_by : BigDecimal)
    amount = read_amount(id).not_nil!
    new_amount = amount - adjust_by
    DATA.exec("UPDATE transactions SET amount = $1 WHERE id = $2", new_amount, id)
  end
end
