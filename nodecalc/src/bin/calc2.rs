/// Calculation Tree, assuming it is semantically correct. It is not and AST, but
/// the final calculation machinery.
///
use std::collections::HashSet;

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

#[derive(Debug, Clone)]
struct Dependency {
    /// source node, that produces value for the target
    source: ExprNodeId,
    target: ExprNodeId,
}

#[derive(Debug)]
struct ExprTree {
    nodes: Vec<ExprNode>,
    deps: Vec<Dependency>,
    tsorted_deps: Vec<ExprNodeId>,
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

    fn node_deps(&self, node_id: ExprNodeId) -> Vec<ExprNodeId> {
        self.deps
            .iter()
            .filter(|e| {
                e.target == node_id
                    && if let ExprNode::Literal { .. } = self.nodes[e.source] {
                        false
                    } else {
                        true
                    }
            })
            .map(|e| e.source)
            .collect()
    }

    fn visit_node(
        &mut self,
        node_id: ExprNodeId,
        permanent: &mut HashSet<ExprNodeId>,
        temp: &mut HashSet<ExprNodeId>,
    ) -> Result<(), String> {
        if permanent.contains(&node_id) {
            return Ok(());
        }
        if temp.contains(&node_id) {
            return Err(String::from(format!("recursive {}", node_id)));
        }
        temp.insert(node_id);

        for d in self.node_deps(node_id) {
            self.visit_node(d, permanent, temp)?;
        }

        temp.remove(&node_id);
        permanent.insert(node_id);
        self.tsorted_deps.push(node_id);

        Ok(())
    }

    /// fails if circular dependency detected
    fn tsort_deps(&mut self) -> Result<(), String> {
        self.tsorted_deps.clear();

        let mut permanent = HashSet::<ExprNodeId>::new();
        let mut temp = HashSet::<ExprNodeId>::new();

        let deps: Vec<_> = self.deps.iter().map(|d| d.target).collect();
        for n in deps {
            self.visit_node(n, &mut permanent, &mut temp)?;
        }

        Ok(())
    }

    /// sorts dependencies and recalculates all, fails if circular deps detected.
    /// must be called first time to initialize and proceeed with calculations.
    pub fn evaluate_all(&mut self) -> Result<(), String> {
        self.deps.clear();
        for i in 0..self.nodes.len() {
            self.add_deps(i);
        }
        self.tsort_deps()?;
        // TODO notify Cell
        Ok(())
    }

    fn visit_node_for_update(
        &mut self,
        node_id: ExprNodeId,
        result: &mut Vec<ExprNodeId>,
    ) {
        // collect all non-Literal nodes
        let deps: Vec<_> = self
            .deps
            .iter()
            .filter(|i| i.source == node_id)
            .map(|i| i.target)
            .collect();

        //println!("deps={:?}", deps);

        result.extend(&deps);
        for d in deps {
            self.visit_node_for_update(d, result);
        }
    }

    /// call when only literals have been updated, i.e. graph has not been changed.
    /// returns updated cells.
    pub fn evaluate_partially(&mut self, updated_ids: &[ExprNodeId]) -> Vec<ExprNodeId> {
        let mut result = Vec::new();

        for u in updated_ids {
            self.visit_node_for_update(*u, &mut result);
        }

        let mut unique_items = HashSet::new();
        result.into_iter().filter(|&e| unique_items.insert(e)).collect()
    }
}

fn main() {
    let mut tree = ExprTree::new();
    tree.add_node(ExprNode::new_literal(LiteralValue::Integer(777)));
    let node_a_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(3)));
    tree.add_node(ExprNode::new_literal(LiteralValue::Integer(888)));
    let node_b_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(5)));
    let node_c_id = tree.add_node(ExprNode::new_sub(node_a_id, node_b_id));
    tree.add_node(ExprNode::new_literal(LiteralValue::Integer(999)));
    let node_d_id = tree.add_node(ExprNode::new_sub(node_c_id, node_b_id));
    tree.add_node(ExprNode::new_sub(node_c_id, node_d_id));
    match &mut tree.nodes[node_d_id] {
        ExprNode::Binary { args, .. } => args[0] = node_c_id,
        _ => {}
    }
    match &mut tree.nodes[node_c_id] {
        ExprNode::Binary { args, .. } => args[0] = node_d_id,
        _ => {}
    }

    println!("{:?}", tree.evaluate_all());
    println!("hello! tree={:?}, node_c_id={}", tree, node_c_id);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_recursion() {
        let mut tree = ExprTree::new();
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(777)));
        let node_a_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(3)));
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(888)));
        let node_b_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(5)));
        let node_c_id = tree.add_node(ExprNode::new_sub(node_a_id, node_b_id));
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(999)));
        let node_d_id = tree.add_node(ExprNode::new_sub(node_c_id, node_b_id));
        tree.add_node(ExprNode::new_sub(node_c_id, node_d_id));
        match &mut tree.nodes[node_d_id] {
            ExprNode::Binary { args, .. } => args[0] = node_c_id,
            _ => {}
        }
        match &mut tree.nodes[node_c_id] {
            ExprNode::Binary { args, .. } => args[0] = node_d_id,
            _ => {}
        }

        let result = tree.evaluate_all();
        println!("{:?}", result);
        println!("hello! tree={:?}, node_c_id={}", tree, node_c_id);

        assert!(result.is_err());
    }

    #[test]
    fn test_ok() {
        let mut tree = ExprTree::new();
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(777)));
        let node_a_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(3)));
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(888)));
        let node_b_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(5)));
        let node_c_id = tree.add_node(ExprNode::new_sub(node_a_id, node_b_id));
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(999)));
        let node_d_id = tree.add_node(ExprNode::new_sub(node_c_id, node_b_id));
        tree.add_node(ExprNode::new_sub(node_c_id, node_d_id));
        let result = tree.evaluate_all();
        println!("{:?}", result);
        println!("hello! tree={:?}, node_c_id={}", tree, node_c_id);

        assert!(result.is_ok());
        assert_eq!(tree.tsorted_deps, [4, 6, 7]);
    }

    #[test]
    fn test_partial() {
        let mut tree = ExprTree::new();
        let node_lit = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(777)));
        let node_a_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(3)));
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(888)));
        let node_b_id = tree.add_node(ExprNode::new_literal(LiteralValue::Integer(5)));
        let node_c_id = tree.add_node(ExprNode::new_sub(node_a_id, node_b_id));
        tree.add_node(ExprNode::new_literal(LiteralValue::Integer(999)));
        let node_d_id = tree.add_node(ExprNode::new_sub(node_c_id, node_b_id));
        let node_last = tree.add_node(ExprNode::new_sub(node_a_id, node_a_id));
        let result = tree.evaluate_all();
        println!("{:?}", result);
        println!("hello! tree={:?}, node_c_id={}", tree, node_c_id);

        assert!(result.is_ok());
        assert_eq!(tree.tsorted_deps, [4, 6, 7]);

        let result = tree.evaluate_partially(&[node_lit]);
        assert_eq!(result.len(), 0);

        let result = tree.evaluate_partially(&[node_a_id]);
        assert_eq!(result, [node_c_id, node_last, node_d_id]);
    }
}
