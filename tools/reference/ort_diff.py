#!/usr/bin/env python3
"""Compare tracked fixture outputs with official ONNX Runtime.

This is a test aid. It is not imported by the MoonBit SDK and must not be
packaged as a runtime dependency. Positive cases must match the analytical
reference in testdata/cases/manifest.json. Negative cases must fail with the
recorded error class. Draft FFI failures in tests/failure_cases.json are
checked for completeness only; this script does not import an SDK.
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort


ROOT = Path(__file__).resolve().parents[2]
TESTDATA = ROOT / "testdata"
MANIFEST_PATH = TESTDATA / "cases" / "manifest.json"
TOLERANCE_PATH = Path(__file__).resolve().parent / "tolerances.json"
FAILURE_PATH = ROOT / "tests" / "failure_cases.json"
ORT_VERSION = "1.30.0"
HARD_RTOL = 1e-6
HARD_ATOL = 1e-6
NUMPY_DTYPES = {
    "float32": np.float32,
    "int64": np.int64,
    "bool": np.bool_,
}


class DiffError(Exception):
    pass


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def to_numpy(spec: dict) -> np.ndarray:
    dtype = NUMPY_DTYPES[spec["dtype"]]
    values = np.array(spec["data"], dtype=dtype)
    return values.reshape(tuple(spec["shape"]))


def make_session(model_path: Path) -> ort.InferenceSession:
    options = ort.SessionOptions()
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    options.log_severity_level = 3
    session = ort.InferenceSession(
        str(model_path),
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    if session.get_providers() != ["CPUExecutionProvider"]:
        raise DiffError(f"{model_path.name} did not stay on CPU: {session.get_providers()}")
    return session


def classify_error(exc: BaseException) -> str:
    message = str(exc)
    if "Protobuf parsing failed" in message or "INVALID_PROTOBUF" in message:
        return "invalid_model"
    if "Unexpected input data type" in message:
        return "wrong_type"
    if "invalid dimensions" in message or "Invalid rank" in message:
        return "wrong_shape"
    if "are missing from input feed" in message:
        return "missing_input"
    return "unclassified"


def check_tolerance_entry(case_id: str, name: str, spec: dict, ceiling: dict) -> None:
    dtype = spec.get("dtype")
    if dtype == "float32":
        if set(spec) != {"dtype", "rtol", "atol"}:
            raise DiffError(f"{case_id}.{name} float tolerance keys must be dtype/rtol/atol")
        if spec["rtol"] > ceiling["rtol"] or spec["atol"] > ceiling["atol"]:
            raise DiffError(f"{case_id}.{name} tolerance exceeds the recorded ceiling")
        return
    if dtype in ("int64", "bool"):
        if spec.get("exact") is not True or set(spec) != {"dtype", "exact"}:
            raise DiffError(f"{case_id}.{name} must be exact and must not carry a float tolerance")
        return
    raise DiffError(f"{case_id}.{name} has unsupported dtype {dtype}")


def check_tolerances(manifest: dict, tolerances: dict) -> None:
    if tolerances.get("ort_version") != ORT_VERSION:
        raise DiffError("tolerances ort_version is not 1.30.0")
    ceiling = tolerances["float32_ceiling"]
    if ceiling["rtol"] > HARD_RTOL or ceiling["atol"] > HARD_ATOL:
        raise DiffError(
            f"float32 ceiling rtol={ceiling['rtol']} atol={ceiling['atol']} "
            f"exceeds hard cap rtol={HARD_RTOL} atol={HARD_ATOL}"
        )
    expected_ids = [case["id"] for case in manifest["positive"]]
    recorded = tolerances["outputs"]
    if set(recorded) != set(expected_ids):
        raise DiffError("tolerance entries do not match positive case ids")
    for case in manifest["positive"]:
        outputs = case["expected"]
        entry = recorded[case["id"]]
        if set(entry) != set(outputs):
            raise DiffError(f"{case['id']} tolerance outputs do not match the manifest")
        for name, value in outputs.items():
            spec = entry[name]
            if spec["dtype"] != value["dtype"]:
                raise DiffError(f"{case['id']}.{name} tolerance dtype does not match the manifest")
            check_tolerance_entry(case["id"], name, spec, ceiling)


def compare_tensor(actual: np.ndarray, expected: dict, tolerance: dict) -> None:
    wanted = to_numpy(expected)
    if actual.shape != wanted.shape:
        raise DiffError(f"shape {tuple(actual.shape)} != {tuple(wanted.shape)}")
    if actual.dtype != wanted.dtype:
        raise DiffError(f"dtype {actual.dtype} != {wanted.dtype}")
    if expected["dtype"] == "float32":
        rtol = float(tolerance["rtol"])
        atol = float(tolerance["atol"])
        if not np.allclose(actual, wanted, rtol=rtol, atol=atol, equal_nan=False):
            delta = np.max(np.abs(actual.astype(np.float64) - wanted.astype(np.float64)))
            raise DiffError(f"float mismatch max_abs={delta} rtol={rtol} atol={atol}")
        return
    if not np.array_equal(actual, wanted):
        raise DiffError("exact integer or bool mismatch")


def prove_real_error_is_rejected(expected: dict, tolerance: dict) -> None:
    mutated = to_numpy(expected).copy()
    if mutated.size == 0:
        raise DiffError("cannot prove a tolerance against an empty tensor")
    flat = mutated.reshape(-1)
    if expected["dtype"] == "float32":
        flat[0] = np.float32(flat[0] + np.float32(1.0))
    elif expected["dtype"] == "int64":
        flat[0] = np.int64(flat[0] + np.int64(1))
    elif expected["dtype"] == "bool":
        flat[0] = np.bool_(not bool(flat[0]))
    else:
        raise DiffError(f"unsupported dtype {expected['dtype']}")
    try:
        compare_tensor(mutated, expected, tolerance)
    except DiffError:
        return
    raise DiffError("tolerance accepted a changed element")


def run_ort(case: dict):
    model_path = TESTDATA / case["model"]
    if not model_path.is_file():
        raise DiffError(f"missing model {model_path}")
    try:
        session = make_session(model_path)
        feeds = {name: to_numpy(spec) for name, spec in case.get("inputs", {}).items()}
        if "expected" in case:
            names = list(case["expected"])
            values = session.run(names, feeds)
            return dict(zip(names, values, strict=True))
        session.run(None, feeds)
        return {}
    except DiffError:
        raise
    except Exception as exc:
        return exc


def check_positive(case: dict, tolerances: dict) -> None:
    result = run_ort(case)
    if isinstance(result, Exception):
        raise DiffError(f"{case['id']} failed in ORT: {result}")
    entry = tolerances["outputs"][case["id"]]
    for name, expected in case["expected"].items():
        try:
            compare_tensor(result[name], expected, entry[name])
            prove_real_error_is_rejected(expected, entry[name])
        except DiffError as exc:
            raise DiffError(f"{case['id']}.{name}: {exc}") from exc


def check_negative(case: dict) -> None:
    result = run_ort(case)
    if not isinstance(result, Exception):
        raise DiffError(f"{case['id']} unexpectedly succeeded")
    kind = classify_error(result)
    if kind != case["expect_error"]:
        raise DiffError(f"{case['id']} classified as {kind}, want {case['expect_error']}: {result}")
    needle = case["message_contains"]
    if needle not in str(result):
        raise DiffError(f"{case['id']} message lacks {needle!r}: {result}")


def check_failure_contract(manifest: dict, contract: dict) -> None:
    if contract.get("schema_version") != 1:
        raise DiffError("failure contract schema_version must be 1")
    negatives = {case["id"]: case for case in manifest["negative"]}
    seen = set()
    executable = []
    for case in contract["cases"]:
        case_id = case["id"]
        if case_id in seen:
            raise DiffError(f"duplicate failure case {case_id}")
        seen.add(case_id)
        if not case.get("trigger") or not case.get("expected", {}).get("outcome"):
            raise DiffError(f"{case_id} is missing trigger or outcome")
        if case["executable_now"]:
            if case.get("runner") != "tools/reference/ort_diff.py":
                raise DiffError(f"{case_id} executable runner is not the reference tool")
            manifest_id = case.get("manifest_id")
            if manifest_id not in negatives:
                raise DiffError(f"{case_id} does not point at a negative manifest case")
            if case["expected"].get("class") != negatives[manifest_id]["expect_error"]:
                raise DiffError(f"{case_id} class does not match the manifest")
            if case.get("kind") != "failure" or case.get("layer") != "session":
                raise DiffError(f"{case_id} must be a session failure")
            executable.append(manifest_id)
            continue
        if not case.get("blocked_on"):
            raise DiffError(f"{case_id} draft is missing blocked_on")
        if "manifest_id" in case:
            raise DiffError(f"{case_id} draft must not point at an executable manifest case")
        if case.get("layer") != "ffi" or case.get("kind") not in ("failure", "lifecycle"):
            raise DiffError(f"{case_id} draft layer or kind is incomplete")
    if set(executable) != set(negatives):
        raise DiffError("executable failure contract does not cover every negative fixture")


def load_candidate(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    items = payload if isinstance(payload, list) else [payload]
    dumps = {}
    for item in items:
        if "id" not in item or "outputs" not in item:
            raise DiffError(f"{path} entry is missing id or outputs")
        dumps[item["id"]] = item["outputs"]
    return dumps


def compare_candidate(manifest: dict, tolerances: dict, dumps: dict) -> None:
    positive_ids = [case["id"] for case in manifest["positive"]]
    if set(dumps) != set(positive_ids):
        raise DiffError("candidate dump must cover every positive case and no others")
    for case in manifest["positive"]:
        result = run_ort(case)
        if isinstance(result, Exception):
            raise DiffError(f"{case['id']} failed in ORT: {result}")
        entry = tolerances["outputs"][case["id"]]
        candidate = dumps[case["id"]]
        if set(candidate) != set(case["expected"]):
            raise DiffError(f"{case['id']} candidate outputs do not match the manifest")
        for name, expected in case["expected"].items():
            try:
                compare_tensor(result[name], expected, entry[name])
                compare_tensor(to_numpy(candidate[name]), expected, entry[name])
                compare_tensor(to_numpy(candidate[name]), {
                    "dtype": expected["dtype"],
                    "shape": list(result[name].shape),
                    "data": result[name].reshape(-1).tolist(),
                }, entry[name])
            except DiffError as exc:
                raise DiffError(f"{case['id']}.{name}: {exc}") from exc


def prepare() -> tuple[dict, dict, dict]:
    if ort.__version__ != ORT_VERSION:
        raise DiffError(f"onnxruntime {ort.__version__} != required {ORT_VERSION}")
    manifest = load_json(MANIFEST_PATH)
    if manifest.get("generator", {}).get("ort_reference") != ORT_VERSION:
        raise DiffError("manifest ort_reference is not 1.30.0")
    tolerances = load_json(TOLERANCE_PATH)
    contract = load_json(FAILURE_PATH)
    check_tolerances(manifest, tolerances)
    check_failure_contract(manifest, contract)
    return manifest, tolerances, contract


def verify() -> None:
    manifest, tolerances, contract = prepare()
    for case in manifest["positive"]:
        check_positive(case, tolerances)
        print(f"pass {case['id']}")
    for case in manifest["negative"]:
        check_negative(case)
        print(f"pass {case['id']}")
    drafts = [case["id"] for case in contract["cases"] if not case["executable_now"]]
    print(
        f"verified official ORT {ORT_VERSION} CPU: "
        f"{len(manifest['positive'])} positive, {len(manifest['negative'])} negative, "
        f"{len(drafts)} FFI drafts checked as data only"
    )


def compare(path: Path) -> None:
    manifest, tolerances, _contract = prepare()
    compare_candidate(manifest, tolerances, load_candidate(path))
    print(f"candidate matches official ORT {ORT_VERSION}: {path}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Compare fixture outputs with official ONNX Runtime 1.30.0")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("verify", help="run positive, negative, and failure-contract checks")
    compare_parser = sub.add_parser("compare", help="compare a JSON dump with official ORT and the tracked reference")
    compare_parser.add_argument("dump", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "verify":
            verify()
        else:
            compare(args.dump)
    except (DiffError, OSError, json.JSONDecodeError) as exc:
        print(f"fail {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
