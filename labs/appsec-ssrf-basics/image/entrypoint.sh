#!/bin/sh
set -e

# Precisa de CAP_NET_ADMIN — sem isso, este comando falha e o serviço
# de metadados simulado nunca sobe (o container continua funcionando
# pro resto do lab, mas a task 2/exploit não vai funcionar).
ip addr add 169.254.169.254/32 dev lo

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
