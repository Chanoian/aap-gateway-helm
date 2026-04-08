# aap-gateway Helm Chart

[![Helm Lint](https://github.com/Chanoian/aap-gateway-helm/actions/workflows/helm-lint.yml/badge.svg?branch=main)](https://github.com/Chanoian/aap-gateway-helm/actions/workflows/helm-lint.yml)
[![Helm Publish](https://github.com/Chanoian/aap-gateway-helm/actions/workflows/helm-publish.yml/badge.svg?branch=main)](https://github.com/Chanoian/aap-gateway-helm/actions/workflows/helm-publish.yml)

A community Helm chart for deploying [Ansible Automation Platform](https://www.redhat.com/en/technologies/management/ansible) on Red Hat OpenShift. Compatible with **AAP 2.5 and 2.6+**.

The chart renders a single `AnsibleAutomationPlatform` CR. The AAP Operator reconciles it and manages all child resources (AutomationController, EDA, Hub, database, Redis). You bring the values — the operator does the rest.

## Prerequisites

- Red Hat OpenShift 4.x
- AAP Operator installed in the target namespace
- Helm 3.x

## Installation

### From Quay (recommended)

The chart is published to [quay.io/achanoia/aap-gateway](https://quay.io/achanoia/aap-gateway) on every version bump.

```bash
# Install a specific version
helm install aap-gateway oci://quay.io/achanoia/aap-gateway \
  --version 1.0.1 \
  -f my-values.yaml \
  --set namespace=aap \
  -n aap --create-namespace

# Upgrade
helm upgrade aap-gateway oci://quay.io/achanoia/aap-gateway \
  --version 1.0.1 \
  -f my-values.yaml \
  --set namespace=aap \
  -n aap
```

> **Note:** `--set namespace=aap` sets the chart value `.Values.namespace`, which the chart requires to render the CR. The `-n aap` flag is the Helm release namespace and is independent — omitting `namespace` from your values will cause the install to fail with `namespace is required and must not be empty`. Set it in your values file to avoid passing `--set` every time:
> ```yaml
> namespace: aap
> ```

Available tags on Quay:

| Tag | Description |
|-----|-------------|
| `1.0.1` | Exact patch version — use this for pinned, reproducible installs |
| `1.0` | Minor alias — always points to the latest `1.0.x` patch |

### From Source

Clone the repo and install directly — useful for development or customization:

```bash
git clone https://github.com/Chanoian/aap-gateway-helm.git
cd aap-gateway-helm

helm install aap-gateway . -f my-values.yaml -n aap --create-namespace
helm upgrade aap-gateway . -f my-values.yaml -n aap
```

`namespace` is required and must be set in your values file (or via `--set namespace=aap`). `hostname` is optional — if omitted, the AAP operator auto-generates a route hostname from the CR name.

## Examples

Ready-to-use values files are in [`examples/`](./examples/):

| File | Description |
|------|-------------|
| [`minimal.yaml`](./examples/minimal.yaml) | Namespace only — operator auto-generates hostname |
| [`controller-only.yaml`](./examples/controller-only.yaml) | Hub and EDA disabled |
| [`full-stack.yaml`](./examples/full-stack.yaml) | All components, internal DB/Redis |
| [`external-db.yaml`](./examples/external-db.yaml) | External database Secret pattern |
| [`full-stack-external-db-resources.yaml`](./examples/full-stack-external-db-resources.yaml) | Full stack with resource limits and external DB |
| [`hub-advanced.yaml`](./examples/hub-advanced.yaml) | Hub nested fields (`content.*`, `worker.*`) |
| [`explicit-zero-replicas.yaml`](./examples/explicit-zero-replicas.yaml) | Verifies `replicas: 0` passes through correctly |
| [`complex-crd-coverage.yaml`](./examples/complex-crd-coverage.yaml) | Exhaustive CRD field coverage across all components |
| [`testing-full-stack.yaml`](./examples/testing-full-stack.yaml) | All components, labels/annotations, resource limits, internal DB |

## Components

The chart supports four components. All are **enabled by default**, matching the AAP Gateway operator behavior. Set `disabled: true` to skip a component.

| Component | Key | Default |
|-----------|-----|---------|
| Gateway API | always on | — |
| AutomationController | `controller.disabled` | `false` (enabled) |
| Event-Driven Ansible | `eda.disabled` | `false` (enabled) |
| Automation Hub | `hub.disabled` | `false` (enabled) |

```yaml
controller:
  disabled: false

eda:
  disabled: false

hub:
  disabled: false
  file_storage_storage_class: my-storage-class
```

### Component pass-through

Any field from the component's own CRD spec can be set directly under the component key:

```yaml
controller:
  web_resource_requirements:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "2Gi"
  task_resource_requirements:
    requests:
      cpu: "250m"
      memory: "512Mi"
  task_privileged: true

hub:
  web:
    resource_requirements:
      requests:
        cpu: "250m"
        memory: "512Mi"
```

Refer to the CRD definitions in [`crds/`](./crds/) for all available fields per AAP version (reference only — CRDs are installed by the AAP Operator, not this chart).

> **Note — string-typed complex fields:** Some fields in the child CRDs (`AutomationController`, `EDA`, `AutomationHub`) look like objects or arrays but are declared as `type: string` (JSON-encoded). Passing these as native YAML will cause the child CR admission webhook to reject them. Before setting any structured-looking field on a component, check its type in `crds/<version>/`. If it says `type: string`, pass it as a pre-serialized JSON string via `extraSpec`:
>
> ```yaml
> extraSpec:
>   controller:
>     node_selector: '{"node-role.kubernetes.io/worker":""}'
>     service_annotations: '{"app.kubernetes.io/managed-by":"helm"}'
>   hub:
>     node_selector: '{"node-role.kubernetes.io/worker":""}'
> ```

## Database

### Internal (default)

The operator deploys and manages a PostgreSQL pod automatically. Tune it with:

```yaml
database:
  postgres_storage_class: my-storage-class
  postgres_keep_pvc_after_upgrade: true
  resource_requirements:
    requests:
      cpu: "500m"
      memory: "1Gi"
  storage_requirements:
    requests:
      storage: "20Gi"
```

### External

Point to a pre-existing PostgreSQL instance:

```yaml
database:
  database_secret: my-postgres-secret
```

The Secret must contain: `host`, `port`, `database`, `username`, `password`.

## Redis

By default the operator deploys a standalone Redis pod. Override with an external instance:

```yaml
redis:
  redis_secret: my-redis-secret
```

For cluster mode:

```yaml
redis_mode: cluster
redis:
  replicas: 3
```

## Networking

The chart defaults to an OpenShift Route with Edge TLS termination. The hostname drives both the Route and the Gateway's public URL.

```yaml
hostname: aap.apps.cluster.example.com
route_tls_termination_mechanism: Edge  # Edge | Passthrough
route_tls_secret: my-tls-secret        # optional — operator generates a cert if omitted
```

For standard Kubernetes Ingress:

```yaml
ingress_type: ingress
ingress_class_name: nginx
ingress_path: /
ingress_path_type: Prefix
ingress_tls_secret: my-tls-secret
```

For LoadBalancer:

```yaml
service_type: LoadBalancer
loadbalancer_port: 443
loadbalancer_protocol: https  # http | https
```

## Resource Requirements

Set CPU and memory on gateway-managed pods directly in values:

```yaml
api:
  replicas: 2
  resource_requirements:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "1Gi"

database:
  resource_requirements:
    requests:
      cpu: "500m"
      memory: "1Gi"

redis:
  resource_requirements:
    requests:
      cpu: "100m"
      memory: "256Mi"
```

For component pods (controller, eda, hub), use the component pass-through as shown above.

## Secrets

| Value | Description |
|-------|-------------|
| `admin_password_secret` | Existing Secret with `password` key — operator sets admin password from it |
| `bundle_cacert_secret` | Secret with a custom CA bundle for TLS verification |
| `db_fields_encryption_secret` | Secret for database field-level encryption key |

## Active-Passive Failover

```yaml
idle_aap: true
database:
  idle_disabled: true
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| admin_password_secret | string | `""` | Name of an existing Secret containing the `password` key — operator sets the admin password from it. |
| api.log_level | string | `"INFO"` | Python logging level. One of `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. |
| api.node_selector | object | `{}` | Node selector for Gateway API pods. |
| api.replicas | int | `1` | Number of Gateway API pod replicas. |
| api.resource_requirements | object | `{"limits":{"cpu":"","memory":""},"requests":{"cpu":"","memory":""}}` | CPU/memory requests and limits for Gateway API pods. |
| api.strategy | object | `{}` | Deployment update strategy. |
| api.tolerations | list | `[]` | Tolerations for Gateway API pods. |
| api.topology_spread_constraints | list | `[]` | Topology spread constraints for Gateway API pods. |
| bundle_cacert_secret | string | `""` | Name of a Secret containing a custom CA bundle for TLS verification. |
| controller.disabled | bool | `false` | Set `true` to disable AutomationController. |
| controller.extra_settings | list | `[]` | Extra settings injected into controller config. Each item: `{setting: "name", value: "value"}`. |
| database.database_secret | string | `""` | Name of an existing Secret with external DB connection info (`host`, `port`, `database`, `username`, `password`). If set, the operator skips deploying PostgreSQL. |
| database.idle_disabled | bool | `false` | Disable the database when `idle_aap=true` (active-passive). |
| database.node_selector | object | `{}` | Node selector for the database pod. |
| database.postgres_data_volume_init | bool | `false` | Run an initContainer to set correct PVC permissions. |
| database.postgres_extra_settings | list | `[]` | Extra PostgreSQL configuration settings. Each item: `{setting: "name", value: "value"}`. |
| database.postgres_init_container_commands | string | `""` | Additional shell commands to run in the database init container. |
| database.postgres_keep_pvc_after_upgrade | bool | `false` | Retain the database PVC across operator upgrades. |
| database.postgres_ssl_mode | string | `""` | PostgreSQL SSL mode. One of `disable`, `require`, `verify-ca`, `verify-full`. |
| database.postgres_storage_class | string | `""` | StorageClass for the database PVC (internal DB only). |
| database.priority_class | string | `""` | PriorityClass name for the database pod. |
| database.resource_requirements | object | `{"limits":{"cpu":"","memory":""},"requests":{"cpu":"","memory":""}}` | CPU/memory requests and limits for the database pod. |
| database.storage_requirements | object | `{"limits":{"storage":""},"requests":{"storage":""}}` | Storage size for the database PVC. |
| database.tolerations | list | `[]` | Tolerations for the database pod. |
| db_fields_encryption_secret | string | `""` | Name of a Secret for database field-level encryption key. |
| eda.automation_server_url | string | `""` | URL of the AutomationController. Operator auto-discovers if left empty. |
| eda.disabled | bool | `false` | Set `true` to disable Event-Driven Ansible. |
| eda.extra_settings | list | `[]` | Extra settings injected into EDA config. Each item: `{setting: "name", value: "value"}`. |
| extraSpec | object | `{}` | Arbitrary fields deep-merged last into the `AnsibleAutomationPlatform` spec. Nested keys are merged recursively. |
| extra_settings | list | `[]` | Global list of `{setting, value}` pairs for the Gateway. |
| feature_flags | object | `{}` | Feature flags. Keys must start with `FEATURE_`. |
| hostname | string | `""` | Public hostname for the AAP Gateway UI (e.g. `aap.apps.cluster.example.com`). Optional — operator auto-generates a route hostname if omitted. |
| hub.content.replicas | int | `2` | Number of Hub content service replicas. |
| hub.disabled | bool | `false` | Set `true` to disable Automation Hub. |
| hub.file_storage_access_mode | string | `""` | PVC access mode. Use `ReadWriteMany` for multi-replica deployments. |
| hub.file_storage_size | string | `""` | Size of the Hub file storage PVC (e.g. `100Gi`). |
| hub.file_storage_storage_class | string | `""` | StorageClass for the Hub file storage PVC. |
| hub.worker.replicas | int | `2` | Number of Hub worker replicas. |
| idle_aap | bool | `false` | Set `true` to mark this instance as passive (active-passive failover). |
| image | string | `""` | Override the operator-default Gateway image. Leave empty to use the operator default. |
| image_pull_policy | string | `"IfNotPresent"` | Image pull policy applied to all AAP component images. One of `Always`, `Never`, `IfNotPresent`. |
| image_pull_secrets | list | `[]` | List of Secret names for pulling images from private registries. |
| image_version | string | `""` | Override the operator-default Gateway image tag. |
| ingress_annotations | object | `{}` | Annotations to add to the Ingress object. |
| ingress_class_name | string | `""` | Ingress class name (e.g. `nginx`). |
| ingress_path | string | `""` | Ingress path (e.g. `/`). |
| ingress_path_type | string | `""` | Ingress path type. One of `Prefix`, `Exact`, `ImplementationSpecific`. |
| ingress_tls_secret | string | `""` | Name of the TLS Secret for Ingress. |
| ingress_type | string | `""` | Set to `ingress` to use Kubernetes Ingress instead of an OpenShift Route. |
| loadbalancer_port | int | `443` | LoadBalancer port. Only used when `service_type=LoadBalancer`. |
| loadbalancer_protocol | string | `"https"` | LoadBalancer protocol. One of `http`, `https`. Only used when `service_type=LoadBalancer`. |
| name | string | `"aap"` | Name of the `AnsibleAutomationPlatform` CR. Must be unique per namespace. |
| namespace | string | `""` | Target namespace for the CR. **Required.** |
| no_log | bool | `true` | Suppress sensitive output in operator logs. |
| postgres_image | string | `""` | Override the operator-default PostgreSQL image. |
| postgres_image_version | string | `""` | Override the operator-default PostgreSQL image tag. |
| public_base_url | string | `""` | Override the public base URL if different from hostname. |
| redhat_registry | string | `""` | Override the default Red Hat registry (`registry.redhat.io`). |
| redhat_registry_ns | string | `""` | Override the default registry namespace. |
| redis.eda_redis_secret | string | `""` | Separate external Redis Secret for EDA (if different from the Gateway Redis). |
| redis.node_selector | object | `{}` | Node selector for the Redis pod. |
| redis.redis_secret | string | `""` | Name of an existing Secret for external Redis. If set, the operator skips deploying Redis. |
| redis.replicas | int | `1` | Number of Redis pod replicas. Only used in cluster mode. |
| redis.resource_requirements | object | `{"limits":{"cpu":"","memory":""},"requests":{"cpu":"","memory":""}}` | CPU/memory requests and limits for the Redis pod. |
| redis.tolerations | list | `[]` | Tolerations for the Redis pod. |
| redis_image | string | `""` | Override the operator-default Redis image. |
| redis_image_version | string | `""` | Override the operator-default Redis image tag. |
| redis_mode | string | `"standalone"` | Redis deployment mode. One of `standalone`, `cluster`. |
| route_annotations | object | `{}` | Annotations to add to the Route object. |
| route_host | string | `""` | Explicit route hostname (alternative to `hostname`). |
| route_tls_secret | string | `""` | Name of the TLS Secret for the Route. Operator generates a cert if omitted. |
| route_tls_termination_mechanism | string | `"Edge"` | Route TLS termination mechanism. One of `Edge`, `Passthrough`. |
| service_account_annotations | object | `{}` | Annotations to add to the ServiceAccount. |
| service_annotations | object | `{}` | Annotations to add to the Service. |
| service_type | string | `""` | Service type. One of `ClusterIP`, `NodePort`, `LoadBalancer`. |

## Contributing

After cloning, install the local git hooks:

```bash
bash hack/setup-hooks.sh
```

This installs a pre-commit hook that runs `helm-docs` (keeps README in sync with `values.yaml`) and `helm lint --strict` before every commit. Requires `helm` and `helm-docs` (`brew install helm-docs`).

## Versioning

Chart versioning is independent of the AAP operator version. A single chart works across AAP 2.5 and 2.6+.

| Chart version | AAP compatibility |
|---------------|-------------------|
| `1.0.x` | AAP 2.5, 2.6 |

The chart is published automatically to Quay whenever `Chart.yaml` is updated on `main`.
