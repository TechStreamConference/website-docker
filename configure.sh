#! /usr/bin/env bash

set -e

if [ -d "data" ]; then
    read -p "Do you want the 'data' folder to be deleted (recommended for initial setup)? (y/N): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        sudo rm -rf data
        echo "Folder 'data' deleted."
    else
        echo "Folder 'data' not deleted. Proceeding..."
    fi
else
    echo "Folder 'data' does not exist."
fi

echo "Copying configuration files..."
find container -type f -name '*.sample' -exec sh -c 'for f; do cp "$f" "${f%.sample}"; done' sh {} +

echo "Building and starting the containers..."
docker compose up -d --build --force-recreate

docker compose exec test_conf_backend bash -c "composer install --ignore-platform-reqs"

# Especially when using WSL2, it may take some time until the containers are up and running.
# Therefore, we wait until the database is ready before running the migrations to prevent errors.
echo "Waiting for database to be ready..."
until docker compose exec test_conf_backend bash -c "php spark migrate:status" >/dev/null 2>&1; do
    echo "Waiting for database to be ready..."
    sleep 2
done

echo "Running database migrations..."
docker compose exec test_conf_backend bash -c "php spark migrate:refresh"
echo "Seeding the database..."
docker compose exec test_conf_backend bash -c "php spark db:seed MainSeeder2024"
echo "Copying images..."
sudo cp ./backend/writable/uploads/* ./data/uploads/

docker compose exec test_conf_db bash -c "touch /var/lib/mysql/.gitkeep"
docker compose exec test_conf_backend bash -c "touch /var/www/html/writable/uploads/.gitkeep"

echo "Setting file permissions..."
docker compose exec test_conf_backend bash -c "chown -R www-data:www-data /var/www/html/writable"

echo "All done."
