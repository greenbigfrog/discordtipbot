require "./enum"
require "./balance"

module Data
  enum UserType
    Discord
    Twitch

    def to_s(io)
      case self
      when Discord then io << "discord_id"
      when Twitch  then io << "twitch_id"
      end
    end
  end

  record TransferError, reason : String? = nil

  struct Account
    DB.mapping(
      id: Int32,
      twitch_id: Int64?,
      discord_id: Int64?,
      created_time: Time
    )

    def balance(coin : Coin)
      DATA.query_one?("SELECT balance FROM balances WHERE user_id = $1 AND coin = '#{coin}'", @id, as: BigDecimal) || BigDecimal.new(0)
    end

    def balances
      DATA.query_all?("SELECT * FROM balances WHERE id = $1", @id, as: Balance)
    end

    def update_balance(coin : Coin, db : DB::Connection)
      db.exec(<<-SQL, @id)
      INSERT INTO balances(coin, user_id, balance)
      SELECT
        '#{coin}',
        $1,
        (SELECT COALESCE( SUM (amount), 0) FROM transactions WHERE to_id = $1 AND coin = '#{coin}')
          - (SELECT COALESCE( SUM (amount), 0) FROM transactions WHERE from_id = $1 AND coin = '#{coin}')
      ON CONFLICT(user_id, coin) DO
      UPDATE SET balance = excluded.balance;
      SQL
    end

    def self.read(user_type : UserType, id : Int64) : self
      DATA.query_one("INSERT INTO accounts(#{user_type}) VALUES ($1) ON CONFLICT (#{user_type}) DO UPDATE SET #{user_type} = accounts.#{user_type} RETURNING *", id, as: self)
    end

    def transfer(amount : BigDecimal, coin : Coin, to : Account, memo : TransactionMemo, *, db : DB::Connection)
      db.exec("INSERT INTO transactions(coin, memo, from_id, to_id, amount) VALUES ($1, $2, $3, $4, $5)", coin, memo, @id, to.id, amount)
    end

    def self.transfer(amount : BigDecimal, coin : Coin, from : Int64, to : Int64, platform : UserType, memo : TransactionMemo)
      multi_transfer(amount, coin, from, [to], platform, memo)
    end

    def self.multi_transfer(total : BigDecimal, coin : Coin, from : Int64, to : Array(Int64), platform : UserType, memo : TransactionMemo)
      from = read(platform, from)

      return TransferError.new("insufficient balance") unless from.balance(coin) >= total

      to = to.map { |x| read(platform, x) }

      amount = BigDecimal.new((total / to.size).round(8))
      # TODO Round mode instead
      amount = amount.round(7) if amount * to.size > total

      DATA.transaction do |tx|
        begin
          to.each do |target|
            from.transfer(amount, coin, target, memo, db: tx.connection)
            target.update_balance(coin, db: tx.connection)
          end
          from.update_balance(coin, db: tx.connection)
        rescue ex : PQ::PQError
          puts ex.inspect_with_backtrace
          LOG.warn("Rolling back transfer of type #{memo} of #{total} #{coin} from #{from} to #{to}")
          tx.rollback
          return TransferError.new
        end
      end
    end
  end
end
