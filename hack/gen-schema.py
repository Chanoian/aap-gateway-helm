#!/usr/bin/env python3
"""
Generate values.schema.json by walking values.yaml and looking up
each field's type/enum in the CRD OpenAPI schemas.

values.yaml       → which fields exist (the chart's surface area)
crds/<version>/   → types and enums for those fields

Usage: python3 hack/gen-schema.py [--version 2.6]
       Defaults to the latest version found in crds/.
"""

import json
import sys
import argparse
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML not installed — pip3 install pyyaml")

REPO_ROOT = Path(__file__).parent.parent
OUTPUT    = REPO_ROOT / "values.schema.json"

parser = argparse.ArgumentParser()
parser.add_argument("--version", help="AAP version to use for CRDs (e.g. 2.5, 2.6). Defaults to latest.")
args = parser.parse_args()

if args.version:
    CRD_DIR = REPO_ROOT / "crds" / args.version
    if not CRD_DIR.is_dir():
        sys.exit(f"ERROR: crds/{args.version}/ not found")
else:
    # Pick the highest version directory available.
    # Use a numeric tuple key so 2.10 sorts after 2.9 (not before, as lexical sort would do).
    def version_key(name):
        try:
            return tuple(int(x) for x in name.split("."))
        except ValueError:
            return (0,)
    versions = sorted([p.name for p in (REPO_ROOT / "crds").iterdir() if p.is_dir()], key=version_key)
    if not versions:
        sys.exit("ERROR: no versioned CRD directories found under crds/")
    CRD_DIR = REPO_ROOT / "crds" / versions[-1]
    print(f"Using CRDs from crds/{versions[-1]}/ (latest)", file=sys.stderr)


def load_crd_props(filename, crd_dir=None):
    path = (crd_dir or CRD_DIR) / filename
    if not path.exists():
        print(f"WARNING: {path} not found", file=sys.stderr)
        return {}
    crd = yaml.safe_load(path.read_text())
    return (
        crd["spec"]["versions"][0]["schema"]
        ["openAPIV3Schema"]["properties"]["spec"]["properties"]
    )


def ref(name):
    return {"$ref": f"#/definitions/{name}"}


# ── Special-case rules (the only hardcoded knowledge in this script) ───────────
#
# When the AAP CRD changes, scan each list below and update accordingly.
# Each entry has a comment explaining WHY it's there so you can judge
# whether a new field belongs and whether an existing entry is still needed.

# Fields whose schema is replaced with a shared $ref definition from the
# "definitions" block at the bottom of the generated schema.  Add a field here
# when it shares structure with an existing definition (resourceRequirements /
# storageRequirements) rather than duplicating the nested object inline.
RESOURCE_REFS = {
    "resource_requirements": "resourceRequirements",
    "storage_requirements":  "storageRequirements",
}

# Fields the CRD declares as `type: string` (JSON-encoded by the operator) but
# that values.yaml exposes as native YAML objects for user convenience.
# The template serialises them with `toJson` before writing to the CR.
# Without this override, field_schema() would emit `type: string` from the CRD,
# causing `helm lint --strict` to reject the YAML-object syntax in values files.
# Add a field here when: the CRD says string, values.yaml uses an object/map,
# and the template calls toJson on it.
FORCE_OBJECT = {
    "route_annotations", "ingress_annotations",
    "service_annotations", "service_account_annotations",
}

# Fields that have a CRD enum but whose chart default is "" (meaning "let the
# operator choose").  The CRD enum doesn't include "", so without patching it in,
# `helm lint --strict` would reject any values file that leaves the field unset
# (the empty-string default would fail validation).
# Add a field here when: it has a CRD enum AND its values.yaml default is "".
OPTIONAL_ENUM = {"ingress_type", "service_type", "file_storage_access_mode", "redis_mode", "route_tls_termination_mechanism"}

