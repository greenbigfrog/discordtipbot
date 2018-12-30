struct Withdrawal
  DB.mapping(
    id: Int64,
    pending: Bool,
    from_id: Int64,
    address: String,
    amount: BigDecimal,
    created_time: Time
  )
end
