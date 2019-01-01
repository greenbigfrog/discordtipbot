module Data
  enum Coin
    DOGE
    ECA
  end

  enum TransactionMemo
    DEPOSIT
    TIP
    SOAK
    RAIN
    WITHDRAWAL
    SPONSORED
  end

  enum DepositStatus
    NEW
    CREDITED
    NEVER
  end
end