# Fields that exist only at the chart level and have no equivalent in any CRD.
# These bypass the CRD lookup entirely and use a fixed schema.
# Add a field here when: it drives chart behaviour (e.g. metadata, escape hatches)
# but is never written into the AnsibleAutomationPlatform spec directly.
#   name      — becomes metadata.name on the rendered CR
#   namespace — becomes metadata.namespace on the rendered CR
#   extraSpec — deep-merged escape hatch for arbitrary spec fields not modelled in values.yaml
#   feature_flags — chart abstraction; the CRD has no feature_flags field.
#                   patternProperties enforces the FEATURE_ prefix required by the AAP API.
CHART_ONLY = {
    "name":      {"type": "string"},
    "namespace": {"type": "string"},
    "extraSpec": {"type": "object"},
    "feature_flags": {"type": "object", "additionalProperties": False, "patternProperties": {"^FEATURE_": {"type": "boolean"}}},
}

# Top-level keys in values.yaml that map to sub-objects rather than scalar fields.
# These are skipped in the top-level scalar walk and handled individually below
# (each section may draw from a different CRD source, e.g. hub uses automationhubs.yaml).
# Add a key here when you add a new structured sub-section to values.yaml.
SECTIONS = {"api", "database", "redis", "controller", "eda", "hub", "secretProvider"}


# ── Schema derivation ─────────────────────────────────────────────────────────

def infer_type(value):
    """Infer a JSON Schema type from a Python default value."""
    if isinstance(value, bool):   return {"type": "boolean"}
    if isinstance(value, int):    return {"type": "integer"}
    if isinstance(value, list):   return {"type": "array"}
    if isinstance(value, dict):   return {"type": "object"}
    return {"type": "string"}


def field_schema(key, value, crd_props):
    """
    Return the JSON Schema for one field:
    1. CHART_ONLY  → fixed schema
    2. RESOURCE_REFS → $ref
    3. FORCE_OBJECT  → {"type": "object"}
    4. CRD match     → CRD definition (pattern stripped, empty enum added if OPTIONAL_ENUM)
    5. fallback      → infer from default value
    """
    if key in CHART_ONLY:
        return CHART_ONLY[key]
    if key in RESOURCE_REFS:
        return ref(RESOURCE_REFS[key])
    if key in FORCE_OBJECT:
        return {"type": "object"}

    if key in crd_props:
        schema = {k: v for k, v in crd_props[key].items() if k != "pattern"}
        if key in OPTIONAL_ENUM and "enum" in schema and "" not in schema["enum"]:
            schema["enum"] = [""] + schema["enum"]
            schema.pop("default", None)
        return schema

    return infer_type(value)


def build_section(values_dict, crd_props):
    """Build a JSON Schema properties map for a section.

    Merges two sources so pass-through fields get type validation:
    - values.yaml keys: schema inferred from default value (and CRD when present)
    - CRD keys not in values.yaml: schema taken directly from the CRD

    Result: any field a user sets — whether modelled in values.yaml or passed
    through directly from the CRD spec — is type-checked by `helm lint --strict`.
    """
    props = {
        key: field_schema(key, value, crd_props)
        for key, value in values_dict.items()
    }
    for key, crd_schema in crd_props.items():
        if key in props:
            continue
        cleaned = {k: v for k, v in crd_schema.items() if k != "pattern"}
        props[key] = cleaned or {"type": "string"}
    return {"type": "object", "properties": props}


VSO_CRD_DIR = REPO_ROOT / "crds" / "vso"


def clean(props, key):
    """Return a JSON Schema entry from CRD props, stripping description and pattern."""
    p = props.get(key, {})
    return {k: v for k, v in p.items() if k not in ("description", "pattern")} or {"type": "string"}


def build_secret_provider_schema(values_sp, vconn, vauth, vss):
    ap = vauth.get("appRole", {}).get("properties", {})
    secret_entry = {"type": "object", "properties": {k: clean(vss, k) for k in ("mount", "path", "refreshAfter")}}
    return {
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["", "vso"]},
            "vso": {"type": "object", "properties": {
                "connection": {"type": "object", "properties": {
                    "address":         clean(vconn, "address"),
                    "vaultNamespace":  {"type": "string"},
                    "skipTLSVerify":   clean(vconn, "skipTLSVerify"),
                    "caCertSecretRef": clean(vconn, "caCertSecretRef"),
                }},
                "auth": {"type": "object", "properties": {
                    "appRole": {"type": "object", "required": ["roleId", "secretRef", "mount"], "properties": {
                        "roleId":    clean(ap, "roleId"),
                        "secretRef": clean(ap, "secretRef"),
                        "mount":     clean(vauth, "mount"),
                    }},
                }},
                "kvVersion":    {"type": "string", "enum": ["v1", "v2"], "default": "v2"},
                "refreshAfter": clean(vss, "refreshAfter"),
                "secrets": {"type": "object", "properties": {
                    key: secret_entry for key in values_sp["vso"]["secrets"]
                }},
            }},
        },
    }


