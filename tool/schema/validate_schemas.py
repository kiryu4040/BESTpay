#!/usr/bin/env python3

"""Validate BESTpay v2 JSON Schema contracts."""

from __future__ import annotations

import copy
import hashlib
import json
import re
import sys
import tempfile
from datetime import date
from importlib.metadata import version
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.exceptions import SchemaError
from referencing import Registry, Resource


DRAFT = "https://json-schema.org/draft/2020-12/schema"

CATALOG_ROOT_ID = "urn:bestpay:schema:catalog-root:1.0.0"
CATALOG_MANIFEST_ID = "urn:bestpay:schema:catalog-manifest:1.0.0"

CATALOG_SCHEMA_IDS = {
    "payment_instruments.json":
        "urn:bestpay:schema:payment-instrument:1.0.0",
    "payment_routes.json":
        "urn:bestpay:schema:payment-route:1.0.0",
    "payment_modes.json":
        "urn:bestpay:schema:payment-mode:1.0.0",
    "funding_relations.json":
        "urn:bestpay:schema:funding-relation:1.0.0",
    "merchant_groups.json":
        "urn:bestpay:schema:merchant-group:1.0.0",
    "merchants.json":
        "urn:bestpay:schema:merchant:1.0.0",
    "merchant_categories.json":
        "urn:bestpay:schema:merchant-category:1.0.0",
    "point_programs.json":
        "urn:bestpay:schema:point-program:1.0.0",
    "condition_definitions.json":
        "urn:bestpay:schema:condition-definition:1.0.0",
    "reward_rules.json":
        "urn:bestpay:schema:reward-rule:1.0.0",
    "sources.json":
        "urn:bestpay:schema:source:1.0.0",
    "id_migrations.json":
        "urn:bestpay:schema:id-migration:1.0.0",
}

COMMON_SCHEMA_IDS = {
    "stable_id": "urn:bestpay:schema:stable-id:1.0.0",
    "catalog_version": "urn:bestpay:schema:catalog-version:1.0.0",
    "date": "urn:bestpay:schema:date:1.0.0",
    "timestamp": "urn:bestpay:schema:timestamp:1.0.0",
    "validity_period": "urn:bestpay:schema:validity-period:1.0.0",
    "rational": "urn:bestpay:schema:rational:1.0.0",
    "selector_set": "urn:bestpay:schema:selector-set:1.0.0",
    "source_reference": "urn:bestpay:schema:source-reference:1.0.0",
    "condition_expression":
        "urn:bestpay:schema:condition-expression:1.0.0",
}

USER_SCHEMA_IDS = {
    "owned_instrument":
        "urn:bestpay:schema:owned-instrument:1.0.0",
    "condition_state":
        "urn:bestpay:schema:condition-state:1.0.0",
    "point_value":
        "urn:bestpay:schema:point-value:1.0.0",
    "usage_period_state":
        "urn:bestpay:schema:usage-period-state:1.0.0",
    "favorite":
        "urn:bestpay:schema:favorite:1.0.0",
    "transaction_record":
        "urn:bestpay:schema:transaction-record:1.0.0",
    "backup":
        "urn:bestpay:schema:backup:1.0.0",
}

CATALOG_VERSION_PATTERN = re.compile(
    r"^([0-9]{4})\.(0[1-9]|1[0-2])\."
    r"(0[1-9]|[12][0-9]|3[01])\.([1-9][0-9]*)$"
)


class TestFailure(RuntimeError):
    """Raised when a schema conformance test fails."""


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def collect_refs(value: Any):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "$ref" and isinstance(child, str):
                yield child
            yield from collect_refs(child)
    elif isinstance(value, list):
        for child in value:
            yield from collect_refs(child)


