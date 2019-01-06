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
    DONATION
    WITHDRAWAL
    SPONSORED
    LUCKY
  end

  enum DepositStatus
    NEW
    CREDITED
    NEVER
  end
end
