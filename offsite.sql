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
