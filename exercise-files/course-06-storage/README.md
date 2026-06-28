# Course 6 -- Managing Storage

[Skill path home](../../README.md)

**Course 6 of 11**  |  **CKA domain:** Storage (10%)  |  **Runtime:** ~75 min

Persist data in Kubernetes: Volumes, PersistentVolumes and Claims, StorageClasses with dynamic provisioning, and access modes for StatefulSet storage.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Volumes, PersistentVolumes, and PersistentVolumeClaims](m01-volumes-persistentvolumes-persistentvolumeclaims/README.md) | Volume types, the PV/PVC binding lifecycle, and mounting persistent storage into pods. | Coming as recorded |
| M02 | [StorageClasses and Dynamic Provisioning](m02-storage-classes-dynamic-provisioning/README.md) | StorageClasses, dynamic provisioning, and the default storage class. | Coming as recorded |
| M03 | [Access Modes, Reclaim Policies, and StatefulSet Storage](m03-access-modes-reclaim-policies-statefulset-storage/README.md) | Access modes, reclaim policies, and volumeClaimTemplates for StatefulSets. | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
