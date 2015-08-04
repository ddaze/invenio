#!/usr/bin/env bash
#set -e

# SET CONFIG
CFG_HOST=${HOST:=$(hostname --ip-address)}
export CFG_HOST
CFG_PORT=${PORT:=4000}
export CFG_PORT
CFG_EMAIL=${EMAIL:='invenio@example.de'}
export CFG_EMAIL

CFG_INVENIO_SRCDIR=${CFG_INVENIO_SRCDIR:=/src/invenio}
export CFG_INVENIO_SRCDIR
CFG_INVENIO_PREFIX=${CFG_INVENIO_PREFIX:=/opt/invenio}
export CFG_INVENIO_PREFIX
CFG_INVENIO_HOSTNAME=${CFG_INVENIO_HOSTNAME:=$CFG_HOST}
export CFG_INVENIO_HOSTNAME
CFG_INVENIO_DOMAINNAME=${CFG_INVENIO_DOMAINNAME:=}
export CFG_INVENIO_DOMAINNAME
CFG_INVENIO_PORT_HTTP=${CFG_INVENIO_PORT_HTTP:=$CFG_PORT}
export CFG_INVENIO_PORT_HTTP # TODO: fix port in config
CFG_INVENIO_PORT_HTTPS=${CFG_INVENIO_PORT_HTTPS:=443}
export CFG_INVENIO_PORT_HTTPS
CFG_INVENIO_USER=${CFG_INVENIO_USER:=root}
export CFG_INVENIO_USER
CFG_INVENIO_ADMIN=${CFG_INVENIO_ADMIN:=$CFG_EMAIL}
export CFG_INVENIO_ADMIN
CFG_INVENIO_DATABASE_NAME=${CFG_INVENIO_DATABASE_NAME:=$DB_ENV_MYSQL_DATABASE}
export CFG_INVENIO_DATABASE_NAME
CFG_INVENIO_DATABASE_USER=${CFG_INVENIO_DATABASE_USER:=$DB_ENV_MYSQL_USER}
export CFG_INVENIO_DATABASE_USER
CFG_INVENIO_DATABASE_PASS=${CFG_INVENIO_DATABASE_PASS:=$DB_ENV_MYSQL_PASSWORD}
export CFG_INVENIO_DATABASE_PASS


function virtenv() {
    source /opt/virtenv/bin/activate
}

function wait_db() {
    # Check if DB is Connected
    sleep 3
    if [ $(mysql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
        "select count(*) from information_schema.tables;") -gt 1 ]; then
        echo "DATABASE UP"
    else
        echo "Waiting for DATABASE"
        sleep 12
        if ! [ $(mysql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
            "select count(*) from information_schema.tables;") -gt 1 ]; then
            echo "DATABASE NOT CONNECTED OR NOT RUNNING"
            exit 5
        fi
    fi
}

function create_db() {
    # Install Database if not exist
    if [ $(mysql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
            "select count(*) from information_schema.tables where TABLE_NAME='userEXT';") -eq 1 ];
    then
        echo "DATABASE ALREADY EXISTS"
    else
        echo "DATABASE DOES NOT EXIST"
        # FIRST SETUP ONLY
    mysql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
        "DROP DATABASE IF EXISTS invenio;"
    mysql -N -s -h ql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
        "CREATE DATABASE invenio DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
    mysql -N -s -h db -u root -p"$DB_ENV_MYSQL_ROOT_PASSWORD" -e \
        "GRANT ALL PRIVILEGES ON invenio.* TO 'invenio'@'%';"
    mysql -N -s -h db -u root -p"$DB_ENV_MYSQL_ROOT_PASSWORD" -e \
        "flush-privileges;"
        chown -R apache /opt/invenio
        /opt/invenio/bin/inveniocfg --update-all
        /opt/invenio/bin/inveniocfg --create-tables --yes-i-know
        /opt/invenio/bin/inveniocfg --load-bibfield-conf
        /opt/invenio/bin/inveniocfg --create-demo-site --yes-i-know
        /opt/invenio/bin/inveniocfg --load-demo-records --yes-i-know
    fi
}

function compile_invenio() {
    echo "Compile Invenio from /src/invenio"
    chown apache -R /opt/invenio

    ENV_PATH="/opt/virtenv/bin/"

    cd /src/invenio
    "$ENV_PATH"pip install -r requirements.txt || true
    "$ENV_PATH"pip install -r requirements-extras.txt || true
    rm -rf autom4te.cache
    aclocal
    automake -a
    autoconf
    ./configure
    make -s clean
    make -s
    make -s install
    make -s install-jquery-plugins
    make -s install-mathjax-plugin
    make -s install-ckeditor-plugin
    make -s install-mediaelement
    make -s install-pdfa-helper-files
    mkdir -p /opt/invenio/var/tmp/ooffice-tmp-files
    chmod -R 775 /opt/invenio/var/tmp/ooffice-tmp-files

    # if cds is installed
    if ! [ -z "$CDS" ]; then
        echo "BUILD CDS Overlay"
        cd /src/cds
        make
        make install-yes-i-know
    fi
    chown apache -R /opt/invenio
}