def load_schemas(repo: Path):
    schema_paths = sorted((repo / "schemas").rglob("*.schema.json"))

    if len(schema_paths) != 30:
        raise TestFailure(
            f"Expected 30 schema files, found {len(schema_paths)}"
        )

    schemas: dict[str, dict[str, Any]] = {}
    paths_by_id: dict[str, Path] = {}

    for path in schema_paths:
        try:
            schema = load_json(path)
        except Exception as error:
            raise TestFailure(
                f"Invalid JSON: {path.relative_to(repo)}: {error}"
            ) from error

        if schema.get("$schema") != DRAFT:
            raise TestFailure(
                f"Invalid $schema: {path.relative_to(repo)}"
            )

        schema_id = schema.get("$id")

        if not isinstance(schema_id, str) or not schema_id:
            raise TestFailure(
                f"Missing $id: {path.relative_to(repo)}"
            )

        if schema_id in schemas:
            raise TestFailure(
                f"Duplicate $id {schema_id}: "
                f"{paths_by_id[schema_id].relative_to(repo)} and "
                f"{path.relative_to(repo)}"
            )

        try:
            Draft202012Validator.check_schema(schema)
        except SchemaError as error:
            raise TestFailure(
                f"Meta-schema failure: {path.relative_to(repo)}: "
                f"{error.message}"
            ) from error

        schemas[schema_id] = schema
        paths_by_id[schema_id] = path

    resources = [
        (schema_id, Resource.from_contents(schema))
        for schema_id, schema in schemas.items()
    ]
    registry = Registry().with_resources(resources)

    unresolved = []

    for schema_id, schema in schemas.items():
        resolver = registry.resolver(base_uri=schema_id)

        for reference in collect_refs(schema):
            try:
                resolver.lookup(reference)
            except Exception as error:
                unresolved.append(
                    f"{schema_id} -> {reference}: {error}"
                )

    if unresolved:
        raise TestFailure(
            "Unresolved references:\n" + "\n".join(unresolved)
        )

    return schema_paths, schemas, registry


def make_validator(schema_id, schemas, registry):
    return Draft202012Validator(
        schemas[schema_id],
        registry=registry,
        format_checker=FormatChecker(),
    )


def assert_valid(
    name,
    schema_id,
    instance,
    schemas,
    registry,
):
    validator = make_validator(schema_id, schemas, registry)
    errors = sorted(
        validator.iter_errors(instance),
        key=lambda error: list(error.absolute_path),
    )

    if errors:
        details = "; ".join(
            f"{list(error.absolute_path)}: {error.message}"
            for error in errors
        )
        raise TestFailure(f"{name} should be valid: {details}")


def assert_invalid(
    name,
    schema_id,
    instance,
    schemas,
    registry,
):
    validator = make_validator(schema_id, schemas, registry)

    if validator.is_valid(instance):
        raise TestFailure(f"{name} should be invalid")


def empty_selector():
    return {
        "instrumentIds": [],
        "modeIds": [],
        "routeIds": [],
        "fundingRelationIds": [],
        "merchantIds": [],
        "merchantGroupIds": [],
        "categoryIds": [],
        "brandIds": [],
        "locationIds": [],
        "transactionTags": [],
    }


def empty_catalog():
    return {
        "schemaVersion": "1.0.0",
        "catalogVersion": "2026.09.18.1",
        "generatedAt": "2026-09-18T00:00:00+09:00",
        "items": [],
    }


def common_positive_instances():
    return {
        COMMON_SCHEMA_IDS["stable_id"]: "abc",
        COMMON_SCHEMA_IDS["catalog_version"]: "2026.09.18.1",
        COMMON_SCHEMA_IDS["date"]: "2026-09-18",
        COMMON_SCHEMA_IDS["timestamp"]:
            "2026-09-18T00:00:00+09:00",
        COMMON_SCHEMA_IDS["validity_period"]: {
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
        },
        COMMON_SCHEMA_IDS["rational"]: {
            "numerator": 1,
            "denominator": 100,
        },
        COMMON_SCHEMA_IDS["selector_set"]: empty_selector(),
        COMMON_SCHEMA_IDS["source_reference"]: "official_source_001",
        COMMON_SCHEMA_IDS["condition_expression"]: {
            "nodeType": "condition",
            "conditionId": "condition_001",
        },
    }


