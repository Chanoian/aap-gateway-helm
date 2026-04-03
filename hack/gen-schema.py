#!/usr/bin/env python3
"""
Generate values.schema.json by walking values.yaml and looking up
each field's type/enum in the CRD OpenAPI schemas.

values.yaml  → which fields exist (the chart's surface area)
crds/        → types and enums for those fields

Usage: python3 hack/gen-schema.py
"""

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML not installed — pip3 install pyyaml")

REPO_ROOT = Path(__file__).parent.parent
OUTPUT    = REPO_ROOT / "values.schema.json"


def load_crd_props(filename):
    path = REPO_ROOT / "crds" / filename
    if not path.exists():
        print(f"WARNING: crds/{filename} not found", file=sys.stderr)
        return {}
    crd = yaml.safe_load(path.read_text())
    return (
        crd["spec"]["versions"][0]["schema"]
        ["openAPIV3Schema"]["properties"]["spec"]["properties"]
    )


def ref(name):
    return {"$ref": f"#/definitions/{name}"}


# ── Special-case rules (the only hardcoded knowledge in this script) ───────────

# Replaced with shared $ref definitions
RESOURCE_REFS = {
    "resource_requirements": "resourceRequirements",
    "storage_requirements":  "storageRequirements",
}

# CRD declares these as string but the chart uses them as objects
FORCE_OBJECT = {
    "route_annotations", "ingress_annotations",
    "service_annotations", "service_account_annotations",
    "feature_flags",
}

# Optional fields whose default is "" but CRD enum doesn't include ""
OPTIONAL_ENUM = {"ingress_type", "service_type", "file_storage_access_mode"}

# Chart-only fields not present in any CRD
CHART_ONLY = {
    "name":      {"type": "string"},
    "namespace": {"type": "string"},
    "extraSpec": {"type": "object"},
    "feature_flags": {"type": "object", "additionalProperties": {"type": "boolean"}},
}

# Sections that need recursive handling (not treated as scalar fields)
SECTIONS = {"api", "database", "redis", "controller", "eda", "hub"}


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
        return schema

    return infer_type(value)


def build_section(values_dict, crd_props):
    """Walk a values.yaml dict and build a JSON Schema properties map."""
    return {
        "type": "object",
        "properties": {
            key: field_schema(key, value, crd_props)
            for key, value in values_dict.items()
        },
    }


# ── Load sources ───────────────────────────────────────────────────────────────

values = yaml.safe_load((REPO_ROOT / "values.yaml").read_text())

aap = load_crd_props("ansibleautomationplatforms.yaml")
hub = load_crd_props("automationhubs.yaml")

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
properties["controller"] = build_section(values["controller"], {})
properties["eda"]        = build_section(values["eda"],        {})

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
