struct Data::Twitch::Channel
  DB.mapping(
    id: Int32,
    coin: Int32,

    name: String,

    contacted: Bool,

    created_time: Time,

    prefix: String?,

    soak: Bool,
    rain: Bool,

    min_soak: BigDecimal?,
    min_soak_total: BigDecimal?,

    min_rain: BigDecimal?,
    min_rain_total: BigDecimal?,

    min_tip: BigDecimal?,
    min_lucky: BigDecimal?
  )
end
