#!/usr/bin/env python3
"""Generate the self-authored, minimal ONNX fixtures used by moon-ort tests.

The four graphs are fixed literals. SEED only draws test inputs from the
exact-value pools below, so float32 reference results stay bit-exact.
Requires onnx==1.17.0. Opset is 13 and IR version is 9. The official
reference runtime for those inputs is ONNX Runtime 1.30.0, invoked only by
tools/reference/ort_diff.py. These models contain no third-party weights and
are distributed under the repository MIT license.
"""

import array
import json
import random
from pathlib import Path

import onnx
from onnx import TensorProto, checker, helper


ROOT = Path(__file__).resolve().parent
OPSET = 13
IR_VERSION = 9
SEED = 20260922
ONNX_VERSION = "1.17.0"
ORT_REFERENCE = "1.30.0"
EXACT_F32 = (-2.0, -1.5, -0.5, 0.0, 0.25, 0.5, 1.0, 1.5, 2.0)
EXACT_I64 = (-5, -3, -1, 0, 1, 4, 5, 7)
INVALID_MODEL_BYTES = b"moon-ort-invalid-onnx-fixture-v1\n\x00\x01\x02"
# Must match the Add initializers written into the model graphs below.
ADD_BIAS = (1.5, -2.0)
OUTPUT_SHIFT = 1.0


def model(name: str, inputs, outputs, nodes, initializers=()):
    graph = helper.make_graph(nodes, name, inputs, outputs, initializer=initializers)
    result = helper.make_model(
        graph,
        producer_name="moon-ort",
        producer_version="0.1.0",
        opset_imports=[helper.make_opsetid("", OPSET)],
    )
    result.ir_version = IR_VERSION
    checker.check_model(result)
    onnx.save(result, ROOT / name)


def as_f32(value: float) -> float:
    return float(array.array("f", [float(value)])[0])


def add_f32(left, right):
    return [as_f32(as_f32(a) + as_f32(b)) for a, b in zip(left, right, strict=True)]


def tensor(dtype: str, shape: list, data: list) -> dict:
    return {"dtype": dtype, "shape": shape, "data": data}


def build_cases(rng: random.Random) -> dict:
    add_input = [rng.choice(EXACT_F32) for _ in range(2)]
    left = [rng.choice(EXACT_I64) for _ in range(2)]
    right = [rng.choice(EXACT_I64) for _ in range(2)]
    if right == left:
        right = [EXACT_I64[(EXACT_I64.index(value) + 1) % len(EXACT_I64)] for value in right]
    scores = [-1.5, 0.25]
    rng.shuffle(scores)
    dynamic_batch1 = [rng.choice(EXACT_F32) for _ in range(2)]
    dynamic_batch3 = [rng.choice(EXACT_F32) for _ in range(6)]
    shifted = [as_f32(as_f32(value) + as_f32(OUTPUT_SHIFT)) for value in scores]

    return {
        "schema_version": 1,
        "generator": {
            "script": "testdata/generate_models.py",
            "seed": SEED,
            "onnx": ONNX_VERSION,
            "opset": OPSET,
            "ir_version": IR_VERSION,
            "ort_reference": ORT_REFERENCE,
            "input_sampling": (
                "random.Random(seed) draws add_f32 inputs, then i64 left/right, "
                "then shuffles the fixed two_outputs scores [-1.5, 0.25], then "
                "draws dynamic batch 1 and batch 3. If the two i64 vectors are "
                "equal, right is rotated one step through EXACT_I64 so a doubled "
                "left input cannot match the expected sum. Pools live in this script."
            ),
            "license": "MIT",
            "license_note": (
                "Self-authored by testdata/generate_models.py. No third-party "
                "weights. Redistributed under the repository LICENSE."
            ),
        },
        "positive": [
            {
                "id": "add_f32",
                "model": "add_f32.onnx",
                "inputs": {"input": tensor("float32", [2], [as_f32(v) for v in add_input])},
                "expected": {
                    "output": tensor("float32", [2], add_f32(add_input, ADD_BIAS)),
                },
            },
            {
                "id": "two_inputs_i64",
                "model": "two_inputs_i64.onnx",
                "inputs": {
                    "left": tensor("int64", [2], left),
                    "right": tensor("int64", [2], right),
                },
                "expected": {
                    "sum": tensor("int64", [2], [a + b for a, b in zip(left, right, strict=True)]),
                },
            },
            {
                "id": "two_outputs_f32_bool",
                "model": "two_outputs_f32_bool.onnx",
                "inputs": {"scores": tensor("float32", [2], [as_f32(v) for v in scores])},
                "expected": {
                    "shifted": tensor("float32", [2], shifted),
                    "positive": tensor("bool", [2], [as_f32(v) > 0.0 for v in scores]),
                },
            },
            {
                "id": "dynamic_identity_f32_batch1",
                "model": "dynamic_identity_f32.onnx",
                "inputs": {
                    "input": tensor("float32", [1, 2], [as_f32(v) for v in dynamic_batch1]),
                },
                "expected": {
                    "output": tensor("float32", [1, 2], [as_f32(v) for v in dynamic_batch1]),
                },
            },
            {
                "id": "dynamic_identity_f32_batch3",
                "model": "dynamic_identity_f32.onnx",
                "inputs": {
                    "input": tensor("float32", [3, 2], [as_f32(v) for v in dynamic_batch3]),
                },
                "expected": {
                    "output": tensor("float32", [3, 2], [as_f32(v) for v in dynamic_batch3]),
                },
            },
        ],
        "negative": [
            {
                "id": "invalid_model",
                "model": "negative/invalid_model.onnx",
                "inputs": {},
                "expect_error": "invalid_model",
                "message_contains": "Protobuf parsing failed",
            },
            {
                "id": "add_f32_wrong_type",
                "model": "add_f32.onnx",
                "inputs": {"input": tensor("int64", [2], [1, 2])},
                "expect_error": "wrong_type",
                "message_contains": "Unexpected input data type",
            },
            {
                "id": "add_f32_wrong_shape",
                "model": "add_f32.onnx",
                "inputs": {"input": tensor("float32", [3], [0.5, 2.0, 1.0])},
                "expect_error": "wrong_shape",
                "message_contains": "Got invalid dimensions",
            },
            {
                "id": "two_inputs_i64_missing_input",
                "model": "two_inputs_i64.onnx",
                "inputs": {"left": tensor("int64", [2], left)},
                "expect_error": "missing_input",
                "message_contains": "Required inputs (['right']) are missing",
            },
        ],
    }


