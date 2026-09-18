#!/usr/bin/env python3

"""Detailed positive and negative tests for BESTpay v2 schemas."""

from __future__ import annotations

import copy
import sys
from pathlib import Path

from validate_schemas import (
    CATALOG_SCHEMA_IDS,
    COMMON_SCHEMA_IDS,
    USER_SCHEMA_IDS,
    TestFailure,
    assert_invalid,
    assert_valid,
    empty_catalog,
    empty_selector,
    load_schemas,
)


def catalog_with(item):
    catalog = empty_catalog()
    catalog["items"] = [item]
    return catalog


def base_catalog_items():
    return {
        "payment_instruments.json": {
            "id": "instrument_001",
            "name": "Example Card",
            "shortName": "Example",
            "instrumentType": "creditCard",
            "issuerName": "Example Issuer",
            "partnerInstitutionName": None,
            "availableBrandIds": [],
            "annualFee": 0,
            "supportedModeIds": [],
            "supportedRouteIds": [],
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
            "status": "draft",
            "sourceIds": [],
            "lastVerifiedAt": "2026-09-18",
            "displayClaims": [],
            "tags": [],
            "notes": [],
        },
        "payment_routes.json": {
            "id": "route_001",
            "name": "Example Route",
            "routeType": "physicalCard",
            "brandIds": [],
            "deviceRequirement": None,
            "supportedInstrumentIds": [],
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "payment_modes.json": {
            "id": "mode_001",
            "instrumentId": "instrument_001",
            "name": "Credit",
            "modeType": "credit",
            "supportedRouteIds": [],
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "funding_relations.json": {
            "id": "funding_relation_001",
            "sourceInstrumentId": "instrument_001",
            "destinationInstrumentId": "instrument_002",
            "relationType": "charge",
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "merchant_groups.json": {
            "id": "merchant_group_001",
            "name": "Example Group",
            "description": "",
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "merchants.json": {
            "id": "merchant_001",
            "name": "Example Merchant",
            "merchantGroupIds": [],
            "categoryIds": [],
            "locationIds": [],
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "merchant_categories.json": {
            "id": "category_001",
            "name": "Example Category",
            "parentCategoryId": None,
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "point_programs.json": {
            "id": "point_program_001",
            "name": "Example Points",
            "issuerName": "Example Issuer",
            "unitName": "point",
            "valueDefinition": {
                "valueType": "unset",
            },
            "expiration": {
                "expirationType": "unknown",
            },
            "status": "draft",
            "sourceIds": [],
            "lastVerifiedAt": "2026-09-18",
            "notes": [],
        },
        "condition_definitions.json": {
            "id": "condition_001",
            "name": "Example Condition",
            "description": "",
            "valueType": "triState",
            "defaultState": "unknown",
            "verificationMethod": "userInput",
            "scope": "user",
            "sensitivity": "normal",
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
            "status": "draft",
            "sourceIds": [],
            "notes": [],
        },
        "reward_rules.json": {
            "id": "reward_rule_001",
            "name": "Example Rule",
            "description": "",
            "ruleKind": "baseReward",
            "selectors": empty_selector(),
            "exclusions": empty_selector(),
            "conditionExpression": None,
            "calculation": {
                "calculationType": "none",
            },
            "outputPointProgramId": None,
            "aggregation": {
                "scope": "transaction",
                "aggregationKey": None,
                "periodMinimumEligibleSpendYen": 0,
                "conditionEvaluationTiming": "transaction",
                "incrementalAward": False,
            },
            "stacking": {
                "policy": "stack",
                "exclusiveGroupId": None,
                "replacesRuleIds": [],
                "suppressesRuleIds": [],
                "suppressesTags": [],
                "dependsOnRuleIds": [],
                "applicationOrder": 0,
            },
            "cap": None,
            "validFrom": "2026-09-18",
            "validUntilExclusive": None,
            "dateBasis": "transactionDate",
            "timezone": "Asia/Tokyo",
            "displayClaim": None,
            "sourceIds": [],
            "lastVerifiedAt": "2026-09-18",
            "status": "draft",
            "priority": 0,
            "tags": [],
            "notes": [],
        },
        "sources.json": {
            "id": "source_001",
            "title": "Example Source",
            "url": "https://example.com/source",
            "publisher": "Example Publisher",
            "sourceType": "officialProductPage",
            "publishedAt": None,
            "lastVerifiedAt": "2026-09-18",
            "accessStatus": "accessible",
            "reliability": "primary",
            "relevantSections": [],
            "summary": "",
            "contentHash": None,
            "notes": [],
        },
        "id_migrations.json": {
            "id": "migration_001",
            "entityType": "merchant",
            "migrationType": "rename",
            "fromIds": ["merchant_old"],
            "toIds": ["merchant_new"],
            "evidenceSourceIds": [],
            "needsReview": False,
            "effectiveFrom": "2026-09-18",
            "notes": [],
        },
    }


def condition_cases():
    leaf = {
        "nodeType": "condition",
        "conditionId": "condition_001",
    }

    cases = [
        leaf,
        {
            "nodeType": "all",
            "children": [copy.deepcopy(leaf)],
        },
        {
            "nodeType": "any",
            "children": [copy.deepcopy(leaf)],
        },
        {
            "nodeType": "not",
            "child": copy.deepcopy(leaf),
        },
    ]

    operators = [
        "equals",
        "notEquals",
        "greaterThan",
        "greaterThanOrEqual",
        "lessThan",
        "lessThanOrEqual",
        "in",
        "notIn",
    ]

    for operator in operators:
        value = ["a", "b"] if operator in {"in", "notIn"} else 1
        cases.append({
            "nodeType": "comparison",
            "conditionId": "condition_001",
            "comparisonOperator": operator,
            "value": value,
        })

    return cases


def point_program_cases(base):
    cases = []

    value_definitions = [
        {
            "valueType": "fixed",
            "yenPerPoint": {
                "numerator": 1,
                "denominator": 1,
            },
        },
        {
            "valueType": "variable",
        },
        {
            "valueType": "unset",
        },
    ]

    for value_definition in value_definitions:
        item = copy.deepcopy(base)
        item["valueDefinition"] = value_definition
        cases.append(item)

    expirations = [
        {
            "expirationType": "none",
        },
        {
            "expirationType": "fixedDate",
            "expiresOn": "2027-09-18",
        },
        {
            "expirationType": "durationMonths",
            "months": 12,
        },
        {
            "expirationType": "unknown",
        },
    ]

    for expiration in expirations:
        item = copy.deepcopy(base)
        item["expiration"] = expiration
        cases.append(item)

    return cases


def migration_cases(base):
    cases = []

    rename = copy.deepcopy(base)
    cases.append(rename)

    merge = copy.deepcopy(base)
    merge.update({
        "migrationType": "merge",
        "fromIds": ["merchant_old_1", "merchant_old_2"],
        "toIds": ["merchant_new"],
        "needsReview": False,
    })
    cases.append(merge)

    split = copy.deepcopy(base)
    split.update({
        "migrationType": "split",
        "fromIds": ["merchant_old"],
        "toIds": ["merchant_new_1", "merchant_new_2"],
        "needsReview": True,
    })
    cases.append(split)

    remove = copy.deepcopy(base)
    remove.update({
        "migrationType": "remove",
        "fromIds": ["merchant_old"],
        "toIds": [],
        "needsReview": True,
    })
    cases.append(remove)

    return cases


def reward_calculations():
    return [
        {
            "calculationType": "unitPoints",
            "amountUnitYen": 100,
            "pointsPerUnit": 1,
            "rounding": "floor",
        },
        {
            "calculationType": "rateFraction",
            "numerator": 1,
            "denominator": 100,
            "rounding": "floor",
        },
        {
            "calculationType": "fixedPoints",
            "points": 10,
        },
        {
            "calculationType": "mirror",
            "sourceRuleId": "reward_rule_source",
            "multiplierNumerator": 1,
            "multiplierDenominator": 1,
            "inheritEligibility": True,
            "inheritExclusions": True,
            "useFinalSourceAmount": True,
        },
        {
            "calculationType": "thresholdBonus",
            "thresholdAmountYen": 10000,
            "bonusPoints": 100,
            "maxAwardsPerPeriod": 1,
        },
        {
            "calculationType": "tiered",
            "tiers": [
                {
                    "minimumAmountYen": 0,
                    "maximumAmountYenExclusive": None,
                    "calculation": {
                        "calculationType": "fixedPoints",
                        "points": 1,
                    },
                }
            ],
        },
        {
            "calculationType": "none",
        },
    ]


def favorite_cases():
    return [
        {
            "entityType": "merchant",
            "entityId": "merchant_001",
            "paymentPlan": None,
            "createdAt": "2026-09-18T00:00:00+09:00",
            "sortOrder": 0,
            "needsReview": False,
        },
        {
            "entityType": "instrument",
            "entityId": "instrument_001",
            "paymentPlan": None,
            "createdAt": "2026-09-18T00:00:00+09:00",
            "sortOrder": 1,
            "needsReview": False,
        },
        {
            "entityType": "searchPreset",
            "entityId": "search_preset_001",
            "paymentPlan": None,
            "createdAt": "2026-09-18T00:00:00+09:00",
            "sortOrder": 2,
            "needsReview": False,
        },
        {
            "entityType": "paymentPlan",
            "entityId": "payment_plan_001",
            "paymentPlan": {
                "instrumentId": "instrument_001",
                "routeId": "route_001",
                "fundingRelationIds": [],
                "loyaltyProgramIds": [],
                "fixedConditionStates": {
                    "condition_001": "unknown",
                },
            },
            "createdAt": "2026-09-18T00:00:00+09:00",
            "sortOrder": 3,
            "needsReview": False,
        },
    ]


def test_catalog_items(schemas, registry):
    positives = 0
    negatives = 0
    items = base_catalog_items()

    if set(items) != set(CATALOG_SCHEMA_IDS):
        raise TestFailure(
            "Catalog fixture file set does not match manifest file set"
        )

    for file_name, item in items.items():
        schema_id = CATALOG_SCHEMA_IDS[file_name]

        assert_valid(
            f"valid catalog item: {file_name}",
            schema_id,
            catalog_with(item),
            schemas,
            registry,
        )
        positives += 1

        unknown = copy.deepcopy(item)
        unknown["unexpectedProperty"] = True

        assert_invalid(
            f"unknown catalog item property: {file_name}",
            schema_id,
            catalog_with(unknown),
            schemas,
            registry,
        )
        negatives += 1

        required = schemas[schema_id]["$defs"]["catalogItem"].get(
            "required",
            [],
        )

        if not required:
            raise TestFailure(
                f"catalogItem.required is empty: {file_name}"
            )

        missing = copy.deepcopy(item)
        del missing[required[0]]

        assert_invalid(
            f"missing required catalog property: {file_name}",
            schema_id,
            catalog_with(missing),
            schemas,
            registry,
        )
        negatives += 1

    return positives, negatives


def test_condition_variants(schemas, registry):
    positives = 0
    negatives = 0
    schema_id = COMMON_SCHEMA_IDS["condition_expression"]

    for index, instance in enumerate(condition_cases()):
        assert_valid(
            f"valid ConditionExpression variant {index}",
            schema_id,
            instance,
            schemas,
            registry,
        )
        positives += 1

    assert_invalid(
        "empty all expression",
        schema_id,
        {
            "nodeType": "all",
            "children": [],
        },
        schemas,
        registry,
    )
    negatives += 1

    assert_invalid(
        "unknown comparison operator",
        schema_id,
        {
            "nodeType": "comparison",
            "conditionId": "condition_001",
            "comparisonOperator": "contains",
            "value": "x",
        },
        schemas,
        registry,
    )
    negatives += 1

    return positives, negatives


def test_point_program_variants(items, schemas, registry):
    positives = 0
    negatives = 0
    schema_id = CATALOG_SCHEMA_IDS["point_programs.json"]
    base = items["point_programs.json"]

    for index, item in enumerate(point_program_cases(base)):
        assert_valid(
            f"valid PointProgram variant {index}",
            schema_id,
            catalog_with(item),
            schemas,
            registry,
        )
        positives += 1

    invalid = copy.deepcopy(base)
    invalid["valueDefinition"] = {
        "valueType": "fixed",
    }

    assert_invalid(
        "fixed PointProgram missing yenPerPoint",
        schema_id,
        catalog_with(invalid),
        schemas,
        registry,
    )
    negatives += 1

    return positives, negatives


def test_migration_variants(items, schemas, registry):
    positives = 0
    negatives = 0
    schema_id = CATALOG_SCHEMA_IDS["id_migrations.json"]
    base = items["id_migrations.json"]

    for index, item in enumerate(migration_cases(base)):
        assert_valid(
            f"valid ID migration variant {index}",
            schema_id,
            catalog_with(item),
            schemas,
            registry,
        )
        positives += 1

    invalid_cases = []

    invalid_rename = copy.deepcopy(base)
    invalid_rename["toIds"] = []
    invalid_cases.append(invalid_rename)

    invalid_merge = copy.deepcopy(base)
    invalid_merge.update({
        "migrationType": "merge",
        "fromIds": ["merchant_old"],
        "toIds": ["merchant_new"],
    })
    invalid_cases.append(invalid_merge)

    invalid_split = copy.deepcopy(base)
    invalid_split.update({
        "migrationType": "split",
        "fromIds": ["merchant_old"],
        "toIds": ["merchant_new_1", "merchant_new_2"],
        "needsReview": False,
    })
    invalid_cases.append(invalid_split)

    invalid_remove = copy.deepcopy(base)
    invalid_remove.update({
        "migrationType": "remove",
        "fromIds": ["merchant_old"],
        "toIds": ["merchant_new"],
        "needsReview": True,
    })
    invalid_cases.append(invalid_remove)

    for index, item in enumerate(invalid_cases):
        assert_invalid(
            f"invalid ID migration variant {index}",
            schema_id,
            catalog_with(item),
            schemas,
            registry,
        )
        negatives += 1

    return positives, negatives


def test_reward_variants(items, schemas, registry):
    positives = 0
    negatives = 0
    schema_id = CATALOG_SCHEMA_IDS["reward_rules.json"]
    base = items["reward_rules.json"]

    for index, calculation in enumerate(reward_calculations()):
        item = copy.deepcopy(base)
        item["calculation"] = calculation

        assert_valid(
            f"valid RewardRule calculation {index}",
            schema_id,
            catalog_with(item),
            schemas,
            registry,
        )
        positives += 1

    invalid_timezone = copy.deepcopy(base)
    invalid_timezone["timezone"] = "UTC"

    assert_invalid(
        "RewardRule UTC timezone",
        schema_id,
        catalog_with(invalid_timezone),
        schemas,
        registry,
    )
    negatives += 1

    return positives, negatives


def test_favorite_variants(schemas, registry):
    positives = 0
    negatives = 0
    schema_id = USER_SCHEMA_IDS["favorite"]

    cases = favorite_cases()

    for index, instance in enumerate(cases):
        assert_valid(
            f"valid Favorite variant {index}",
            schema_id,
            instance,
            schemas,
            registry,
        )
        positives += 1

    merchant_with_plan = copy.deepcopy(cases[0])
    merchant_with_plan["paymentPlan"] = copy.deepcopy(
        cases[3]["paymentPlan"]
    )

    assert_invalid(
        "non-paymentPlan favorite with paymentPlan",
        schema_id,
        merchant_with_plan,
        schemas,
        registry,
    )
    negatives += 1

    payment_plan_without_components = copy.deepcopy(cases[3])
    payment_plan_without_components["paymentPlan"] = None

    assert_invalid(
        "paymentPlan favorite without components",
        schema_id,
        payment_plan_without_components,
        schemas,
        registry,
    )
    negatives += 1

    return positives, negatives


def main(repo_text):
    repo = Path(repo_text).resolve()
    schema_paths, schemas, registry = load_schemas(repo)
    items = base_catalog_items()

    positive_count = 0
    negative_count = 0

    for test_function, arguments in [
        (test_catalog_items, (schemas, registry)),
        (test_condition_variants, (schemas, registry)),
        (
            test_point_program_variants,
            (items, schemas, registry),
        ),
        (
            test_migration_variants,
            (items, schemas, registry),
        ),
        (
            test_reward_variants,
            (items, schemas, registry),
        ),
        (test_favorite_variants, (schemas, registry)),
    ]:
        positives, negatives = test_function(*arguments)
        positive_count += positives
        negative_count += negatives

    print("===== Detailed Schema Contract Test Summary =====")
    print(f"SchemaFileCount: {len(schema_paths)}")
    print(f"CatalogItemFixtureCount: {len(items)}")
    print(f"DetailedPositiveTestCount: {positive_count}")
    print(f"DetailedNegativeTestCount: {negative_count}")
    print("DetailedValidationPassed: True")

    return 0


if __name__ == "__main__":
    if len(sys.argv) > 2:
        print(
            "Usage: test_schema_contracts.py [REPOSITORY]",
            file=sys.stderr,
        )
        raise SystemExit(2)

    repository = (
        Path(sys.argv[1])
        if len(sys.argv) == 2
        else Path(__file__).resolve().parents[2]
    )

    try:
        raise SystemExit(main(str(repository)))
    except TestFailure as error:
        print(f"TEST FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