def user_positive_instances():
    owned = {
        "instrumentId": "instrument_001",
        "enabled": True,
        "selectedModeIds": [],
        "selectedRouteIds": [],
        "acquiredOn": None,
        "nickname": None,
        "createdAt": "2026-09-18T00:00:00+09:00",
        "updatedAt": "2026-09-18T00:00:00+09:00",
        "notes": [],
    }

    condition_state = {
        "conditionId": "condition_001",
        "state": "unknown",
        "updatedAt": "2026-09-18T00:00:00+09:00",
    }

    point_value = {
        "pointProgramId": "point_program_001",
        "yenPerPoint": None,
        "updatedAt": None,
    }

    usage_period = {
        "id": "usage_period_001",
        "instrumentId": "instrument_001",
        "aggregationKey": "monthly_spend_001",
        "periodType": "calendarMonth",
        "periodStart": "2026-09-01",
        "periodEndExclusive": "2026-10-01",
        "eligibleSpendYen": 0,
        "ineligibleSpendYen": 0,
        "awardedPointsByProgram": {},
        "consumedCaps": {},
        "bonusStates": {},
        "dataConfidence": "unknown",
        "updatedAt": "2026-09-18T00:00:00+09:00",
        "updateMethod": "systemCalculated",
    }

    favorite = {
        "entityType": "merchant",
        "entityId": "merchant_001",
        "paymentPlan": None,
        "createdAt": "2026-09-18T00:00:00+09:00",
        "sortOrder": 0,
        "needsReview": False,
    }

    transaction = {
        "id": "transaction_001",
        "merchantId": None,
        "manualMerchantName": None,
        "categoryId": None,
        "amountYen": 1000,
        "transactionAt": "2026-09-18T12:00:00+09:00",
        "postingAt": None,
        "settlementDataReceivedAt": None,
        "billingAt": None,
        "instrumentId": "instrument_001",
        "modeId": "mode_001",
        "routeId": "route_001",
        "fundingRelationIds": [],
        "appliedRuleIds": [],
        "earnedPoints": {},
        "eligibility": "unknown",
        "createdAt": "2026-09-18T12:00:00+09:00",
        "notes": [],
    }

    backup = {
        "formatId": "bestpay-v2-backup",
        "schemaVersion": "1.0.0",
        "appVersion": "1.1.0+2",
        "catalogVersion": "2026.09.18.1",
        "exportedAt": "2026-09-18T00:00:00+09:00",
        "ownedInstruments": [],
        "conditionStates": [],
        "pointValues": [],
        "usagePeriodStates": [],
        "favorites": [],
        "transactionRecords": [],
    }

    return {
        USER_SCHEMA_IDS["owned_instrument"]: owned,
        USER_SCHEMA_IDS["condition_state"]: condition_state,
        USER_SCHEMA_IDS["point_value"]: point_value,
        USER_SCHEMA_IDS["usage_period_state"]: usage_period,
        USER_SCHEMA_IDS["favorite"]: favorite,
        USER_SCHEMA_IDS["transaction_record"]: transaction,
        USER_SCHEMA_IDS["backup"]: backup,
    }


def is_real_catalog_version(value):
    if not isinstance(value, str):
        return False

    match = CATALOG_VERSION_PATTERN.fullmatch(value)

    if match is None:
        return False

    year, month, day, revision = map(int, match.groups())

    if revision < 1:
        return False

    try:
        date(year, month, day)
    except ValueError:
        return False

    return True


def condition_expression_stats(node):
    if not isinstance(node, dict):
        raise ValueError("ConditionExpression node must be an object")

    node_type = node.get("nodeType")

    if node_type in {"condition", "comparison"}:
        return 1, 1

    if node_type == "not":
        child_depth, child_count = condition_expression_stats(
            node["child"]
        )
        return child_depth + 1, child_count + 1

    if node_type in {"all", "any"}:
        child_stats = [
            condition_expression_stats(child)
            for child in node["children"]
        ]
        depth = 1 + max(item[0] for item in child_stats)
        count = 1 + sum(item[1] for item in child_stats)
        return depth, count

    raise ValueError(f"Unsupported nodeType: {node_type!r}")


def validate_condition_limits(node):
    depth, count = condition_expression_stats(node)
    errors = []

    if depth > 10:
        errors.append(f"depth {depth} exceeds 10")

    if count > 100:
        errors.append(f"node count {count} exceeds 100")

    return errors


