#!/usr/bin/env python3
"""Generate the self-authored, minimal ONNX fixtures used by moon-ort tests.

Requires the pinned generator dependency: onnx==1.17.0.
"""

from pathlib import Path

import onnx
from onnx import TensorProto, checker, helper


ROOT = Path(__file__).resolve().parent
OPSET = 13


def model(name: str, inputs, outputs, nodes, initializers=()):
    graph = helper.make_graph(nodes, name, inputs, outputs, initializer=initializers)
    result = helper.make_model(
        graph,
        producer_name="moon-ort",
        producer_version="0.1.0",
        opset_imports=[helper.make_opsetid("", OPSET)],
    )
    result.ir_version = 9
    checker.check_model(result)
    onnx.save(result, ROOT / name)


def main():
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


if __name__ == "__main__":
    main()