function config_invenio() {
    # Configure Invenio:
    touch /opt/invenio/etc/invenio-local.conf
    /create-config /src/invenio/docker/invenio-local.template > /opt/invenio/etc/invenio-local.conf

    if ! [ -z "$CDS" ]; then
        /create-config /src/invenio/docker/invenio-local_cds.template >> /opt/invenio/etc/invenio-local.conf
    #  sed -i 's,CFG_CERN_SITE =.*,CFG_CERN_SITE = 1,g' /opt/invenio/lib/python/invenio/config.py
    #  sed -i 's,CFG_WEBSTYLE_TEMPLATE_SKIN = .*,CFG_WEBSTYLE_TEMPLATE_SKIN = "cern",g' /opt/invenio/lib/python/invenio/config.py
    fi
    chown apache /opt/invenio/etc/invenio-local.conf
}

function install_invenio_if_needed() {
    if ! [ -d /opt/invenio/var/run/ ]; then
        compile_invenio
    fi
}

function check_collections() {
    # Check if the collection cache is good
    if ! [ -d /opt/invenio/var/cache/collections ]; then
        # Create cache /opt/invenio/bin/webcoll  /opt/invenio/bin/bibsched
        taskID="$(/opt/invenio/bin/webcoll -u admin | grep -oP '(?<=#)[0-9]*')"
        # TODO: Check if running in background is okay
        /opt/invenio/bin/webcoll $taskID&
    fi
}

################# Check first start ####################

# patch -t /usr/local/lib/python2.7/dist-packages/invenio_devserver/serve.py < /tmp/serve.patch
virtenv

if ! [ -d /opt/invenio/etc ]; then
    echo "create opt"
    mkdir -p /opt/invenio/lib/python/invenio
    ln -s /opt/invenio/lib/python/invenio /opt/virtenv/lib/python2.7/site-packages/
    ln -s /opt/invenio/lib/python/invenio /opt/virtenv/local/lib/python2.7/site-packages/
    chown -R apache.apache /opt/invenio
else
    echo "Use existing /opt/invenio"
fi

if ! [ -d /src/invenio/modules ]; then
    echo "Copy src"
    mkdir -p /src/invenio
    cp -R /tmp/src/invenio /src
    chown -R apache.apache /src/invenio
else
    echo "Use existing src"
fi

if ! [ -f /src/invenio/docker/invenio-local.template ]; then
    mkdir -p /src/invenio/docker
    cp /tmp/invenio-local.template /src/invenio/docker/
    cp /tmp/invenio-local_cds.template /src/invenio/docker/
fi

if [ "$1" = 'serve' ]; then
    wait_db
    install_invenio_if_needed
    config_invenio
    /opt/invenio/bin/inveniocfg --update-all
    create_db
    check_collections

    echo "DB Port: $DB_PORT"
    echo "Redis Port: $REDIS_PORT"
    echo "IP: $(hostname --ip-address)"

    serve -s /src/invenio -o /opt/invenio -b 0.0.0.0 -p $CFG_PORT
    # gosu apache serve -s /src/invenio -o /opt/invenio -b 0.0.0.0 -p 4000
    exit

elif [ "$1" = 'make' ]; then
    echo "compile_invenio"
    compile_invenio
    echo "wait_db"
    wait_db
    echo "config_invenio"
    config_invenio
    echo "create_db"
    create_db
    echo "check_collections"
    check_collections

    echo "DB Port: $DB_PORT"
    echo "Redis Port: $REDIS_PORT"
    echo "IP: $(hostname --ip-address)"

    /opt/invenio/bin/inveniocfg --update-all
    # exec sudo script -q -c "/bin/bash serve -s /src/invenio -o /opt/invenio"
    exit

elif [ "$1" = 'newdb' ]; then
    wait_db
    mysql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
        "DROP DATABASE IF EXISTS invenio;"
    mysql -N -s -h ql -N -s -h db -u $DB_ENV_MYSQL_USER -p"$DB_ENV_MYSQL_PASSWORD" -e \
        "CREATE DATABASE invenio DEFAULT CHARACTER SET utf8;"
    mysql -N -s -h db -u root -p"$DB_ENV_MYSQL_ROOT_PASSWORD" -e \
        "GRANT ALL PRIVILEGES ON invenio.* TO 'invenio'@'%'"
    config_invenio
    create_db
    exit

elif [ "$1" = 'unit_tests' ]; then
    exec nosetests /opt/invenio/lib/python/invenio/*_unit_tests.py
elif [ "$1" = 'regression_tests' ]; then
    exec nosetests /opt/invenio/lib/python/invenio/*_regression_tests.py
fi

config_invenio
/opt/invenio/bin/inveniocfg --update-all
exec $@

# Check if data exist
# if ! [ -d "/opt/invenio/var/www" ]; then
#   echo "www does not exist, DO SOMESTHING compile?"
# fi
