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