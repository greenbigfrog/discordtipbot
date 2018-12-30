struct Transaction
  enum TransactionMemo
    DEPOSIT
    TIP
    SOAK
    RAIN
    WITHDRAWAL
    SPONSORED
  end

  DB.mapping(
    id: Int64,

    coin: Coin,

    memo: TransactionMemo,

    from_id: Int64,
    to_id: Int64,

    amount: BigDecimal,

    address: String?,
    coin_transaction_id: String?,

    time: Time
  )
end
