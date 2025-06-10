#!/bin/bash
set -e

# Create database and user if they don't exist
echo "Setting up database..."
sudo -u postgres psql -c "SELECT 1 FROM pg_roles WHERE rolname='interview_user'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER interview_user WITH PASSWORD 'interview_password';"

sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw interview_db || \
    sudo -u postgres psql -c "CREATE DATABASE interview_db;"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE interview_db TO interview_user;"

# Apply schema
echo "Applying database schema..."
psql -U interview_user -d interview_db -f init.sql

echo "Database initialization completed successfully!" 