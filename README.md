# aap-gateway Helm Chart

Helm chart for deploying [Ansible Automation Platform](https://www.redhat.com/en/technologies/management/ansible) 2.6 on Red Hat OpenShift via the `AnsibleAutomationPlatform` operator CR.

The chart renders a single `AnsibleAutomationPlatform` CR. The AAP Operator reconciles it and manages all child resources (AutomationController, EDA, Hub, database, Redis).

## Prerequisites

- Red Hat OpenShift 4.x
- AAP Operator installed in the target namespace
- Helm 3.x

## Quickstart

```bash
helm install aap-gateway . \
  --set namespace=aap
```

Or with a values file:

```bash
helm install aap-gateway . -f my-values.yaml
helm upgrade aap-gateway . -f my-values.yaml
```

Only `namespace` is required. `hostname` is optional — if omitted, the AAP operator auto-generates a route hostname from the CR name. The chart explicitly sets a small number of fields (`no_log`, `redis_mode`, route TLS termination, and API replicas/log level); everything else is left to the operator defaults.

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
| [`complex-crd-coverage.yaml`](./examples/complex-crd-coverage.yaml) | Exhaustive CRD field coverage across all components (2.6 only) |

## Components

The chart supports four components. All are **enabled by default**, matching the AAP Gateway operator behavior. Set `disabled: true` to skip a component.

| Component | Key | Default |
|-----------|-----|---------|
| Gateway API | always on | — |
| AutomationController | `controller.disabled` | `false` (enabled) |
| Event-Driven Ansible | `eda.disabled` | `false` (enabled) |
| Automation Hub | `hub.disabled` | `false` (enabled) |

Enable components in your values file:

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

Any field from the component's own CRD spec can be set directly under the component key — no nesting required:

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
  web_resource_requirements:
    requests:
      cpu: "250m"
      memory: "512Mi"
```

Refer to the CRD definitions in [`crds/`](./crds/) for all available fields (reference only — CRDs are installed by the AAP Operator, not this chart).

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
route_tls_termination_mechanism: Edge  # Edge | Passthrough | Reencrypt
route_tls_secret: my-tls-secret        # optional — operator generates a cert if omitted
```

For standard Kubernetes Ingress:

```yaml
ingress_type: ingress
ingress_class_name: nginx
ingress_tls_secret: my-tls-secret
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

## Private Registry

```yaml
image_pull_secrets:
  - my-pull-secret

redhat_registry: my-mirror.example.com
redhat_registry_ns: ansible-automation-platform-26
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
| Any `AutomationController` spec field | — | Passed through directly (see `crds/automationcontrollers.yaml`) |

### EDA (`eda.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `eda.disabled` | `false` | Disable Event-Driven Ansible |
| `eda.automation_server_url` | `""` | AutomationController URL — operator auto-discovers if empty |
| `eda.extra_settings` | `[]` | Extra settings `[{setting, value}]` |
| Any `EDA` spec field | — | Passed through directly (see `crds/edas.yaml`) |

### Hub (`hub.*`)

| Key | Default | Description |
|-----|---------|-------------|
| `hub.disabled` | `false` | Disable Automation Hub |
| `hub.file_storage_storage_class` | `""` | StorageClass for Hub PVC |
| `hub.file_storage_size` | `""` | PVC size (e.g. `100Gi`) |
| `hub.file_storage_access_mode` | `""` | PVC access mode (`ReadWriteMany` for multi-replica) |
| `hub.content.replicas` | `2` | Hub content service replicas |
| `hub.worker.replicas` | `2` | Hub worker replicas |
| Any `AutomationHub` spec field | — | Passed through directly (see `crds/automationhubs.yaml`) |

### Global Escape Hatches

| Key | Default | Description |
|-----|---------|-------------|
| `extra_settings` | `[]` | Global settings `[{setting, value}]` for the Gateway |
| `feature_flags` | `{}` | Feature flags — keys must start with `FEATURE_` |
| `extraSpec` | `{}` | Fields deep-merged last into the CR spec. Nested keys are merged recursively — `extraSpec.api.strategy` adds to the rendered `api` block without dropping `api.replicas`. |

## Release Branches

| Branch | AAP Version |
|--------|-------------|
| `main` | Latest stable — read-only FF pointer to current release branch |
| `release-2.5` | AAP 2.5 |
| `release-2.6` | AAP 2.6 |
