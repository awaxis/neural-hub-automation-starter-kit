#!/bin/bash

set -e
set -u

function create_user_and_database() {
    local database=$1
    local dbuser=$2
    if [ "$#" -gt 2 ]
    then
        password=$3
    else
        local password=""
    fi

    echo "Creating user and database '$dbuser$([[ -z $password ]] && echo "" || echo ":$password")@$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
CREATE USER $database$([[ -z $password ]] && echo "" || echo " WITH PASSWORD '$password'");
CREATE DATABASE $database OWNER $dbuser;
GRANT CONNECT ON DATABASE $database TO $dbuser;
GRANT ALL PRIVILEGES ON DATABASE $database TO $dbuser;
GRANT ALL ON SCHEMA public TO $dbuser;
EOSQL
}

if [ -n "$POSTGRES_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_DATABASES"
    for db in $(echo $POSTGRES_DATABASES | tr ',' ' '); do
        dbname=$db
        dbuser=$db
        dbpassword=""
        # find user and password, pattern: user:password@dbname
        dbconfig=(${db//@/ })
        if [ ${#dbconfig[@]} -gt 1 ]; then
            dbname=${dbconfig[1]}
            dbuser=${dbconfig[0]}

            userconfig=(${dbuser//:/ })
            if [ ${#userconfig[@]} -gt 1 ]; then
                dbuser=${userconfig[0]}
                dbpassword=${userconfig[1]}
            fi
        fi
        create_user_and_database $dbname $dbuser $dbpassword
    done
    echo "Multiple databases created"
fi