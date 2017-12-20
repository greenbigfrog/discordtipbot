class TipBot
  @db : DB::Database

  def initialize(@config : Config, @log : Logger)
    @db = DB.open(@config.database_url)
  end

  def transfer(from : UInt64, to : UInt64, amount : Float32)
    @log.debug("Attempting to transfer #{amount} #{coinname_short} from #{from} to #{to}")
    sql = <<-SQL
        BEGIN;
        INSERT INTO transactions VALUES ('tip', #{from}, #{to}, #{amount});
        UPDATE accounts SET balance = ((SELECT count(amount) FROM transactions WHERE to_id = #{from}) - (SELECT count(amount) FROM transactions WHERE from_id = #{from})) WHERE userid = #{from};
        UPDATE accounts SET balance = ((SELECT count(amount) FROM transactions WHERE to_id = #{from}) - (SELECT count(amount) FROM transactions WHERE from_id = #{from})) WHERE userid = #{to};
        COMMIT;
        SQL
    @db.exec(sql)
  end
end
