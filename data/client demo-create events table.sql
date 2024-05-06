-- SQL script to prepare data for client demo

-- Set initial state
DROP SCHEMA demo CASCADE;

-- creates demo schema and EVENTS table
CREATE SCHEMA demo;
CREATE TABLE demo.events
    (id int,
    timestamp varchar,
    source_id varchar,
    data_point varchar,
    data_unit varchar,
    data_type varchar,
    data varchar);

-- Copy data from a CSV file into the new table
-- COPY command is not standard SQL, but is supported
-- by many servers including PostgreSQL and DB2
copy demo.events FROM './demo.events.csv' WITH (FORMAT csv, DELIMITER ',', HEADER TRUE);

-- Sample query to test table contents
-- select events coming from VSU devices (representing package sensors)
SELECT * from demo.events WHERE source_id LIKE 'vsu-%'
