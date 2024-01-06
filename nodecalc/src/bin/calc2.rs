/// Calculation Tree, assuming it is semantically correct. It is not and AST, but
/// the final calculation machinery.

type ExprNodeId = usize;

#[derive(Clone, Debug)]
enum LiteralValue {
    Integer(i64),
    Float(f64),
    String(String),
    Bool(bool),
}

#[derive(Clone, Debug)]
enum BinaryOp {
    IntSub,
    StrConcat,
}

#[derive(Clone, Debug)]
enum UnaryOp {
    // insert variable/const value
    //ReadValue { symbol_name: String },
    BoolNot,
}

#[derive(Clone, Debug)]
enum ExprNode {
    /// literal value without dependencies
    Literal { value: LiteralValue },
    /// calculation node, with multiple dependencies
    Unary {
        cached_value: Option<LiteralValue>,
        arg: ExprNodeId,
        operation: UnaryOp,
    },
    Binary {
        cached_value: Option<LiteralValue>,
        args: [ExprNodeId; 2],
        operation: BinaryOp,
    },
    /// target cell, this node is used for a fixed reference number for the result,
    /// and notifications
    Cell { source: ExprNodeId },
}

impl ExprNode {
    fn new_literal(value: LiteralValue) -> ExprNode {
        ExprNode::Literal { value }
    }

    fn new_sub(a: ExprNodeId, b: ExprNodeId) -> ExprNode {
        ExprNode::Binary {
            cached_value: None,
            args: [a, b],
            operation: BinaryOp::IntSub,
        }
    }
}

#[derive(Debug)]
struct Dependency {
    /// source node, that produces value for the target
    source: ExprNodeId,
    target: ExprNodeId,
}

#[derive(Debug)]
struct ExprTree {
    nodes: Vec<ExprNode>,
    deps: Vec<Dependency>,
    tsorted_deps: Vec<Dependency>,
}

impl ExprTree {
    pub fn new() -> ExprTree {
        ExprTree {
            nodes: Vec::new(),
            deps: Vec::new(),
            tsorted_deps: Vec::new(),
        }
    }

    pub fn add_node(&mut self, node: ExprNode) -> ExprNodeId {
        let node_id = self.nodes.len();
        self.nodes.push(node);
        self.add_deps(node_id);
        node_id
    }

    fn add_deps(&mut self, node_id: ExprNodeId) {
        let node = &self.nodes[node_id];
        match node {
            ExprNode::Unary { arg, .. } => self.deps.push(Dependency {
                source: *arg,
                target: node_id,
            }),
            ExprNode::Binary { args, .. } => {
                self.deps.push(Dependency {
                    source: args[0],
                    target: node_id,
                });
                self.deps.push(Dependency {
                    source: args[1],
                    target: node_id,
                });
            }
            ExprNode::Cell { source, .. } => self.deps.push(Dependency {
                source: *source,
                target: node_id,
            }),
            _ => (),
        }
    }

    fn tsort_deps(&mut self) {
        self.tsorted_deps.clear();
    }

    /// sorts dependencies and recalculates all
    pub fn evaluate_all(&mut self) -> Result<(), ()> {
        self.tsort_deps();
        Ok(())
    }
}

fn main() {
    let mut tree = ExprTree::new();
    let node_a_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(3)));
    let node_b_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(5)));
    let node_c_id = tree.add_node(ExprNode::new_sub(node_a_id, node_b_id));
    println!("hello! tree={:?}, node_c_id={}", tree, node_c_id);
    println!("{:?}", tree.evaluate_all());
}
