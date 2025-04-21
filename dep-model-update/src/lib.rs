/// Framework to be used for reactive ViewModel, e.g. developing UIs that
/// are not source code based, but with a graphical tool, spreadsheet apps etc.
/// The model has input values, calculation nodes, and events. All calculation
/// is driven by the input values updates, evaluated following the dependency
/// graph.
/// The evaluation graph supports switchable nodes, where node calculation is
/// not necessary if the parent node decides so, e.g. to implement
/// conditional variables, e.g. there are two subnodes for sum and
/// multiplication in {a = when b is true: c+d, else e*f}. The multiplication
/// evaluation is not necessary if b is false, so {e*f} is marked as inactive
/// node, while the dependency graph still triggers {e*f} node evaluation,
/// when either e or f is changed.
/// Nodes: a, BRANCH, NB, SUM, MUL, b, c, d, e, f in the evaluation:
/// a = BRANCH@{NB@{when c < 30}: SUM@{c+d}, else MUL@{e*f}}
/// Dependencies:
/// BRANCH -> a
/// NB -> BRANCH
/// SUM -> BRANCH
/// MUL -> BRANCH
/// c -> NB
/// NB -> SUM
/// NB -> MUL
/// c -> SUM
/// d -> SUM
/// e -> MUL
/// f -> MUL
///
//use petgraph::algo::toposort;
use petgraph::graph::DiGraph;
//use petgraph::visit::{Bfs, GraphBase, Walker};
use petgraph::visit::GraphBase;
use std::collections::HashMap;

pub enum ExprType {
    Error(String),
    Bool,
    I32,
    U32,
    F32,
    F64,
    StringType,
    Array,
    Map,
}

pub type NodeList = Vec<CalcNode>;

pub struct ArrayNode {
    pub contents: NodeList,
}

pub struct MapNode {
    pub contents: HashMap<String, CalcNode>,
}

pub struct FnCallNode {
    pub name: String,
    pub args: NodeList,
}

pub struct RefNode {
    pub name: String,
}

pub enum CalcNode {
    BoolLiteral(bool),
    I32Literal(i32),
    U32Literal(u32),
    I64Literal(i64),
    U64Literal(u64),
    F32Literal(f32),
    F64Literal(f64),
    StringLiteral(String),
    Array(ArrayNode),
    Map(MapNode),
    FnCall(FnCallNode),
    // reference to node by name
    RefByName(RefNode),
}

impl CalcNode {
    pub fn from_string(value: String) -> CalcNode {
        CalcNode::StringLiteral(value)
    }
}

type ModelGraph = DiGraph<CalcNode, ()>;
type NodeId = <ModelGraph as GraphBase>::NodeId;

// Model must be valid, constructed with ModelBuilder, otherwise would panic.
pub struct Model {
    // model input values
    input: HashMap<String, CalcNode>,
    // local variables/consts for ui expressions
    //locals: HashMap<String, CalcNode>,

    // evaluation order
    //toposorted: Vec<NodeId>,
    //graph: ModelGraph,
}

impl Model {
    pub fn update_string(&mut self, name: &str, value: String) -> bool {
        if let Some(v) = self.input.get_mut(name) {
            *v = CalcNode::from_string(value);
            return true;
        }
        return false;
    }
}

// constructs a model from a UI definition, validates
pub struct ModelBuilder {
    // model input values
    //input: HashMap<String, CalcNode>,
    // local variables/consts for ui expressions
    //locals: HashMap<String, CalcNode>,
}

// TODO validate node tree, e.g. cannot insert Float32Literal node into FnCall
// that accepts strings
//

pub fn ret_err(a: i32) -> Result<i32, ()> {
    if a != 0 {
        Ok(a * 3)
    } else {
        Err(())
    }
}

pub fn ignore_err(a: i32) {
    if let Ok(i) = ret_err(a) {
        println!("{}", i)
    }
}
