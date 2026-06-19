-- Example concept of registering database events to trigger agent percepts.
-- This can be implemented via pg_notify in PostgreSQL or custom UDFs in MySQL.
SELECT 'Notify BDI agent about database event' AS action;