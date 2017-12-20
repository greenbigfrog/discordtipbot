DROP TABLE IF EXISTS coin_transactions, transactions, accounts;

/*
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
       balance float8 NOT NULL DEFAULT 0,
       address text,

       created_time timestamptz NOT NULL DEFAULT now()
);

INSERT INTO accounts VALUES userid=00000000;

CREATE TABLE transactions (
       id serial PRIMARY KEY,
       memo text NOT NULL,
       from_id bigint NOT NULL FOREIGN KEY REFERENCES accounts(userid),
       to_id bigint NOT NULL FOREIGN KEY REFERENCES accounts(userid),
       amount float8 NOT NULL,

       time timestamptz NOT NULL DEFAULT now()
)

