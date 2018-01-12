DROP TABLE IF EXISTS transactions, accounts, config;

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
);

CREATE TABLE config (
       serverid bigint PRIMARY KEY,

       contacted boolean DEFAULT false,

       mention boolean DEFAULT false,
       soak boolean DEFAULT false,
       rain boolean DEFAULT false,

       created_time timestamptz NOT NULL DEFAULT now()
)

