# aap-gateway Helm Chart

Helm chart for deploying [Ansible Automation Platform](https://www.redhat.com/en/technologies/management/ansible) on Red Hat OpenShift via the `AnsibleAutomationPlatform` operator CR.

## Prerequisites

- Red Hat OpenShift 4.x
- AAP Operator installed in the target namespace (installs the `AnsibleAutomationPlatform` CRD)
- Helm 3.x

## Install

```bash
helm install aap-gateway . \
  --set namespace=my-aap \
  --set hostname=aap.apps.cluster.example.com
```

## Upgrade

```bash
helm upgrade aap-gateway . -f my-values.yaml
```

## Values

All configuration is through `values.yaml`. Every field is optional except `namespace` and `hostname`.

### Identity

| Key | Default | Description |
|-----|---------|-------------|
| `name` | `aap` | Name of the `AnsibleAutomationPlatform` CR |
| `namespace` | `""` | **REQUIRED.** Target namespace |

### Global

| Key | Default | Description |
|-----|---------|-------------|
| `image_pull_policy` | `IfNotPresent` | Image pull policy for all AAP components. One of `Always`, `Never`, `IfNotPresent` |
| `image_pull_secrets` | `[]` | List of image pull secret names for private registries |
| `no_log` | `true` | Suppress sensitive output in operator logs |
| `idle_aap` | `false` | Mark instance as passive for active-passive failover |
| `redis_mode` | `standalone` | Redis mode: `standalone` or `cluster` |

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

### Registry

| Key | Default | Description |
|-----|---------|-------------|
| `redhat_registry` | `""` | Override default Red Hat registry (`registry.redhat.io`) |
| `redhat_registry_ns` | `""` | Override default registry namespace |

### Secrets

| Key | Default | Description |
|-----|---------|-------------|
| `admin_password_secret` | `""` | Name of existing Secret with admin password |
| `bundle_cacert_secret` | `""` | Name of Secret containing custom CA bundle |
| `db_fields_encryption_secret` | `""` | Name of Secret for database field encryption key |

### Networking

| Key | Default | Description |
|-----|---------|-------------|
| `hostname` | `""` | **REQUIRED.** Public hostname for the AAP Gateway UI |
| `public_base_url` | `""` | Override base URL if different from `hostname` |
| `route_tls_termination_mechanism` | `Edge` | OpenShift Route TLS mode: `Edge`, `Passthrough`, `Reencrypt` |
| `route_tls_secret` | `""` | Name of TLS secret for the Route |
| `route_host` | `""` | Override Route hostname |
| `route_annotations` | `{}` | Annotations for the Route |
| `ingress_type` | `""` | Ingress type for non-OpenShift clusters |
| `ingress_class_name` | `""` | IngressClass name |
| `ingress_path` | `/` | Ingress path |
| `ingress_path_type` | `Prefix` | Ingress path type |
| `ingress_tls_secret` | `""` | Name of TLS secret for Ingress |
| `ingress_annotations` | `{}` | Annotations for the Ingress |
| `service_type` | `""` | Service type: `ClusterIP`, `NodePort`, or `LoadBalancer` |
| `service_annotations` | `{}` | Annotations for the Service |
| `service_account_annotations` | `{}` | Annotations for the ServiceAccount |
| `loadbalancer_port` | `443` | Port for LoadBalancer service |
| `loadbalancer_protocol` | `https` | Protocol for LoadBalancer: `http` or `https` |

### Gateway API

| Key | Default | Description |
|-----|---------|-------------|
| `api.replicas` | `1` | Number of gateway API pod replicas |
| `api.log_level` | `INFO` | Log level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `api.resource_requirements.requests.cpu` | `""` | CPU request |
| `api.resource_requirements.requests.memory` | `""` | Memory request |
| `api.resource_requirements.limits.cpu` | `""` | CPU limit |
| `api.resource_requirements.limits.memory` | `""` | Memory limit |
| `api.node_selector` | `{}` | Node selector for gateway API pods |
| `api.tolerations` | `[]` | Tolerations for gateway API pods |
| `api.topology_spread_constraints` | `[]` | Topology spread constraints |
| `api.strategy` | `{}` | Deployment update strategy |

### Gateway Database

| Key | Default | Description |
|-----|---------|-------------|
| `database.database_secret` | `""` | Name of Secret for external PostgreSQL. If set, operator uses external DB |
| `database.postgres_storage_class` | `""` | StorageClass for database PVC |
| `database.postgres_ssl_mode` | `""` | PostgreSQL SSL mode |
| `database.postgres_data_volume_init` | `false` | Run initContainer to set PVC permissions |
| `database.postgres_keep_pvc_after_upgrade` | `false` | Retain PVC across upgrades |
| `database.postgres_init_container_commands` | `""` | Extra commands in the DB init container |
| `database.postgres_extra_settings` | `[]` | Extra PostgreSQL config `[{setting, value}]` |
| `database.idle_disabled` | `false` | Disable DB when `idle_aap=true` |
| `database.priority_class` | `""` | PriorityClass for database pod |
| `database.resource_requirements.*` | `""` | CPU/memory requests and limits |
| `database.storage_requirements.requests.storage` | `""` | Storage request for PVC |
| `database.storage_requirements.limits.storage` | `""` | Storage limit for PVC |
| `database.node_selector` | `{}` | Node selector for database pod |
| `database.tolerations` | `[]` | Tolerations for database pod |

### Gateway Redis

| Key | Default | Description |
|-----|---------|-------------|
| `redis.redis_secret` | `""` | Name of Secret for external Redis. If set, operator uses external Redis |
| `redis.eda_redis_secret` | `""` | Separate Redis secret for EDA |
| `redis.replicas` | `1` | Number of Redis replicas (cluster mode) |
| `redis.resource_requirements.*` | `""` | CPU/memory requests and limits |
| `redis.node_selector` | `{}` | Node selector for Redis pod |
| `redis.tolerations` | `[]` | Tolerations for Redis pod |

### Components

Each component maps to a child CR managed by the AAP operator. Set `disabled: false` to enable.

#### Controller (AutomationController)

| Key | Default | Description |
|-----|---------|-------------|
| `controller.disabled` | `false` | Disable AutomationController deployment |
| `controller.extra_settings` | `[]` | Extra settings `[{setting, value}]` |
| `controller.extraSpec` | `{}` | Any `AutomationController` spec field (see `crds/automationcontroller.yaml`) |

#### EDA (Event-Driven Ansible)

| Key | Default | Description |
|-----|---------|-------------|
| `eda.disabled` | `true` | Disable EDA deployment |
| `eda.automation_server_url` | `""` | **REQUIRED if `eda.disabled=false`.** AutomationController URL |
| `eda.extra_settings` | `[]` | Extra settings `[{setting, value}]` |
| `eda.extraSpec` | `{}` | Any EDA spec field (see `crds/eda.yaml`) |

#### Hub (Automation Hub)

| Key | Default | Description |
|-----|---------|-------------|
| `hub.disabled` | `true` | Disable Automation Hub deployment |
| `hub.file_storage_size` | `100Gi` | Size of Hub file storage PVC |
| `hub.file_storage_access_mode` | `ReadWriteMany` | PVC access mode |
| `hub.file_storage_storage_class` | `""` | StorageClass for Hub PVC |
| `hub.content.replicas` | `1` | Hub content service replicas |
| `hub.worker.replicas` | `1` | Hub worker replicas |
| `hub.gunicorn_api_workers` | `1` | Gunicorn workers for Hub API |
| `hub.gunicorn_content_workers` | `1` | Gunicorn workers for Hub content |
| `hub.extraSpec` | `{}` | Any Hub spec field |

#### Lightspeed

| Key | Default | Description |
|-----|---------|-------------|
| `lightspeed.disabled` | `true` | Disable Lightspeed deployment |
| `lightspeed.chatbot_config_secret_name` | `""` | Secret with Lightspeed chatbot config |
| `lightspeed.extraSpec` | `{}` | Any Lightspeed spec field (see `crds/lightspeed.yaml`) |

#### MCP

| Key | Default | Description |
|-----|---------|-------------|
| `mcp.disabled` | `true` | Disable MCP server deployment |
| `mcp.allow_write_operations` | `false` | Allow MCP write operations |
| `mcp.image` | `""` | MCP server image |
| `mcp.image_version` | `""` | MCP server image tag |
| `mcp.extraSpec` | `{}` | Any MCP spec field |

### Global Escape Hatches

| Key | Default | Description |
|-----|---------|-------------|
| `extra_settings` | `[]` | Global settings `[{setting, value}]` for the Gateway |
| `feature_flags` | `{}` | Feature flags map. Keys must start with `FEATURE_` |
| `extraSpec` | `{}` | Arbitrary fields merged last into the `AnsibleAutomationPlatform` spec, overriding anything above |

## Using extraSpec

To set any operator field not explicitly modeled in `values.yaml`:

```yaml
# Top-level field override
extraSpec:
  some_operator_field: value

# Component-level field (passes into AutomationController spec)
controller:
  extraSpec:
    task_privileged: true
    web_replicas: 2
```

## External Database

```yaml
database:
  database_secret: my-postgres-secret
```

The Secret must contain: `host`, `port`, `database`, `username`, `password`.

## Active-Passive Failover

```yaml
idle_aap: true
database:
  idle_disabled: true
```

## Release Branches

| Branch | AAP Version |
|--------|-------------|
| `main` | Development |
| `release-2.6` | AAP 2.6 |
| `release-2.7` | AAP 2.7 (future) |
