
CREATE TABLE accounts (
       id serial PRIMARY KEY,
       active boolean NOT NULL DEFAULT true,
       twitch_id bigint UNIQUE,
       discord_id bigint UNIQUE,

       created_time timestamptz NOT NULL DEFAULT now()
);

INSERT INTO accounts (id) VALUES (0);

CREATE TYPE coin_type AS ENUM('DOGE', 'ECA');

CREATE TABLE balances (
       account_id bigint NOT NULL REFERENCES accounts(id),
       coin coin_type NOT NULL,
       balance numeric(64, 8) NOT NULL CONSTRAINT positive_amount CHECK (balance >= 0),
       PRIMARY KEY (account_id, coin)
);

CREATE TYPE transaction_memo AS ENUM('DEPOSIT', 'TIP', 'SOAK', 'RAIN', 'WITHDRAWAL', 'SPONSORED', 'DONATION', 'IMPORT_FOR_LINK');
CREATE TABLE transactions (
       id serial PRIMARY KEY,
       coin coin_type NOT NULL,
       memo transaction_memo NOT NULL,
       account_id bigint NOT NULL REFERENCES accounts(id),
       amount numeric(64, 8) NOT NULL,

       address text,
       coin_transaction_id text,

       time timestamptz NOT NULL DEFAULT now()
);

CREATE TYPE deposit_status AS ENUM('NEW', 'CREDITED', 'NEVER');
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
              (SELECT SUM(amount) FROM transactions WHERE memo='TIP') AS tip_sum,
              (SELECT SUM(amount) FROM transactions WHERE memo='SOAK') AS soak_sum,
              (SELECT SUM(amount) FROM transactions WHERE memo='RAIN') as rain_sum
);


CREATE TYPE offsite_memo AS ENUM ('DEPOSIT', 'WITHDRAWAL');
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
