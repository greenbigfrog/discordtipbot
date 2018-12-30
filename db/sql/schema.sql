/*
DROP TABLE IF EXISTS transactions, accounts, config, coin_transactions;
*/

CREATE TABLE accounts (
       userid bigint PRIMARY KEY,
       balance numeric(64, 8) NOT NULL DEFAULT 0 CONSTRAINT positive_account_balance CHECK (balance >= 0),
       address text,
       
       premium boolean DEFAULT false,
       premium_till timestamp,

       created_time timestamptz NOT NULL DEFAULT now()
);

INSERT INTO accounts (userid) VALUES (0);

CREATE TYPE transaction_memo AS ENUM('deposit', 'tip', 'soak', 'rain', 'withdrawal', 'sponsored');
CREATE TYPE coin_type AS ENUM('doge', 'eca');

CREATE TABLE transactions (
       id serial PRIMARY KEY,
       coin coin_type NOT NULL,
       memo transaction_memo NOT NULL,
       from_id bigint NOT NULL REFERENCES accounts(id),
       to_id bigint NOT NULL REFERENCES accounts(id),
       amount numeric(64, 8) NOT NULL CONSTRAINT positive_amount CHECK (amount > 0),

       address text,
       coin_transaction_id text,

       time timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE config (
       serverid bigint PRIMARY KEY,

       contacted boolean DEFAULT false,
       prefix text,
       premium boolean DEFAULT false,
       premium_till timestamp,

       mention boolean DEFAULT false,
       soak boolean DEFAULT false,
       min_soak numeric(64, 8),
       min_soak_total numeric(64, 8),
       rain boolean DEFAULT false,
       min_rain_total numeric(64, 8),
       min_rain numeric(64, 8),
       min_tip numeric(64, 8),

       created_time timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE coin_transactions (
       txhash text PRIMARY KEY,
       status text NOT NULL,

       created_time timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE withdrawals (
       id serial PRIMARY KEY,
       pending boolean DEFAULT true,
       from_id bigint NOT NULL REFERENCES accounts(id),
       address text NOT NULL,
       amount numeric(64, 8) CONSTRAINT positive_amount CHECK (amount > 0),

       created_time timestamptz NOT NULL DEFAULT now()
);

CREATE MATERIALIZED VIEW statistics AS (
       SELECT
              (SELECT SUM(1) FROM transactions) AS transaction_count,
              (SELECT SUM(amount) FROM transactions) AS transaction_sum,
              (SELECT SUM(amount) FROM transactions WHERE memo='tip') AS tip_sum,
              (SELECT SUM(amount) FROM transactions WHERE memo='soak') AS soak_sum,
              (SELECT SUM(amount) FROM transactions WHERE memo='rain') as rain_sum
);

CREATE TYPE offsite_memo AS ENUM ('deposit', 'withdrawal');

CREATE TABLE offsite (
	id serial PRIMARY KEY,

	memo offsite_memo NOT NULL,
	userid bigint NOT NULL REFERENCES accounts(userid),

	amount numeric(64, 8) CONSTRAINT positive_amount CHECK (amount > 0),
	created_time timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX offsite_user_id ON offsite USING btree (userid);

CREATE TABLE offsite_addresses (
	id serial PRIMARY KEY,

	address text NOT NULL,

	userid bigint NOT NULL REFERENCES accounts(userid),
	created_time timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX offsite_addresses_user_id ON offsite_addresses USING btree(userid);
CREATE INDEX offsite_addresses_address ON offsite_addresses USING btree(address);
