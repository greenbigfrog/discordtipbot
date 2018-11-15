CREATE MATERIALIZED VIEW statistics AS (
       SELECT
                (SELECT SUM(1) FROM transactions) AS transaction_count,
                (SELECT SUM(amount) FROM transactions) AS transaction_sum,
                (SELECT SUM(amount) FROM transactions WHERE memo='tip') AS tip_sum,
                (SELECT SUM(amount) FROM transactions WHERE memo='soak') AS soak_sum,
                (SELECT SUM(amount) FROM transactions WHERE memo='rain') as rain_sum
);
