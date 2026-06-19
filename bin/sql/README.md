# Client BDI Coprocessor - Sql

SQL client wrapper or integration concept for updating agent beliefs from database triggers.

## Protocol Interaction Example

```sql
-- Example concept of registering database events to trigger agent percepts.
-- This can be implemented via pg_notify in PostgreSQL or custom UDFs in MySQL.
SELECT 'Notify BDI agent about database event' AS action;
```