def validate_manifest_contract(manifest, directory=None):
    errors = []
    items = manifest.get("items")

    if not isinstance(items, list):
        return ["items must be an array"]

    names = [
        item.get("fileName")
        for item in items
        if isinstance(item, dict)
    ]

    if len(names) != len(set(names)):
        errors.append("duplicate fileName")

    actual_names = set(names)
    expected_names = set(CATALOG_SCHEMA_IDS)

    missing = sorted(expected_names - actual_names)
    unexpected = sorted(actual_names - expected_names)

    if missing:
        errors.append("missing files: " + ", ".join(missing))

    if unexpected:
        errors.append(
            "unexpected files: " + ", ".join(unexpected)
        )

    for item in items:
        if not isinstance(item, dict):
            errors.append("manifest item must be an object")
            continue

        file_name = item.get("fileName")
        expected_schema_id = CATALOG_SCHEMA_IDS.get(file_name)

        if (
            expected_schema_id is not None
            and item.get("schemaId") != expected_schema_id
        ):
            errors.append(
                f"schemaId mismatch for {file_name}"
            )

        if item.get("required") is not True:
            errors.append(f"required must be true for {file_name}")

        if directory is not None and file_name in CATALOG_SCHEMA_IDS:
            path = directory / file_name

            if not path.is_file():
                errors.append(f"missing physical file: {file_name}")
                continue

            actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()

            if item.get("contentHash") != actual_hash:
                errors.append(f"contentHash mismatch for {file_name}")

    return errors


def build_manifest(directory):
    items = []

    for index, (file_name, schema_id) in enumerate(
        CATALOG_SCHEMA_IDS.items()
    ):
        path = directory / file_name
        payload = (
            f'{{"fixture":{index},"file":"{file_name}"}}\n'
        ).encode("utf-8")
        path.write_bytes(payload)

        items.append({
            "fileName": file_name,
            "schemaId": schema_id,
            "contentHash": hashlib.sha256(payload).hexdigest(),
            "required": True,
        })

    return {
        "schemaVersion": "1.0.0",
        "catalogVersion": "2026.09.18.1",
        "generatedAt": "2026-09-18T00:00:00+09:00",
        "items": items,
    }


def test_schema_roots(schemas, registry):
    positive_count = 0
    negative_count = 0

    for schema_id, instance in common_positive_instances().items():
        assert_valid(
            f"positive {schema_id}",
            schema_id,
            instance,
            schemas,
            registry,
        )
        positive_count += 1

    assert_invalid(
        "short StableId",
        COMMON_SCHEMA_IDS["stable_id"],
        "ab",
        schemas,
        registry,
    )
    negative_count += 1

    assert_invalid(
        "uppercase StableId",
        COMMON_SCHEMA_IDS["stable_id"],
        "Abc",
        schemas,
        registry,
    )
    negative_count += 1

    assert_invalid(
        "zero CatalogVersion revision",
        COMMON_SCHEMA_IDS["catalog_version"],
        "2026.09.18.0",
        schemas,
        registry,
    )
    negative_count += 1

    assert_invalid(
        "invalid date format",
        COMMON_SCHEMA_IDS["date"],
        "2026-9-18",
        schemas,
        registry,
    )
    negative_count += 1

    assert_invalid(
        "invalid timestamp",
        COMMON_SCHEMA_IDS["timestamp"],
        "not-a-timestamp",
        schemas,
        registry,
    )
    negative_count += 1

    assert_invalid(
        "zero rational denominator",
        COMMON_SCHEMA_IDS["rational"],
        {"numerator": 1, "denominator": 0},
        schemas,
        registry,
    )
    negative_count += 1

    invalid_selector = empty_selector()
    del invalid_selector["transactionTags"]

    assert_invalid(
        "selector missing transactionTags",
        COMMON_SCHEMA_IDS["selector_set"],
        invalid_selector,
        schemas,
        registry,
    )
    negative_count += 1

    invalid_condition = {
        "nodeType": "condition",
        "conditionId": "condition_001",
        "unexpected": True,
    }

    assert_invalid(
        "condition expression unknown property",
        COMMON_SCHEMA_IDS["condition_expression"],
        invalid_condition,
        schemas,
        registry,
    )
    negative_count += 1

    assert_valid(
        "catalog root",
        CATALOG_ROOT_ID,
        empty_catalog(),
        schemas,
        registry,
    )
    positive_count += 1

    for file_name, schema_id in CATALOG_SCHEMA_IDS.items():
        assert_valid(
            f"empty catalog {file_name}",
            schema_id,
            empty_catalog(),
            schemas,
            registry,
        )
        positive_count += 1

        invalid_catalog = empty_catalog()
        invalid_catalog["unexpected"] = True

        assert_invalid(
            f"catalog unknown property {file_name}",
            schema_id,
            invalid_catalog,
            schemas,
            registry,
        )
        negative_count += 1

    for schema_id, instance in user_positive_instances().items():
        assert_valid(
            f"positive {schema_id}",
            schema_id,
            instance,
            schemas,
            registry,
        )
        positive_count += 1

        if isinstance(instance, dict):
            invalid_instance = copy.deepcopy(instance)
            invalid_instance["unexpected"] = True

            assert_invalid(
                f"unknown property {schema_id}",
                schema_id,
                invalid_instance,
                schemas,
                registry,
            )
            negative_count += 1

    return positive_count, negative_count