def write_models():
    model(
        "add_f32.onnx",
        [helper.make_tensor_value_info("input", TensorProto.FLOAT, [2])],
        [helper.make_tensor_value_info("output", TensorProto.FLOAT, [2])],
        [helper.make_node("Add", ["input", "bias"], ["output"])],
        [helper.make_tensor("bias", TensorProto.FLOAT, [2], [1.5, -2.0])],
    )
    model(
        "two_inputs_i64.onnx",
        [
            helper.make_tensor_value_info("left", TensorProto.INT64, [2]),
            helper.make_tensor_value_info("right", TensorProto.INT64, [2]),
        ],
        [helper.make_tensor_value_info("sum", TensorProto.INT64, [2])],
        [helper.make_node("Add", ["left", "right"], ["sum"])],
    )
    model(
        "two_outputs_f32_bool.onnx",
        [helper.make_tensor_value_info("scores", TensorProto.FLOAT, [2])],
        [
            helper.make_tensor_value_info("shifted", TensorProto.FLOAT, [2]),
            helper.make_tensor_value_info("positive", TensorProto.BOOL, [2]),
        ],
        [
            helper.make_node("Add", ["scores", "one"], ["shifted"]),
            helper.make_node("Greater", ["scores", "zero"], ["positive"]),
        ],
        [
            helper.make_tensor("one", TensorProto.FLOAT, [1], [1.0]),
            helper.make_tensor("zero", TensorProto.FLOAT, [1], [0.0]),
        ],
    )
    model(
        "dynamic_identity_f32.onnx",
        [helper.make_tensor_value_info("input", TensorProto.FLOAT, ["batch", 2])],
        [helper.make_tensor_value_info("output", TensorProto.FLOAT, ["batch", 2])],
        [helper.make_node("Identity", ["input"], ["output"])],
    )


def write_invalid_model():
    destination = ROOT / "negative"
    destination.mkdir(exist_ok=True)
    (destination / "invalid_model.onnx").write_bytes(INVALID_MODEL_BYTES)


def write_manifest(cases: dict):
    destination = ROOT / "cases"
    destination.mkdir(exist_ok=True)
    text = json.dumps(cases, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
    (destination / "manifest.json").write_text(text, encoding="utf-8")


def main():
    if onnx.__version__ != ONNX_VERSION:
        raise SystemExit(f"onnx {onnx.__version__} != required {ONNX_VERSION}")
    write_models()
    write_invalid_model()
    write_manifest(build_cases(random.Random(SEED)))


if __name__ == "__main__":
    main()
