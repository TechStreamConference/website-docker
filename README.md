# Tech-Stream-Conference Docker

## Setup

1) In this folder clone the projects `website-backend` and `website-frontend`:

    ```sh
    git clone https://github.com/TechStreamConference/website-backend.git
    git clone https://github.com/TechStreamConference/website-frontend.git
    ```

2) Build the docker images:

    ```sh
    docker compose build
    ```

    _Note: If you do not have the subcommand `docker compose` use `docker-compose` instead._

3) Start the app:

    ```sh
    docker compose up -d
    ```

4) Run initial database migrations and seed with test data:

    ```sh
    docker compose run --rm php bash

    php spark migrate
    php spark db:seed MainSeeder

    exit
    ```

5) Setup the hostname:  
    Open your `/etc/hosts` file and add an entry for `dev.test-conf.de` pointing to `127.0.0.1`:

    ```hosts
    127.0.0.1   dev.test-conf.de
    ```

6) The app should be running now:  
    Open <http://dev.test-conf.de:8080/> in your browser.
