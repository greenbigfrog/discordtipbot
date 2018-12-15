module Premium
  enum Kind
    User
    Guild
  end

  def clear_expired_premium
    sql = <<-SQL
    UPDATE config
    SET premium = false,
        premium_till = null,
        min_soak = null,
        min_soak_total = null,
        min_rain = null,
        min_rain_total = null,
        min_tip = null
    WHERE premium_till < (NOW() AT TIME ZONE 'utc')
    SQL
    @db.exec(sql)

    sql = <<-SQL
    UPDATE accounts
    SET premium = false,
    premium_till = null
    WHERE premium_till < (NOW() AT TIME ZONE 'utc')
    SQL
    @db.exec(sql)
  end

  def set_premium(kind : Kind, id : UInt64, till : Time)
    if kind == Kind::Guild
      @db.exec("UPDATE config SET premium = true, premium_till = $1 WHERE serverid = $2", till, id)
    else
      @db.exec(<<-SQL, id, till)
      INSERT INTO accounts(userid, premium, premium_till)
        VALUES ($1, true, $2)
      ON CONFLICT (userid) DO
        UPDATE SET premium = true, premium_till = $2
        WHERE accounts.userid = $1
      SQL
    end
  end

  def extend_premium(kind : Kind, id : UInt64, extend_by : Time::Span)
    current = status_premium(kind, id)
    if current
      till = current + extend_by
    else
      till = Time.utc_now + extend_by
    end
    set_premium(kind, id, till)
  end

  def status_premium(kind : Kind, id : UInt64)
    if kind == Kind::Guild
      @db.query_one?("SELECT premium_till FROM config WHERE serverid = $1", id, as: Time?)
    else
      @db.query_one?("SELECT premium_till FROM accounts WHERE userid = $1", id, as: Time?)
    end
  end
end
