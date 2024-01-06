use std::collections::HashMap;

type CalcNodeId = usize;

trait CalcUpdate {
    fn update(&self, node_id: CalcNodeId, tree: &CalcTree) -> Self;
}

trait IntValue {
    fn int_value(&self) -> i32;
}

#[derive(Clone)]
struct LiteralValue {
    pub value: i32,
}

impl IntValue for LiteralValue {
    fn int_value(&self) -> i32 {
        self.value
    }
}

/// subtraction, to easily test order of evaluation
#[derive(Clone)]
struct SubValue {
    pub cached_value: Option<i32>,
    pub args: Vec<CalcNodeId>,
}

impl SubValue {
    pub fn new(args: Vec<CalcNodeId>) -> SubValue {
        SubValue {
            cached_value: None,
            args,
        }
    }
}

impl IntValue for SubValue {
    fn int_value(&self) -> i32 {
        self.cached_value.unwrap_or(0)
    }
}

impl CalcUpdate for SubValue {
    fn update(&self, _node_id: CalcNodeId, tree: &CalcTree) -> Self {
        if self.args.len() < 2 {
            panic!("self.args < 2");
        }

        let mut result = tree.int_value_from(self.args[0]);
        for n_id in &self.args[1..] {
            result = result - tree.int_value_from(*n_id);
        }

        let mut modified = self.clone();
        modified.cached_value = Some(result);
        modified
    }
}

#[derive(Clone)]
enum ExprNode {
    Literal(LiteralValue),
    Expression(SubValue),
}

impl IntValue for ExprNode {
    fn int_value(&self) -> i32 {
        match self {
            ExprNode::Literal(e) => e.int_value(),
            ExprNode::Expression(e) => e.int_value(),
        }
    }
}

struct CalcTree {
    nodes: Vec<ExprNode>,
    sym_table: HashMap<String, CalcNodeId>,
}

impl CalcTree {
    pub fn new() -> CalcTree {
        CalcTree {
            nodes: Vec::new(),
            sym_table: HashMap::new(),
        }
    }

    pub fn add_node(&mut self, node: ExprNode) -> CalcNodeId {
        let node_id = self.nodes.len();
        self.nodes.push(node);

        node_id
    }

    pub fn int_value_from(&self, node_id: CalcNodeId) -> i32 {
        self.nodes[node_id].int_value()
    }

    pub fn add_symbol(&mut self, name: String, node_id: CalcNodeId) {
        self.sym_table.insert(name, node_id);
    }

    pub fn node_from(&self, node_id: CalcNodeId) -> &ExprNode {
        &self.nodes[node_id]
    }

    pub fn update_node(&mut self, node_id: CalcNodeId, node: ExprNode) {
        self.nodes[node_id] = node;
    }
}

fn main() {
    let mut tree = CalcTree::new();
    let node_a = ExprNode::Literal(LiteralValue { value: 3 });
    let node_b = ExprNode::Literal(LiteralValue { value: 5 });
    let node_a_id = tree.add_node(node_a);
    let node_b_id = tree.add_node(node_b);
    let node_c = ExprNode::Expression(SubValue::new(vec![node_a_id, node_b_id]));
    let node_c_id = tree.add_node(node_c);

    match tree.node_from(node_c_id) {
        ExprNode::Expression(e) => {
            let updated = e.update(node_c_id, &tree);
            tree.update_node(node_c_id, ExprNode::Expression(updated));
        },

        _ => (),
    }

    let node = tree.node_from(node_c_id);
    if let ExprNode::Expression(value) = node {
        println!("Hello, world! {}", value.int_value());
    }

}
