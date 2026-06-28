# Course 3, Module 3 -- Helm, Kustomize & CRDs

Exercise files for the Module 3 demo. These cover three CKA v1.35 objectives:
package management with **Helm**, template-free customization with **Kustomize**,
and extending the API with **Custom Resource Definitions (CRDs)**.

The on-rails demo driver is `Invoke-M03Lab.ps1` in
`src/cka-lab/course-03-lifecycle-upgrades/`. It pushes this tree to the lab node
and runs every command live. You can also run the commands yourself against any
v1.35 cluster.

The module slide deck (PDF) is [`m03-helm-kustomize-crds-slides.pdf`](m03-helm-kustomize-crds-slides.pdf).

## Kustomize -- `m03-kustomize-demo/`

One **base** customized by two **overlays**. No templating language, no copied YAML.

```
m03-kustomize-demo/
  base/                     # globo-web Deployment + Service, plain
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    staging/                # staging- prefix, env=staging, replicas 2
      kustomization.yaml
    production/             # prod- prefix, env=production, replicas 4, pinned image
      kustomization.yaml
```

Render an overlay (build only, nothing applied):

```bash
kubectl kustomize overlays/production
```

Apply it for real:

```bash
kubectl apply -k overlays/production
kubectl get deploy,svc -l env=production
```

Key transformers on display: `namePrefix`, `labels` (metadata only, selectors
left intact), `replicas`, and `images` (pin nginx to a specific patch tag in prod).

## CRDs -- `m03-crds-demo/`

```
m03-crds-demo/
  backuppolicy-crd.yaml          # defines the BackupPolicy kind (group globomantics.io)
  globomantics-backuppolicy.yaml # a BackupPolicy instance: nightly etcd backup
```

```bash
# Teach the API server a new kind:
kubectl apply -f backuppolicy-crd.yaml

# The structural schema makes explain work against your OWN kind:
kubectl explain backuppolicy.spec

# Create and list an instance (short name: bp):
kubectl apply -f globomantics-backuppolicy.yaml
kubectl get bp
```

A CRD is typed storage. Pair it with a controller that reconciles those objects
and you have an **operator**.

## Helm

Helm uses a public chart (no files here). The demo installs the client, adds a
repo, installs a release, upgrades one value, then rolls back:

```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo
helm upgrade --install globo-podinfo podinfo/podinfo --wait
helm upgrade globo-podinfo podinfo/podinfo --reuse-values --set replicaCount=3 --wait
helm rollback globo-podinfo 1 --wait
helm history globo-podinfo
```

`helm upgrade --install` is idempotent, and every release keeps a numbered
revision history -- `helm rollback <release> <revision>` is the undo.
