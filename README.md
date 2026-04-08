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

> **Note — string-typed complex fields:** The child CRDs (`AutomationController`, `EDA`, `AutomationHub`) declare several fields that look like objects or arrays but are actually `type: string` (JSON-encoded). This includes `node_selector`, `topology_spread_constraints`, `service_annotations`, `ingress_annotations`, and `service_account_annotations`. Passing these as native YAML through the component pass-through will cause the child CR admission webhook to reject them. Use `extraSpec` with pre-serialized JSON strings instead:
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

## Values Reference

### Identity

| Key | Default | Description |
|-----|---------|-------------|
| `name` | `aap` | Name of the `AnsibleAutomationPlatform` CR |
| `namespace` | — | **Required.** Target namespace |
| `hostname` | `""` | Public hostname for the Gateway UI. Optional — operator auto-generates if omitted |

### Global

| Key | Default | Description |
|-----|---------|-------------|
| `no_log` | `true` | Suppress sensitive output in operator logs |
| `idle_aap` | `false` | Mark instance as passive (active-passive failover) |
| `redis_mode` | `standalone` | `standalone` or `cluster` |
| `image_pull_policy` | `IfNotPresent` | `Always`, `Never`, or `IfNotPresent` |
| `image_pull_secrets` | `[]` | Pull secret names for private registries |

### Images

Override operator-default images. Leave empty to use operator defaults.

| Key | Default | Description |
|-----|---------|-------------|
| `image` | `""` | Gateway image |
| `image_version` | `""` | Gateway image tag |
| `postgres_image` | `""` | PostgreSQL image |
| `postgres_image_version` | `""` | PostgreSQL image tag |
| `redis_image` | `""` | Redis image |
| `redis_image_version` | `""` | Redis image tag |
| `redhat_registry` | `""` | Override default Red Hat registry (`registry.redhat.io`) |
| `redhat_registry_ns` | `""` | Override default registry namespace |

### Networking

| Key | Default | Description |
|-----|---------|-------------|
| `hostname` | `""` | Public hostname. Optional — operator auto-generates if omitted |
| `public_base_url` | `""` | Override the public base URL if different from hostname |
| `route_tls_termination_mechanism` | `Edge` | `Edge` or `Passthrough` |
| `route_tls_secret` | `""` | TLS secret for the Route. Operator generates a cert if omitted |
| `route_host` | `""` | Explicit route hostname (alternative to `hostname`) |
| `route_annotations` | `{}` | Annotations added to the Route object |
| `ingress_type` | `""` | Set to `ingress` to use Kubernetes Ingress instead of Route |
| `ingress_class_name` | `""` | Ingress class (e.g. `nginx`) |
| `ingress_path` | `""` | Ingress path (e.g. `/`) |
| `ingress_path_type` | `""` | `Prefix`, `Exact`, or `ImplementationSpecific` |
| `ingress_tls_secret` | `""` | TLS secret for Ingress |
| `ingress_annotations` | `{}` | Annotations added to the Ingress object |
| `service_type` | `""` | `ClusterIP`, `NodePort`, or `LoadBalancer` |
| `service_annotations` | `{}` | Annotations added to the Service |
| `service_account_annotations` | `{}` | Annotations added to the ServiceAccount |
| `loadbalancer_port` | `443` | LoadBalancer port (only used when `service_type=LoadBalancer`) |
| `loadbalancer_protocol` | `https` | `http` or `https` |

### Gateway API (`api.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `api.replicas` | `1` | Number of gateway API pod replicas |
| `api.log_level` | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `api.resource_requirements` | `{}` | CPU/memory requests and limits |
| `api.node_selector` | `{}` | Node selector |
| `api.tolerations` | `[]` | Tolerations |
| `api.topology_spread_constraints` | `[]` | Topology spread constraints |
| `api.strategy` | `{}` | Deployment update strategy |

### Database (`database.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `database.database_secret` | `""` | External DB secret name. If set, operator skips deploying PostgreSQL |
| `database.postgres_storage_class` | `""` | StorageClass for database PVC |
| `database.postgres_ssl_mode` | `""` | `disable`, `require`, `verify-ca`, `verify-full` |
| `database.postgres_data_volume_init` | `false` | Run initContainer to fix PVC permissions |
| `database.postgres_keep_pvc_after_upgrade` | `false` | Retain PVC across operator upgrades |
| `database.postgres_init_container_commands` | `""` | Additional shell commands to run in the init container |
| `database.postgres_extra_settings` | `[]` | Extra PostgreSQL config `[{setting, value}]` |
| `database.idle_disabled` | `false` | Disable DB when `idle_aap=true` |
| `database.priority_class` | `""` | PriorityClass for database pod |
| `database.resource_requirements` | `{}` | CPU/memory requests and limits |
| `database.storage_requirements` | `{}` | PVC storage requests and limits |
| `database.node_selector` | `{}` | Node selector |
| `database.tolerations` | `[]` | Tolerations |

### Redis (`redis.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `redis.redis_secret` | `""` | External Redis secret. If set, operator skips deploying Redis |
| `redis.eda_redis_secret` | `""` | Separate Redis secret for EDA |
| `redis.replicas` | `1` | Replicas (cluster mode only) |
| `redis.resource_requirements` | `{}` | CPU/memory requests and limits |
| `redis.node_selector` | `{}` | Node selector |
| `redis.tolerations` | `[]` | Tolerations |

### Controller (`controller.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `controller.disabled` | `false` | Disable AutomationController |
| `controller.extra_settings` | `[]` | Extra settings `[{setting, value}]` |
| Any `AutomationController` spec field | — | Passed through directly (see [`crds/<version>/automationcontrollers.yaml`](./crds/)) |

### EDA (`eda.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `eda.disabled` | `false` | Disable Event-Driven Ansible |
| `eda.automation_server_url` | `""` | AutomationController URL — operator auto-discovers if empty |
| `eda.extra_settings` | `[]` | Extra settings `[{setting, value}]` |
| Any `EDA` spec field | — | Passed through directly (see [`crds/<version>/edas.yaml`](./crds/)) |

### Hub (`hub.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `hub.disabled` | `false` | Disable Automation Hub |
| `hub.file_storage_storage_class` | `""` | StorageClass for Hub PVC |
| `hub.file_storage_size` | `""` | PVC size (e.g. `100Gi`) |
| `hub.file_storage_access_mode` | `""` | PVC access mode (`ReadWriteMany` for multi-replica) |
| `hub.content.replicas` | `2` | Hub content service replicas |
| `hub.worker.replicas` | `2` | Hub worker replicas |
| Any `AutomationHub` spec field | — | Passed through directly (see [`crds/<version>/automationhubs.yaml`](./crds/)) |

### Global Escape Hatches

| Key | Default | Description |
|-----|---------|-------------|
| `extra_settings` | `[]` | Global settings `[{setting, value}]` for the Gateway |
| `feature_flags` | `{}` | Feature flags — keys must start with `FEATURE_` |
| `extraSpec` | `{}` | Fields deep-merged last into the CR spec. Nested keys are merged recursively — `extraSpec.api.strategy` adds to the rendered `api` block without dropping `api.replicas`. |

## Versioning

Chart versioning is independent of the AAP operator version. A single chart works across AAP 2.5 and 2.6+.

| Chart version | AAP compatibility |
|---------------|-------------------|
| `1.0.x` | AAP 2.5, 2.6 |

The chart is published automatically to Quay whenever `Chart.yaml` is updated on `main`.
