ALTER TABLE config ADD min_soak numeric(64, 8) DEFAULT 1;
ALTER TABLE config ADD min_soak_total numeric(64, 8) DEFAULT 1;
ALTER TABLE config ADD min_rain numeric(64, 8) DEFAULT 1;
ALTER TABLE config ADD min_rain_total numeric(64, 8) DEFAULT 1;
ALTER TABLE config ADD min_tip numeric(64, 8) DEFAULT 1;