def test_custom_contracts(schemas, registry):
    custom_positive_count = 0
    custom_negative_count = 0

    valid_versions = [
        "2026.09.17.1",
        "2026.12.31.9",
        "2028.02.29.1",
    ]

    invalid_versions = [
        "2026.02.30.1",
        "2026.13.01.1",
        "2026.01.01.0",
        "v2",
    ]

    for value in valid_versions:
        if not is_real_catalog_version(value):
            raise TestFailure(
                f"Valid CatalogVersion rejected: {value}"
            )
        custom_positive_count += 1

    for value in invalid_versions:
        if is_real_catalog_version(value):
            raise TestFailure(
                f"Invalid CatalogVersion accepted: {value}"
            )
        custom_negative_count += 1

    condition_leaf = {
        "nodeType": "condition",
        "conditionId": "condition_001",
    }

    depth_ten = copy.deepcopy(condition_leaf)

    for _ in range(9):
        depth_ten = {
            "nodeType": "not",
            "child": depth_ten,
        }

    if validate_condition_limits(depth_ten):
        raise TestFailure("Depth 10 expression was rejected")

    assert_valid(
        "ConditionExpression depth 10 schema validation",
        COMMON_SCHEMA_IDS["condition_expression"],
        depth_ten,
        schemas,
        registry,
    )
    custom_positive_count += 1

    depth_eleven = {
        "nodeType": "not",
        "child": depth_ten,
    }

    if not validate_condition_limits(depth_eleven):
        raise TestFailure("Depth 11 expression was accepted")

    custom_negative_count += 1

    node_count_100 = {
        "nodeType": "all",
        "children": [
            {
                "nodeType": "condition",
                "conditionId": f"condition_{index:03d}",
            }
            for index in range(99)
        ],
    }

    if validate_condition_limits(node_count_100):
        raise TestFailure("100-node expression was rejected")

    assert_valid(
        "ConditionExpression 100 nodes schema validation",
        COMMON_SCHEMA_IDS["condition_expression"],
        node_count_100,
        schemas,
        registry,
    )
    custom_positive_count += 1

    node_count_101 = copy.deepcopy(node_count_100)
    node_count_101["children"].append({
        "nodeType": "condition",
        "conditionId": "condition_100",
    })

    if not validate_condition_limits(node_count_101):
        raise TestFailure("101-node expression was accepted")

    custom_negative_count += 1

    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        manifest = build_manifest(directory)

        assert_valid(
            "valid Catalog Manifest",
            CATALOG_MANIFEST_ID,
            manifest,
            schemas,
            registry,
        )

        manifest_errors = validate_manifest_contract(
            manifest,
            directory,
        )

        if manifest_errors:
            raise TestFailure(
                "Valid manifest rejected: "
                + "; ".join(manifest_errors)
            )

        custom_positive_count += 1

        duplicate_manifest = copy.deepcopy(manifest)
        duplicate_manifest["items"][1]["fileName"] = (
            duplicate_manifest["items"][0]["fileName"]
        )

        if not validate_manifest_contract(
            duplicate_manifest,
            directory,
        ):
            raise TestFailure(
                "Duplicate manifest fileName was accepted"
            )

        custom_negative_count += 1

        wrong_schema_manifest = copy.deepcopy(manifest)
        wrong_schema_manifest["items"][0]["schemaId"] = (
            "urn:bestpay:schema:source:1.0.0"
        )

        if not validate_manifest_contract(
            wrong_schema_manifest,
            directory,
        ):
            raise TestFailure(
                "Manifest schemaId mismatch was accepted"
            )

        custom_negative_count += 1

        wrong_hash_manifest = copy.deepcopy(manifest)
        wrong_hash_manifest["items"][0]["contentHash"] = "0" * 64

        if not validate_manifest_contract(
            wrong_hash_manifest,
            directory,
        ):
            raise TestFailure(
                "Manifest hash mismatch was accepted"
            )

        custom_negative_count += 1

    reward_schema = schemas[
        CATALOG_SCHEMA_IDS["reward_rules.json"]
    ]
    reward_timezone = (
        reward_schema["$defs"]["catalogItem"]
        ["properties"]["timezone"]
    )

    if reward_timezone != {"const": "Asia/Tokyo"}:
        raise TestFailure(
            "RewardRule timezone is not fixed to Asia/Tokyo"
        )

    custom_positive_count += 1

    migration_schema = schemas[
        CATALOG_SCHEMA_IDS["id_migrations.json"]
    ]
    migration_item = migration_schema["$defs"]["catalogItem"]
    merge_minimum = None

    for rule in migration_item["allOf"]:
        migration_type = (
            rule.get("if", {})
                .get("properties", {})
                .get("migrationType", {})
                .get("const")
        )

        if migration_type == "merge":
            merge_minimum = (
                rule["then"]["properties"]["fromIds"]["minItems"]
            )

    if merge_minimum != 2:
        raise TestFailure(
            f"Expected merge fromIds minimum 2, got {merge_minimum}"
        )

    custom_positive_count += 1

    return custom_positive_count, custom_negative_count


