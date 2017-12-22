DROP TABLE IF EXISTS transactions, accounts;

/*
 *   DROP TABLE IF EXISTS coin_transactions;
 *
 *   CREATE TABLE coin_transactions (
 *   txid text PRIMARY KEY,
 *   status text NOT NULL DEFAULT "unchecked",
 *   amount float8,
 *   credited_userid bigint FOREIGN KEY REFERENCES accounts(userid),
 *
 *   created_time timestamptz NOT NULL DEFAULT now(),
 *   credited_at timestamptz
 *   );
 */

CREATE TABLE accounts (
       userid bigint PRIMARY KEY,
       balance float8 NOT NULL DEFAULT 0 CONSTRAINT positive_account_balance CHECK (balance >= 0),
       address text,

       created_time timestamptz NOT NULL DEFAULT now()
);

INSERT INTO accounts (userid) VALUES (0);

CREATE TABLE transactions (
       id serial PRIMARY KEY,
       memo text NOT NULL,
       from_id bigint NOT NULL REFERENCES accounts(userid),
       to_id bigint NOT NULL REFERENCES accounts(userid),
       amount float8 NOT NULL CONSTRAINT positive_amount CHECK (amount > 0),

       time timestamptz NOT NULL DEFAULT now()
)

