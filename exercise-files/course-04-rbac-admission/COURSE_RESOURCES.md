# CKA Course 4 -- Securing Access with RBAC and Admission Controls

## Course Resources

Hand-picked, first-party references for **Certified Kubernetes Administrator (CKA)**
Course 4 of 11, spanning all three modules. Every link is an official source
(kubernetes.io, CNCF, or the Linux Foundation), grounded against **kubernetes.io
release-1.35** and validated on **2026-07-05**.

> **Exam-day note:** the CKA is open-book against `kubernetes.io/docs` (plus a few
> official subdomains). You cannot open Google, blogs, or your own notes. The
> pages marked **[bookmark]** are the ones worth pinning in your exam browser
> *before* test day, because fast doc-navigation is itself a scored skill.

---

## Exam essentials (all three modules)

- **CKA certification home (Linux Foundation)** -- registration, the free retake, and the Candidate Handbook: https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/
- **CKA curriculum (CNCF, GitHub)** -- the authoritative, versioned domain-and-competency list: https://github.com/cncf/curriculum
- **CKA program changes (Feb 2025 revision)** -- confirms the domain weights this course maps to, including Cluster Architecture at 25%: https://training.linuxfoundation.org/certified-kubernetes-administrator-cka-program-changes/
- **Killer Shell -- CKA simulator** -- two free sessions ship with your exam registration; the closest thing to the real environment: https://killer.sh/
- **Kubernetes Documentation (home)** -- the only reference open during the exam: https://kubernetes.io/docs/home/
- **kubectl Quick Reference (cheat sheet)** **[bookmark]** -- the single most useful exam page for imperative speed: https://kubernetes.io/docs/reference/kubectl/quick-reference/
- **kubectl create (command reference)** **[bookmark]** -- generates RBAC objects and, with `--dry-run=client -o yaml`, the manifests: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/
- **Course exercise files (ps-cka repo)** -- the YAML, `commands.sh`, and demo runbooks used on screen: https://github.com/timothywarner-org/ps-cka

---

## Module 1 -- Authentication, Authorization, and RBAC Fundamentals

- **Using RBAC Authorization** **[bookmark]** -- Roles, ClusterRoles, bindings, aggregation, and the default built-in roles; the spine of the module: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- **Authorization Overview** -- the request attributes (the verb-resource-namespace tuple) and where RBAC sits among the authorization modes: https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- **Authenticating** -- why Kubernetes has no User object; X.509 CN maps to the user and O maps to groups; impersonation headers: https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- **kubectl auth (can-i / whoami)** **[bookmark]** -- your RBAC unit test: prove a permission with `--as` before a user ever hits a 403: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/
- **kubectl create role / rolebinding / clusterrole / clusterrolebinding** -- the imperative commands, flag by flag: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/

---

## Module 2 -- Service Accounts and Least-Privilege Access

- **Service Accounts (concept)** -- what identity a Pod gets and what the default ServiceAccount can (and can't) do: https://kubernetes.io/docs/concepts/security/service-accounts/
- **Configure Service Accounts for Pods** **[bookmark]** -- binding a ServiceAccount to a Pod, projected token volumes, and `automountServiceAccountToken`: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- **Managing Service Accounts** -- the TokenRequest API, time-bound projected tokens, and why legacy Secret-based tokens are gone: https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/
- **kubectl create token** -- mint a short-lived token on demand (`--duration`, `--bound-object-kind`): https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/
- **Authenticating -- Service Account Tokens** -- the JWT claims (iss, sub, aud, exp) you'll decode in the demo: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens

---

## Module 3 -- Admission Controls, Resource Limits, and Governance

- **Admission Control in Kubernetes** **[bookmark]** -- how controllers intercept and validate API requests before they reach etcd; the full plugin list: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
- **Limit Ranges** **[bookmark]** -- default and max/min CPU and memory requests and limits per namespace: https://kubernetes.io/docs/concepts/policy/limit-range/
- **Resource Quotas** **[bookmark]** -- cap total consumption per namespace; the Forbidden error when you exceed it: https://kubernetes.io/docs/concepts/policy/resource-quotas/
- **Resource Management for Pods and Containers** -- how requests and limits actually behave, the pairing a LimitRange fills in: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- **Configure a Security Context for a Pod or Container** **[bookmark]** -- `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- **Pod Security Standards** -- the Privileged, Baseline, and Restricted profiles the exam expects you to know: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- **Pod Security Admission** -- the built-in enforcer: namespace labels for enforce / audit / warn: https://kubernetes.io/docs/concepts/security/pod-security-admission/
- **Enforce Pod Security Standards with the Built-In Admission Controller** -- the hands-on task behind the demo's root-Pod rejection: https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/
- **Validating Admission Policy (enrichment)** -- GA in-tree policy with CEL (`admissionregistration.k8s.io/v1`), default-enabled in v1.35; know it exists, but it is not a named CKA objective: https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/

---

## Version and currency notes (v1.35)

Kubernetes moves fast, so a few facts a stale study guide will get wrong:

- **Validating Admission Policy** is **GA** on `admissionregistration.k8s.io/v1` and default-enabled since v1.30; **Mutating Admission Policy** is still **beta and off by default** in v1.35 -- treat it as mention-only.
- **PodSecurityPolicy (PSP) is removed.** The current answer is always **Pod Security Admission** plus the Pod Security Standards.
- **Legacy Secret-based ServiceAccount tokens**: auto-generation stopped in v1.24, and since v1.29 unused legacy tokens are actively invalidated and purged. Prefer `kubectl create token` and projected tokens.
- The docs at `kubernetes.io/docs` always render the current release; if you're studying on an older cluster, cross-check the version selector.

*Curated and validated 2026-07-05 against kubernetes.io (release-1.35) and the Context7 Kubernetes docs index. Tim Warner -- Pluralsight CKA Skill Path.*
