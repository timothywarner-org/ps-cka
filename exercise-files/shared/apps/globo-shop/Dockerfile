# Globomantics parts shop -- the shared demo app for the CKA Skill Path.
#
# Deliberately boring: a static site on nginx. The teaching value is not in the
# app, it is in what the app REVEALS -- which Pod, which node, which namespace
# served the request. Keep it that way. Every minute a learner spends puzzling
# over app code is a minute they are not learning Kubernetes.

# Pinned to a specific minor, not :latest. An image that silently changes under
# you is the enemy of a reproducible lab, and "works on my cluster" is the
# failure mode this line prevents.
FROM nginx:1.27-alpine

# OCI labels. ghcr.io reads these to wire the package back to the repo, which is
# what makes the package page show the README and the source link automatically.
LABEL org.opencontainers.image.title="Globomantics parts shop" \
      org.opencontainers.image.description="Shared demo app for Tim Warner's CKA Skill Path. Reports the Pod, node, and namespace that served the request." \
      org.opencontainers.image.source="https://github.com/timothywarner-org/ps-cka" \
      org.opencontainers.image.licenses="MIT"

# Baked in at build time so the running Pod can name its own version on screen.
# The workflow overrides this per tag.
ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION}

COPY src/nginx.conf    /etc/nginx/nginx.conf
COPY src/entrypoint.sh /entrypoint.sh

# The PRISTINE page lives at /opt, which stays read-only. At startup the entrypoint
# copies it to /usr/share/nginx/html (a writable emptyDir in Kubernetes) and stamps
# the Downward API values into the copy.
#
# WHY not an initContainer: an initContainer would also work, but it is a second
# container that needs its own resource requests and limits the moment the namespace
# has a ResourceQuota -- and forgetting that is a genuinely nasty failure (the
# ReplicaSet just refuses to create Pods and the Deployment sits at 0/3 with the
# reason buried in `describe rs`). One container with a copy step is simpler and it
# cannot fail that way.
COPY src/index.html /opt/globo/index.html

RUN chmod +x /entrypoint.sh \
 && mkdir -p /usr/share/nginx/html /tmp \
 && chown -R 101:101 /usr/share/nginx/html /tmp /opt/globo

# Run unprivileged, and declare it as a NUMERIC UID.
#
# WHY the number and not `USER nginx`: with runAsNonRoot: true, the kubelet has to
# verify the user isn't root BEFORE it starts the container. It only has the image
# metadata to go on, so a name like "nginx" is unverifiable -- it can't resolve the
# name to a UID without running the image, which is the thing it's trying to gate.
# It fails closed with CreateContainerConfigError. A numeric UID it can check.
# 101 is nginx in the official alpine image.
USER 101

# 8080, not 80 -- see the comment in nginx.conf. A non-root user cannot bind 80.
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/entrypoint.sh"]
