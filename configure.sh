#! /usr/bin/env bash

set -e

ENV_FILE=".env"

if [[ ! -f $ENV_FILE ]]; then
  echo "Creating $ENV_FILE with HOST_UID and HOST_GID..."
  echo "HOST_UID=$(id -u)" > "$ENV_FILE"
  echo "HOST_GID=$(id -g)" >> "$ENV_FILE"
else
  echo "$ENV_FILE already exists. Using existing HOST_UID and HOST_GID..."
fi

# Load values into environment
set -o allexport
source "$ENV_FILE"
set +o allexport

echo "HOST_UID=$HOST_UID"
echo "HOST_GID=$HOST_GID"

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

echo "Building the backend image (dev_dependencies stage only)..."
docker buildx build --build-arg HOST_UID=$HOST_UID --build-arg HOST_GID=$HOST_GID --target dev_dependencies -t test_conf_backend ./backend

# Restore vendor folder if missing or empty
if [ ! -d "./backend/vendor" ] || [ -z "$(ls -A ./backend/vendor 2>/dev/null)" ]; then
    echo "Restoring 'vendor' folder from image..."

    # Create temp container from built image
    temp_container=$(docker create test_conf_backend)

    docker cp "$temp_container:/app/vendor/." ./backend/vendor/

    docker rm "$temp_container"

    echo "Fixing vendor folder ownership..."
    sudo chown -R "$(id -u):$(id -g)" ./backend/vendor
else
    echo "'vendor' folder already exists and is not empty. Skipping restore."
fi

echo "Building the frontend image (dev_dependencies stage only)..."
docker buildx build --build-arg HOST_UID=$HOST_UID --build-arg HOST_GID=$HOST_GID --target dev -t test_conf_frontend ./frontend

# Restore node_modules folder if missing or empty
if [ ! -d "./frontend/node_modules" ] || [ -z "$(ls -A ./frontend/node_modules 2>/dev/null)" ]; then
    echo "Restoring 'node_modules' folder from image..."

    # Create temp container from built image
    temp_container=$(docker create test_conf_frontend)

    docker cp "$temp_container:/app/node_modules/." ./frontend/node_modules/

    docker rm "$temp_container"

    echo "Fixing node_modules folder ownership..."
    sudo chown -R "$(id -u):$(id -g)" ./frontend/node_modules
else
    echo "'node_modules' folder already exists and is not empty. Skipping restore."
fi

echo "Copying configuration files..."
find container -type f -name '*.sample' -exec sh -c '
  for f; do
    target="${f%.sample}"
    if [ ! -e "$target" ]; then
      cp "$f" "$target"
    fi
  done
' sh {} +

echo "Building and starting the containers..."
docker compose up -d --build --force-recreate

echo "Setting file permissions..."
docker compose exec -u root test_conf_backend bash -c "chown -R ${HOST_UID}:${HOST_GID} /var/www/html/writable"

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

# Load DB password from .compose_env
COMPOSE_ENV_FILE="./container/dev/.compose_env"
if [[ -f "$COMPOSE_ENV_FILE" ]]; then
  echo "Loading MySQL credentials from $COMPOSE_ENV_FILE..."
  set -o allexport
  source "$COMPOSE_ENV_FILE"
  set +o allexport
else
  echo "Error: $COMPOSE_ENV_FILE not found. Cannot create test database."
  exit 1
fi

echo "Creating test database if not exists..."
docker compose exec test_conf_db mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS test_conf_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
docker compose exec test_conf_db mariadb -u root -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON test_conf_test.* TO 'test_conf_user'@'%'; FLUSH PRIVILEGES;"

echo "All done."
