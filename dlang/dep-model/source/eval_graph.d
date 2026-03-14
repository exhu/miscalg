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
/// a = BRANCH@{when NB@{c < 30}: SUM@{c+d}, else MUL@{e*f}}
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
/// Types of nodes: immediate value,
/// reference to value (node_id),
/// unary operation (operation, node_id),
/// binary operation (operation, node_id, node_id),
/// branch(bool expression node_id, conditional node_id for true, conditional node_id for false),
/// conditional node(node id of conditional expr, node_id for expression).
///
/// So there's a tsort list.
/// And an execution queue, which can be processed by multiple threads.
/// The queue population step:
///     - take the next item from the list if its dependencies already calculated.
///     - repeat until there are no free items, or the end of list is reached.
/// The queue is either empty or has items that can be executed in parallel.
///
/// Because previous (leaf) nodes can take longer to evaluate, we cannot
/// assume that those are resolved when taking next nodes further to the root.
///
///
/// Simplification of the graph (data conversion and calculations are
/// implementation details for the user of the framework):
///     - input node (no dependencies, those nodes are the only ones that trigger
///     evaluation of the graph)
///     - user node (function, dependencies = array of node_id)
///     - boolean node (function -> bool, dependencies = array of node_id)
///     - branch node (boolean node_id, branch a node_id, branch b node_id)
///
///
/// Simplification:
/// value_type = boolean or user
/// node variants:
/// immediate value of value_type (e.g. a constant or a varying input value, no dependencies), 
/// function_call (any expression is a function, return value is of value_type, arguments are
/// node_ids which declare the dependencies),
/// conditional_expression = immediate or function_call returning a boolean value
/// conditional_call (node_id of conditional_expression, condition (true or false), arguments, return value_type)
/// branch (node_id of conditional_expression, conditional_call node_id A if conditional_expression is true,
/// conditional_call node_id B if false;
/// both A and B must return the same value_type which becomes the value_type of the branch node.

/// Phases:
/// - prepare:
/// -- build node graph
/// -- topological sort
/// -- report and exclude cycle nodes
/// - update:
/// -- update immediate/input values
/// -- run evaluation, read/store calculated values

import graph;

enum ValueType
{
    boolean,
    user
}

struct NodeValue(T)
{
    ValueType type;
    union
    {
        bool booleanValue;
        T userValue;
    }
}

struct BoolNode
{
    bool value;
}

alias CellIndexes = graph.CellIndex[];
    
struct BoolFunctionNode(T)
{
    bool delegate(in NodeValue!(T)[] arguments) func;
    CellIndexes dependencies;
}

struct BranchNode
{
    /// condition points to bool node or bool func node
    /// BranchNode depends on 
    /// condition, onTrue, onFalse
    /// and branches depend on condition
    graph.CellIndex condition, onTrue, onFalse;
}

// TODO how to adjust node update order regarding topologically sorted list?
// TODO how to propagate node inactivity via branches of branches? toposorted is inverted, so
// inactive nodes may stand before active ones in order...

/// During graph evaluation BranchNode adds onTrue or onFalse to inactive
alias DisabledNodes = CellIndexes;

struct Node
{
    

}
