#!/usr/bin/env bash
#================================================================
# Globomantics parts shop -- get the image onto your lab nodes.
#
# Run this from your HOST (the machine with Docker), not from a node.
#
# WHY this exists: the manifests set `imagePullPolicy: IfNotPresent`, which means
# a node that already has the image never contacts a registry at all. So there are
# two ways to get it there, and this script does whichever one works for you:
#
#   1. PULL  -- the node pulls from ghcr.io. Needs internet on the nodes.
#   2. BUILD -- you build locally and we side-load the image into each node's
#               containerd. Needs Docker on the host, nothing on the nodes.
#
# Mode 2 is the fallback that always works, including on an air-gapped lab. It is
# also exactly how you would seed a real disconnected cluster, so it is worth
# knowing regardless.
#================================================================
set -euo pipefail

IMAGE="ghcr.io/timothywarner-org/globo-shop:v1"
NODES=("control1" "worker1" "worker2")
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Trying the easy path first: can the nodes pull ${IMAGE} themselves?"
if ssh "vagrant@${NODES[0]}" "sudo crictl pull ${IMAGE}" >/dev/null 2>&1; then
    echo "    Yes. Pulling on every node."
    for n in "${NODES[@]}"; do
        ssh "vagrant@${n}" "sudo crictl pull ${IMAGE}" >/dev/null 2>&1
        echo "    [OK] ${n}"
    done
    echo "==> Done. The nodes pulled the image from the registry."
    exit 0
fi

echo "    No -- the registry is unreachable or the package is private."
echo "==> Falling back: build locally and side-load into each node's containerd."

command -v docker >/dev/null 2>&1 || {
    echo "ERROR: Docker is required for the build fallback. Install Docker and re-run." >&2
    exit 1
}

echo "--> Building ${IMAGE}"
docker build --build-arg APP_VERSION=v1 -t "${IMAGE}" "${HERE}"

TAR="$(mktemp -t globo-shop-XXXXXX.tar)"
# Clean up the tarball even if a node transfer fails partway through.
trap 'rm -f "${TAR}"' EXIT

echo "--> Exporting to ${TAR}"
docker save "${IMAGE}" -o "${TAR}"

for n in "${NODES[@]}"; do
    echo "--> Loading onto ${n}"
    scp -q "${TAR}" "vagrant@${n}:/tmp/globo.tar"
    # -n k8s.io is the containerd NAMESPACE Kubernetes reads from. Import into the
    # default containerd namespace instead and the kubelet will never find the image.
    ssh "vagrant@${n}" "sudo ctr -n k8s.io images import /tmp/globo.tar >/dev/null && rm -f /tmp/globo.tar"
    ssh "vagrant@${n}" "sudo crictl images | grep -q globo-shop" \
        && echo "    [OK] ${n}" \
        || { echo "    [FAIL] ${n} -- image not visible to the kubelet" >&2; exit 1; }
done

echo "==> Done. Every node has the image. Now deploy:"
echo "      kubectl apply -f manifests/environments.yaml"
echo "      kubectl apply -k manifests/overlays/dev"
echo "      kubectl apply -k manifests/overlays/prod"
