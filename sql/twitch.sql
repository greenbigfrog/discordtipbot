CREATE TABLE channels (
    id serial PRIMARY KEY,
    name text NOT NULL UNIQUE,

    created_at timestamptz NOT NULL DEFAULT now()
);