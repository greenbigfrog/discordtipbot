
CREATE TABLE accounts (
       id bigint PRIMARY KEY,
       twitch_id bigint,
       discord_id bigint,

       created_time timestamptz NOT NULL DEFAULT now()
);

INSERT INTO accounts (id) VALUES (0);

CREATE TYPE coin_type AS ENUM('doge', 'eca');

CREATE TABLE balances (
       id serial PRIMARY KEY,
       user_id bigint NOT NULL,
       coin coin_type NOT NULL,
       balance numeric(64, 8) NOT NULL CONSTRAINT positive_amount CHECK (balance > 0)
);

CREATE TYPE transaction_memo AS ENUM('deposit', 'tip', 'soak', 'rain', 'withdrawal', 'sponsored');
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

CREATE TYPE deposit_status AS ENUM('new', 'credited', 'never');
CREATE TABLE deposits (
       txhash text PRIMARY KEY,
       status deposit_status NOT NULL,
       user_id bigint,

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
	user_id bigint NOT NULL REFERENCES accounts(id),

	amount numeric(64, 8) CONSTRAINT positive_amount CHECK (amount > 0),
	created_time timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX offsite_user_id ON offsite USING btree (user_id);

CREATE TABLE offsite_addresses (
	id serial PRIMARY KEY,

	address text NOT NULL,

	user_id bigint NOT NULL REFERENCES accounts(id),
	created_time timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX offsite_addresses_user_id ON offsite_addresses USING btree(user_id);
CREATE INDEX offsite_addresses_address ON offsite_addresses USING btree(address);
