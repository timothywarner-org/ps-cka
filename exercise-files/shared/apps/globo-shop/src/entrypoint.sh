#!/bin/sh
# Globomantics parts shop -- container entrypoint.
#
# WHY this exists: the page has to prove WHICH Pod served it, or the scaling and
# load-balancing demos are just an author's word against a static page. Kubernetes
# hands us that identity through the Downward API as environment variables, so we
# stamp them into the HTML once, at start, and then nginx serves a plain static file.
# No app runtime, no templating engine, no request-time cost.
set -eu

# The pristine page ships at /opt/globo and is never modified. We copy it to the
# serving directory (a writable emptyDir under Kubernetes) and stamp THAT copy.
# Copying every start means a restarted container re-stamps cleanly instead of
# running sed over an already-substituted file.
PRISTINE=/opt/globo/index.html
SRC=/usr/share/nginx/html/index.html

cp "$PRISTINE" "$SRC"

# Every value has a fallback, so the image still runs under plain `docker run`
# with no Kubernetes around it. A demo asset that only works inside a cluster is
# a demo asset you cannot debug.
: "${APP_ENV:=unset}"
: "${APP_VERSION:=v1}"
: "${POD_NAME:=not-in-kubernetes}"
: "${POD_NAMESPACE:=none}"
: "${NODE_NAME:=localhost}"
: "${POD_IP:=127.0.0.1}"

sed -i \
  -e "s|__ENV_NAME__|${APP_ENV}|g" \
  -e "s|__APP_VERSION__|${APP_VERSION}|g" \
  -e "s|__POD_NAME__|${POD_NAME}|g" \
  -e "s|__POD_NAMESPACE__|${POD_NAMESPACE}|g" \
  -e "s|__NODE_NAME__|${NODE_NAME}|g" \
  -e "s|__POD_IP__|${POD_IP}|g" \
  "$SRC"

echo "globo-shop ${APP_VERSION} starting: env=${APP_ENV} pod=${POD_NAME} ns=${POD_NAMESPACE} node=${NODE_NAME}"

# exec so nginx becomes PID 1 and receives SIGTERM directly. Without exec, the
# shell holds PID 1, swallows the signal, and every Pod deletion waits the full
# 30-second grace period. That is the difference between a 2-second rolling
# update on camera and a 30-second one.
exec nginx -g 'daemon off;'
