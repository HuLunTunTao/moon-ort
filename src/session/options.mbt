///|
/// Graph optimization level for a CPU session.
///
/// These are the ONNX Runtime `GraphOptimizationLevel` values the raw API accepts.
pub(all) enum GraphOptimization {
  DisableAll
  Basic
  Extended
  Layout
  All
} derive(Eq)

///|
pub extend GraphOptimization with Eq::{not_equal, equal}

///|
fn GraphOptimization::to_raw(self : GraphOptimization) -> Int {
  match self {
    DisableAll => @raw.graph_optimization_disable_all
    Basic => @raw.graph_optimization_basic
    Extended => @raw.graph_optimization_extended
    Layout => @raw.graph_optimization_layout
    All => @raw.graph_optimization_all
  }
}

///|
/// Map a raw graph-optimization code.
///
/// Only the five levels the raw setter accepts are valid. Unknown codes return
/// `None`; callers that configure a session pass the enum itself.
pub fn GraphOptimization::from_raw(code : Int) -> GraphOptimization? {
  if code == @raw.graph_optimization_disable_all {
    Some(DisableAll)
  } else if code == @raw.graph_optimization_basic {
    Some(Basic)
  } else if code == @raw.graph_optimization_extended {
    Some(Extended)
  } else if code == @raw.graph_optimization_layout {
    Some(Layout)
  } else if code == @raw.graph_optimization_all {
    Some(All)
  } else {
    None
  }
}

///|
/// Sequential or parallel execution inside one session.
pub(all) enum ExecutionMode {
  Sequential
  Parallel
} derive(Eq)

///|
pub extend ExecutionMode with Eq::{not_equal, equal}

///|
fn ExecutionMode::to_raw(self : ExecutionMode) -> Int {
  match self {
    Sequential => @raw.execution_sequential
    Parallel => @raw.execution_parallel
  }
}

///|
fn ExecutionMode::from_raw(code : Int) -> ExecutionMode {
  if code == @raw.execution_sequential {
    Sequential
  } else if code == @raw.execution_parallel {
    Parallel
  } else {
    abort("execution mode is invalid")
  }
}

///|
/// CPU session options. The `OrtSessionOptions` pointer stays in the raw shim.
///
/// v0.1 does not append execution providers, load a model from a URL, or attach
/// a device buffer. Closing the options releases them exactly once. A session
/// already created from these options stays open.
pub struct SessionOptions {
  priv raw : @raw.SessionOptions
}

///|
/// Create options for `runtime`.
pub fn SessionOptions::create(
  runtime : @raw.Runtime,
) -> SessionOptions raise @raw.OrtError {
  { raw: @raw.SessionOptions::create(runtime), }
}

///|
/// Release the options exactly once.
pub fn SessionOptions::close(self : SessionOptions) -> Unit raise @raw.OrtError {
  self.raw.close()
}

///|
/// Set intra-op threads. A negative count is `InvalidArgument` and is not stored.
///
/// Zero is left for ONNX Runtime as its default thread count.
pub fn SessionOptions::set_intra_op_threads(
  self : SessionOptions,
  threads : Int,
) -> Unit raise @raw.OrtError {
  self.raw.set_intra_op_threads(threads)
}

///|
/// Set inter-op threads. A negative count is `InvalidArgument` and is not stored.
///
/// Zero is left for ONNX Runtime as its default thread count.
pub fn SessionOptions::set_inter_op_threads(
  self : SessionOptions,
  threads : Int,
) -> Unit raise @raw.OrtError {
  self.raw.set_inter_op_threads(threads)
}

///|
pub fn SessionOptions::set_graph_optimization_level(
  self : SessionOptions,
  level : GraphOptimization,
) -> Unit raise @raw.OrtError {
  self.raw.set_graph_optimization_level(level.to_raw())
}

///|
pub fn SessionOptions::set_execution_mode(
  self : SessionOptions,
  mode : ExecutionMode,
) -> Unit raise @raw.OrtError {
  self.raw.set_execution_mode(mode.to_raw())
}

///|
/// Read the execution mode back from ONNX Runtime.
pub fn SessionOptions::execution_mode(
  self : SessionOptions,
) -> ExecutionMode raise @raw.OrtError {
  ExecutionMode::from_raw(self.raw.execution_mode())
}
