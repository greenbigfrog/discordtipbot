struct Data::Balance
  DB.mapping(
    account_id: Int64,
    coin: Int32,
    balance: BigDecimal
  )
end
