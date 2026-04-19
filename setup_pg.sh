#!/bin/bash
set -e

sudo apt-get install -y postgresql postgresql-contrib
sudo service postgresql start
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'asendulf53';"

# Install pgvector from source
sudo apt-get install -y git build-essential postgresql-server-dev-all
git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git /tmp/pgvector
cd /tmp/pgvector && make && sudo make install

sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS vector;"

echo "Done. pgvector ready."

# Python virtual environment
python3 -m venv /home/mike/probono/.venv
echo "Run: source .venv/bin/activate"
