ALTER TABLE config ADD min_soak numeric(64, 8);
ALTER TABLE config ADD min_soak_total numeric(64, 8);
ALTER TABLE config ADD min_rain numeric(64, 8);
ALTER TABLE config ADD min_rain_total numeric(64, 8);
ALTER TABLE config ADD min_tip numeric(64, 8);
ALTER TABLE config ADD prefix text;
ALTER TABLE config ADD premium boolean DEFAULT false;
ALTER TABLE config ADD premium_till timestamp;