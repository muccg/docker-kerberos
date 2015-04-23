#!/bin/bash

set -e


function defaults {
    : ${KRB5REALM:=DOCKERDOMAIN}
    : ${DOMAIN_REALM:=dockerdomain}
    : ${KERB_MASTER_KEY:=masterkey}
    : ${KERB_ADMIN_USER:=admin}
    : ${KERB_ADMIN_PASS:=admin}
    : ${KDC_ADDRESS:=kerberos.dockerdomain}
    : ${KRB5KDC_ARGS:=""}
    : ${KADMIND_ARGS:=""}
    : ${DOCKER_FIRSTRUN:=/var/kerberos/.docker_firstrun}

    export KRB5REALM KRB5KDC_ARGS KADMIND_ARGS
}


function create_config() {
    echo "Creating config"
    cat > /etc/krb5.conf<<EOF
[logging]
 default = FILE:/dev/stdout
 kdc = FILE:/dev/stdout
 admin_server = FILE:/dev/stdout
[libdefaults]
 default_realm = $KRB5REALM
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true

[realms]
 $KRB5REALM = {
  kdc = $KDC_ADDRESS:88
  admin_server = $KDC_ADDRESS:749
  default_domain = $DOMAIN_REALM
 }

[domain_realm]
 .$DOMAIN_REALM = $KRB5REALM
 $DOMAIN_REALM = $KRB5REALM
EOF
}


function create_db() {
    echo "Creating db"
    /usr/sbin/kdb5_util -P $KERB_MASTER_KEY -r $KRB5REALM create -s
}


function create_admin_user() {
    echo "Creating admin user"
    kadmin.local -q "addprinc -pw $KERB_ADMIN_PASS $KERB_ADMIN_USER/admin"
    echo "*/admin@$KRB5REALM *" > /var/kerberos/krb5kdc/kadm5.acl
}


function firstrun {
    if ! [[ -f ${DOCKER_FIRSTRUN} ]]; then
        create_config
        create_db
        create_admin_user
        touch ${DOCKER_FIRSTRUN}
    fi
}


echo "HOME is ${HOME}"
echo "WHOAMI is `whoami`"

defaults
firstrun

if [ "$1" = 'supervisord' ]; then
    echo "[Run] supervisord"
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n
    exit 0
fi

echo "[RUN]: Builtin command not provided [supervisord]"
echo "[RUN]: $@"

exec "$@"
