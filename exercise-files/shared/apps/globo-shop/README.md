# Globomantics parts shop

The shared demo app for the CKA Skill Path. It is a static site on nginx, and it is
deliberately boring, because the app is not the lesson. What it **reveals** is the lesson:
every page names the **Pod**, **node**, **namespace**, and **environment** that served it.

Scale the Deployment and the Pod names change. Switch namespaces and the banner changes.
Delete a Pod and watch a new name appear. The learner sees Kubernetes working instead of
taking the instructor's word for it.

## The two environments

One cluster, two namespaces, both running at the same time.

| Environment | Namespace | Replicas | URL |
|---|---|---|---|
| Dev | `globo-dev` | 2 | http://192.168.50.10:30080 |
| Prod | `globo-prod` | 3 | http://192.168.50.10:30081 |

**Why namespaces and not two clusters:** the CKA exam puts you in front of several clusters
and every task names the one it wants. We can't hand every learner a second cluster on a
laptop, but the reflex we're drilling -- verify where you're pointed **before** you type --
is identical whether the boundary is a cluster or a namespace. Same muscle, one-tenth the RAM.

Prod also carries a **ResourceQuota**. That's not decoration: deploy something oversized into
prod and it gets rejected, while the same manifest sails into dev. Consequences are what make
"check your context" land.

## Deploy it

```bash
# On control1
kubectl apply -f manifests/environments.yaml     # creates both namespaces + the prod quota
kubectl apply -k manifests/overlays/dev
kubectl apply -k manifests/overlays/prod

kubectl get pods -n globo-dev                    # 2 pods
kubectl get pods -n globo-prod                   # 3 pods
```

Then open both URLs side by side. Refresh a few times and watch the **Pod** row change as the
Service load-balances you across replicas.

## Tear it down

```bash
kubectl delete -k manifests/overlays/dev
kubectl delete -k manifests/overlays/prod
kubectl delete -f manifests/environments.yaml
```

## The image

`ghcr.io/timothywarner-org/globo-shop:v1` -- built by
[`.github/workflows/globo-shop-image.yml`](../../../../.github/workflows/globo-shop-image.yml)
on every push to this folder. The package is **public**, so the lab nodes pull it anonymously
with no imagePullSecret.

Build it yourself:

```bash
docker build --build-arg APP_VERSION=v1 -t globo-shop:dev .
docker run --rm -p 8080:8080 -e APP_ENV=local globo-shop:dev
# http://localhost:8080
```

It runs as an **unprivileged user** on port **8080** (not 80, because binding a port below
1024 would force it to run as root), with a **read-only root filesystem** and **all Linux
capabilities dropped**. That's not gold-plating -- it's the configuration the exam expects
you to be able to explain.

## Layout

```
globo-shop/
  Dockerfile
  src/
    index.html        the page, with __PLACEHOLDER__ tokens
    entrypoint.sh     stamps the Downward API values in at container start
    nginx.conf        listens on 8080; serves /healthz for the probes
  manifests/
    environments.yaml            the two namespaces + the prod ResourceQuota
    base/                        the app, with no opinion about environment
    overlays/dev/                namespace, 2 replicas, dev banner, port 30080
    overlays/prod/               namespace, 3 replicas, prod banner, port 30081
```

Kustomize is on the February 2025 CKA curriculum, so the overlay structure doubles as the
teaching artifact for it. Two environments that differ in three fields don't need two copies
of a manifest.
