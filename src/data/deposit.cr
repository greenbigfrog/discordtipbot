struct Data::Deposit
  DB.mapping(
    txhash: String,
    status: DepositStatus,
    user_id: BigInt,
    created_time: Time
  )
end