def main(repo_text):
    repo = Path(repo_text).resolve()

    schema_paths, schemas, registry = load_schemas(repo)

    expected_ids = (
        set(COMMON_SCHEMA_IDS.values())
        | set(USER_SCHEMA_IDS.values())
        | set(CATALOG_SCHEMA_IDS.values())
        | {CATALOG_ROOT_ID, CATALOG_MANIFEST_ID}
    )

    actual_ids = set(schemas)

    if actual_ids != expected_ids:
        missing = sorted(expected_ids - actual_ids)
        unexpected = sorted(actual_ids - expected_ids)
        raise TestFailure(
            f"Schema ID set mismatch. "
            f"Missing={missing}, Unexpected={unexpected}"
        )

    positive_count, negative_count = test_schema_roots(
        schemas,
        registry,
    )

    custom_positive_count, custom_negative_count = (
        test_custom_contracts(schemas, registry)
    )

    reference_count = sum(
        1
        for schema in schemas.values()
        for _ in collect_refs(schema)
    )

    print("===== BESTpay Schema Validation Summary =====")
    print(f"PythonVersion: {sys.version.split()[0]}")
    print(f"JsonSchemaVersion: {version('jsonschema')}")
    print(f"SchemaFileCount: {len(schema_paths)}")
    print(f"UniqueSchemaIdCount: {len(schemas)}")
    print(f"ReferenceCount: {reference_count}")
    print("UnresolvedReferenceCount: 0")
    print(f"RootPositiveTestCount: {positive_count}")
    print(f"RootNegativeTestCount: {negative_count}")
    print(f"CustomPositiveTestCount: {custom_positive_count}")
    print(f"CustomNegativeTestCount: {custom_negative_count}")
    print("ValidationPassed: True")

    return 0


if __name__ == "__main__":
    if len(sys.argv) > 2:
        print(
            "Usage: validate_schemas.py [REPOSITORY]",
            file=sys.stderr,
        )
        raise SystemExit(2)

    if len(sys.argv) == 2:
        repository = Path(sys.argv[1])
    else:
        repository = Path(__file__).resolve().parents[2]

    try:
        raise SystemExit(main(str(repository)))
    except TestFailure as error:
        print(f"VALIDATION FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
