# CKA C04 M02 — deck corrections before you record

**Grounded 2026-08-17** against kubernetes.io v1.35 and the `kubernetes/kubernetes`
`release-1.35` source, by a six-lens research pass with an adversarial refutation
round. Every item below is a claim the deck makes **on camera**.

**Your speaker notes are in better shape than your slide bullets.** Several of these
are already correct in the notes and wrong only in the on-screen text.

---

## 1. Slide 9 bullet — "the gate in v1.27" is WRONG

**On screen now:** *"Auto-generation stopped in Kubernetes v1.24, the gate in v1.27"*

The feature gate `LegacyServiceAccountTokenNoAutoGeneration` was **not removed in
v1.27**. In v1.27 it went GA and was *locked to its default* (`LockToDefault: true`),
so you could no longer turn auto-generation back on — but the gate name was still
accepted. It was **removed from the code in v1.29**.

Two sibling gates followed: `LegacyServiceAccountTokenTracking` removed in **v1.30**,
`LegacyServiceAccountTokenCleanUp` removed in **v1.32**. On **v1.35 all three are gone
and the behavior is unconditional** — there is no switch to flip.

**Suggested replacement bullet:** *"Auto-generation stopped in v1.24; locked open in
v1.27, gate gone in v1.29"*

> **Also worth knowing:** the kubernetes.io docs themselves are inaccurate on this
> point. Do not quote the docs page on camera — the source tree and release notes are
> the reliable record here.

## 2. Slide 10 bullet — "The kubelet requests it and mounts it" compresses two components

**Correct split:** the **kube-apiserver's ServiceAccount admission controller** adds
the projected volume and volumeMount to the Pod spec. The **kubelet** then acquires
the actual token via the TokenRequest API and writes it into that volume.

This matters because Demo 2 proves it live: the projected volume is **not** in
`deploy-runner.yaml`, yet it is in the live object. Admission wrote it.

**Suggested narration:** *"Admission adds the volume, the kubelet fills it."*

## 3. Slide 10 bullet — "Rotated on a timer" is not what happens

The kubelet's token manager refreshes when the token is older than **80% of its TTL**
(minus up to 10s of jitter), **or older than 24 hours**, whichever comes first. Not a
fixed timer. For a 3607s token that's roughly the 48-minute mark.

## 4. Slide 13 bullet — "the server decides the lifetime" is true but incomplete

`kubectl` only sets `spec.expirationSeconds` when `--duration > 0`. Otherwise it leaves
the field nil and **the API server defaults it to exactly 3600 seconds**. "The server
decides" is right, but the number is knowable and worth saying.

**Two more facts that belong in the demo:**

- **There is a 10-minute floor.** `--duration=5m` is **refused**: `may not specify a
  duration less than 10 minutes`. Your notes already say "duration ten m" — that is
  the minimum, not a round number. Worth showing the rejection on camera; it's a
  memorable beat and the runbook now includes it.
- **Exceeding the admin cap does NOT fail.** If a cluster sets
  `--service-account-max-token-expiration`, the API server **silently shortens** the
  token, emits an HTTP Warning header, and returns 200. `kubectl` exits 0. Only the
  hard validation ceiling (2^32 seconds) produces an actual error.

## 5. Slide 13 bullet — `--bound-object-kind` and a stale doc

Your bullet says *"takes Node, Pod, or Secret"* — that matches **kubectl and the
server** (Node binding went beta in 1.31, GA in 1.33). But the **published API
reference still lists only Pod and Secret**; it was never updated. If a learner checks
the docs mid-exam they will see a shorter list than the one you said. One clause
covers it.

## 6. Slide 6 bullet — "only the API discovery permissions" is nearly right

Two refinements:

- Beyond the three discovery ClusterRoles, every ServiceAccount is **also** bound to
  `system:service-account-issuer-discovery` via the group `system:serviceaccounts`.
  So `kubectl auth can-i get /openid/v1/jwks --as=system:serviceaccount:staging:default`
  returns **yes**.
- The discovery grants do **not** come from any binding naming the default
  ServiceAccount. `system:discovery`, `system:basic-user`, and
  `system:public-info-viewer` are bound to the **group** `system:authenticated`. Your
  notes already say "granted to everyone who authenticates" — that's exactly right,
  and it's the better framing.

---

## CONFIRMED — say these with confidence

| Claim | Status |
|---|---|
| `expirationSeconds: 3607` on the injected volume | **CONFIRMED** |
| exp is ~1 year out, `warnafter` at the hour mark | **CONFIRMED** — your slide-10 notes have this exactly right |
| Three files at `/var/run/secrets/kubernetes.io/serviceaccount/`: `token`, `ca.crt`, `namespace` | **CONFIRMED** |
| `ca.crt` from the `kube-root-ca.crt` ConfigMap | **CONFIRMED** |
| `namespace` from the downward API | **CONFIRMED** |
| A missing ServiceAccount is rejected at API-server admission; **no Pod object is persisted** | **CONFIRMED** — exact text: `pods "NAME" is forbidden: error looking up service account NS/SA: serviceaccount "SA" not found` |
| The course outline's `CreateContainerConfigError` claim | **WRONG.** That error is the missing-ConfigMap/Secret signature, kubelet-side. Your deck is right; the outline needs the edit. |
| For a Deployment, the failure surfaces as a `FailedCreate` event on the ReplicaSet and a `ReplicaFailure` condition on the Deployment | **CONFIRMED** |
| SA username `system:serviceaccount:<ns>:<name>`; groups include `system:serviceaccounts` and `system:serviceaccounts:<ns>` | **CONFIRMED** |
| `automountServiceAccountToken` sits beside `metadata` on the SA, under `spec` on the Pod, and **the Pod wins** | **CONFIRMED** |
| Hand-made token Secrets are never auto-cleaned | **CONFIRMED** — the v1.29 cleaner only touches auto-generated ones (those the SA's `.secrets` list references back) |

---

## THE ON-CAMERA TRAP THAT WOULD HAVE BITTEN

**`jq` is NOT installed on a stock Ubuntu 22.04 server**, and kubeadm does not pull it
in. Demo 3 is *"Decode the claims."* Any decode that pipes to `jq` **dies on camera**.

`lab.sh` therefore uses **coreutils only**. The JWT decoder handles base64url properly:
translate `_-` to `/+`, then re-add the stripped padding (residue 2 needs `==`, residue
3 needs `=`). Getting that wrong prints `invalid input` and a truncated payload — a
classic live failure. **Tested against all three padding residues; all pass.**

On camera you type `./lab.sh jwt`, which prints `sub`, `aud`, `iss`, `exp` with its
day count, `warnafter` with its minute count, and the `kubernetes.io` block — then
states the point: *exp is a year out, rotation is what limits exposure.*