# ── Load sources ───────────────────────────────────────────────────────────────

values = yaml.safe_load((REPO_ROOT / "values.yaml").read_text())

aap = load_crd_props("ansibleautomationplatforms.yaml")
hub = load_crd_props("automationhubs.yaml")

vso_conn  = load_crd_props("secrets.hashicorp.com_vaultconnections.yaml", VSO_CRD_DIR)
vso_auth  = load_crd_props("secrets.hashicorp.com_vaultauths.yaml",       VSO_CRD_DIR)
vso_ss    = load_crd_props("secrets.hashicorp.com_vaultstaticsecrets.yaml", VSO_CRD_DIR)

if not aap:
    print("WARNING: crds/ansibleautomationplatforms.yaml not found — top-level fields will be inferred from values.yaml defaults (normal for AAP 2.4)", file=sys.stderr)

# ── Build schema properties ────────────────────────────────────────────────────

properties = {}

# Top-level scalar fields — walk values.yaml, look up each in the AAP CRD
for key, value in values.items():
    if key in SECTIONS:
        continue
    properties[key] = field_schema(key, value, aap)

# Structured sections — each walked against its CRD source
properties["api"]        = build_section(values["api"],        aap.get("api",      {}).get("properties", {}))
properties["database"]   = build_section(values["database"],   aap.get("database", {}).get("properties", {}))
properties["redis"]      = build_section(values["redis"],      aap.get("redis",    {}).get("properties", {}))

# Controller — top-level fields from AutomationController CRD
controller_crd = load_crd_props("automationcontrollers.yaml") if (CRD_DIR / "automationcontrollers.yaml").exists() else {}
properties["controller"] = build_section(values["controller"], controller_crd)

# EDA — top-level fields from EDA CRD; database sub-section from the same CRD
eda_crd = load_crd_props("edas.yaml") if (CRD_DIR / "edas.yaml").exists() else {}
eda_values = {k: v for k, v in values["eda"].items() if k != "database"}
eda_properties = build_section(eda_values, eda_crd)["properties"]
eda_db_props = eda_crd.get("database", {}).get("properties", {})
eda_properties["database"] = build_section(values["eda"]["database"], eda_db_props)
properties["eda"] = {"type": "object", "properties": eda_properties}

properties["secretProvider"] = build_secret_provider_schema(values["secretProvider"], vso_conn, vso_auth, vso_ss)

# Hub — top-level fields from automationhubs CRD; content/worker as sub-sections
hub_values     = {k: v for k, v in values["hub"].items() if k not in ("content", "worker")}
hub_properties = build_section(hub_values, hub)["properties"]
hub_properties["content"] = build_section(values["hub"].get("content", {}), hub.get("content", {}).get("properties", {}))
hub_properties["worker"]  = build_section(values["hub"].get("worker",  {}), hub.get("worker",  {}).get("properties", {}))
properties["hub"] = {"type": "object", "properties": hub_properties}

# ── Assemble final schema ──────────────────────────────────────────────────────

schema = {
    "$schema": "https://json-schema.org/draft-07/schema#",
    "type": "object",
    "required": ["namespace"],
    "properties": properties,
    "definitions": {
        "resourceRequirements": {
            "type": "object",
            "properties": {
                "requests": {"type": "object", "properties": {"cpu": {"type": "string"}, "memory": {"type": "string"}}},
                "limits":   {"type": "object", "properties": {"cpu": {"type": "string"}, "memory": {"type": "string"}}},
            },
        },
        "storageRequirements": {
            "type": "object",
            "properties": {
                "requests": {"type": "object", "properties": {"storage": {"type": "string"}}},
                "limits":   {"type": "object", "properties": {"storage": {"type": "string"}}},
            },
        },
    },
}

OUTPUT.write_text(json.dumps(schema, indent=2) + "\n")
print(f"Generated {OUTPUT}")
