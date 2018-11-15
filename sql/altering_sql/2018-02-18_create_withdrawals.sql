CREATE TYPE withdrawal_status AS ENUM ('pending', 'processed');

CREATE TABLE withdrawals (
       id serial PRIMARY KEY,
       status withdrawal_status DEFAULT 'pending',
       from_id bigint NOT NULL REFERENCES accounts(userid),
       address text NOT NULL,
       amount numeric(64, 8) CONSTRAINT positive_amount CHECK (amount > 0),

       created_time timestamptz NOT NULL DEFAULT now()
)
