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

fn main() {
    println!("hello! {}", 1);
}
