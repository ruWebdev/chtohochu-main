-- =============================================================================
-- ЧтоХочу — PostgreSQL initialization script
-- =============================================================================
-- Runs once on first container startup (docker-entrypoint-initdb.d).
-- The POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD env vars already create
-- the default database and user. This script grants additional privileges
-- and creates a test database for the test suite.
-- =============================================================================

-- Grant all privileges on the application database to the application user.
-- The database and user are created by the POSTGRES_DB / POSTGRES_USER env vars.
GRANT ALL PRIVILEGES ON DATABASE chtohochu TO chtohochu;

-- Create a dedicated testing database (Laravel uses it for php artisan test).
SELECT 'CREATE DATABASE chtohochu_testing'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'chtohochu_testing')\gexec
GRANT ALL PRIVILEGES ON DATABASE chtohochu_testing TO chtohochu;

-- Enable required extensions on both databases
\connect chtohochu
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\connect chtohochu_testing
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
