#!/usr/bin/env bash

source bosh-src/ci/tasks/utils.sh

check_param RUBY_VERSION
check_param DB

echo "Starting $DB..."
case "$DB" in
  mysql)
    mv /var/lib/mysql /var/lib/mysql-src
    mkdir /var/lib/mysql
    mount -t tmpfs -o size=512M tmpfs /var/lib/mysql
    mv /var/lib/mysql-src/* /var/lib/mysql/

    sudo service mysql start
    ;;
  postgresql)
    export PATH=/usr/lib/postgresql/9.4/bin:$PATH

    mkdir /tmp/postgres
    mount -t tmpfs -o size=512M tmpfs /tmp/postgres
    mkdir /tmp/postgres/data
    chown postgres:postgres /tmp/postgres/data

    su postgres -c '
      export PATH=/usr/lib/postgresql/9.4/bin:$PATH
      export PGDATA=/tmp/postgres/data
      export PGLOGS=/tmp/log/postgres
      mkdir -p $PGDATA
      mkdir -p $PGLOGS
      initdb -U postgres -D $PGDATA
      pg_ctl start -l $PGLOGS/server.log -o "-N 400"
    '
    ;;
  *)
    echo "Usage: DB={mysql|postgresql} $0 {commands}"
    exit 1
esac

mv ./bosh-cli/*bosh-cli-*-linux-amd64 /usr/local/bin/gobosh
chmod +x /usr/local/bin/gobosh

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

agent_path=bosh-src/src/go/src/github.com/cloudfoundry/
mkdir -p $agent_path
cp -r bosh-agent $agent_path

cd bosh-src/src

print_git_state

bundle install --local

set +e
bundle exec rake --trace spec:integration_gocli
RESULT=$?

grep -Ri "Agent exited with error:" tmp/integration-tests-workspace 2>/dev/null

exit $RESULT
