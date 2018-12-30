struct DepositAddress
  DB.mapping(
    id: Int64,
    active: Bool,
    userid: Int64,
    coin: Coin,
    address: String
  )
end
