struct Data::Balance
  DB.mapping(
    id: Int64,
    userid: Int64,
    coin: Coin,
    balance: BigDecimal
  )
end
