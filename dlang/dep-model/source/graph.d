// TODO rename to follow D style
// TODO clean up code
// TODO try to use functional style -- non-member or static functions instead of methods
// if only one field is used to simplify unit tests
// TODO add impl using SumType

import std.algorithm.iteration;
import std.algorithm.comparison;
import std.algorithm.searching;
import std.stdio;
import std.string;

alias CellIndex = size_t;

struct Edge
{
    CellIndex from_cell, to_cell;
}

alias Edges = Edge[];

struct Graph
{
    immutable Edges edges;
    immutable size_t nodesCount;

    static Graph make_from_edges(immutable Edges edges)
    {
        immutable max_node = fold!((a, c) => max(a, max(c.from_cell, c.to_cell)))(edges, 0L);
        return Graph(edges, max_node + 1);
    }

    void dump()
    {
        print_edges(edges);
    }

    auto all_dest_from(CellIndex n)
    {
        auto f = (const Edge e) => e.from_cell == n;
        auto m = (const Edge e) => e.to_cell;
        return filter!(f)(edges).map!m();
    }

    string generate_dot_text(string name)
    {
        string buf;
        buf ~= format("digraph \"%s\" {\n", name);
        auto e = (const Edge e) => buf ~= format("%d -> %d\n", e.from_cell, e.to_cell);
        each!e(edges);
        buf ~= "}";
        return buf;
    }

    SortResult tsort()
    {
        auto ctx = SortContext(this);
        for (auto i = 0; i < nodesCount; ++i)
        {
            writefln("top iter %d", i);
            auto found_cycle = visit(ctx, i);

            if (found_cycle.selector is SortContext.VisitStatus.Selector.cycleFound)
            {
                writeln("cycle!");
                return SortResult.makeCycle(found_cycle.cycle);
            }
        }
        writeln("sorted!");
        return SortResult.makeSorted(ctx.sorted);
    }
}

void print_edges(const Edges edges)
{
    auto f = (const Edge n) => writefln("edge %d -> %d", n.from_cell, n.to_cell);
    each!(f)(edges);
}

struct SortResult
{
    enum Selector
    {
        sorted,
        cycle,
    }

    Selector result;
    union
    {
        CellIndex[] sorted;
        CellIndex cycle;
    }

    this(CellIndex cycle)
    {
        result = Selector.cycle;
        this.cycle = cycle;
    }

    this(CellIndex[] sorted)
    {
        this.sorted = sorted;
        result = Selector.sorted;
    }

    static SortResult makeCycle(CellIndex c)
    {
        return SortResult(c);
    }

    static SortResult makeSorted(CellIndex[] s)
    {
        return SortResult(s);
    }
}

private struct SortContext
{
    Graph graph;
    CellIndex[] sorted, perm_marked, temp_marked;

    struct VisitStatus
    {
        enum Selector
        {
            continueVisiting,
            cycleFound,
        }

        Selector selector = Selector.continueVisiting;
        CellIndex cycle = CellIndex.max;

        this(CellIndex cycle)
        {
            this.cycle = cycle;
            selector = Selector.cycleFound;
        }

        bool isCycle()
        {
            return selector is Selector.cycleFound;
        }
    }

    void mark_perm(CellIndex n)
    {
        perm_marked ~= n;
    }

    void add_to_sorted(CellIndex n)
    {
        sorted ~= n;
    }

    void mark_temp(CellIndex n)
    {
        temp_marked ~= n;
    }

    version (none)
    {
        VisitStatus visit(CellIndex n)
        {
            writefln("%d visit", n);
            if (find(perm_marked, n).empty == false)
            {
                writeln("already perm");
                return VisitStatus();
            }
            else if (find(temp_marked, n).empty == false)
            {
                writefln("%d early cycle", n);
                return VisitStatus(n);
            }
            mark_temp(n);
            auto fvisit(CellIndex c)
            {
                writefln("%d ctx fvisit %d", n, c);
                auto r = visit(c);
                writefln("%d ctx fvisit result %s", n, r);
                return r;
            }

            auto is_cycle(in VisitStatus s)
            {
                auto r = (s.selector is VisitStatus.Selector.cycleFound);
                writefln("%d is_cycle %s", n, r);
                return r;
            }

            auto nodes_of_n = graph.all_dest_from(n);
            writefln("%d nodes_of_n = %s", n, nodes_of_n);

            auto mapped = map!fvisit(nodes_of_n);
            writefln("%d mapped", n);
            // here there's probably compiler bug, since it fails
            auto foundRange = find!is_cycle(mapped);
            //writefln("range: %s", foundRange);
            mark_perm(n);
            add_to_sorted(n);
            if (foundRange.empty)
            {
                writefln("%d ctx continue", n);
                return VisitStatus(VisitStatus.Selector.continueVisiting);
            }
            auto foundCycle = foundRange.front;
            // compiler bug if find over map range is used
            assert(foundCycle.selector is VisitStatus.Selector.cycleFound);
            writefln("%d ctx return cycle %s", n, foundCycle);
            return foundCycle;
        }
    }
}

SortContext.VisitStatus visit(SortContext ctx, CellIndex n)
{
    writefln("%d visit", n);
    if (find(ctx.perm_marked, n).empty == false)
    {
        writeln("already perm");
        return SortContext.VisitStatus();
    }
    else if (find(ctx.temp_marked, n).empty == false)
    {
        writefln("%d early cycle", n);
        return SortContext.VisitStatus(n);
    }
    ctx.mark_temp(n);
    auto nodes_of_n = ctx.graph.all_dest_from(n);
    writefln("%d nodes_of_n = %s", n, nodes_of_n);

    auto foundCycle = SortContext.VisitStatus();
    foreach (i; nodes_of_n)
    {
        foundCycle = visit(ctx, i);
        if (foundCycle.isCycle)
            break;
    }
    ctx.mark_perm(n);
    ctx.add_to_sorted(n);
    if (!foundCycle.isCycle)
    {
        writefln("%d ctx continue", n);
        return SortContext.VisitStatus();
    }
    assert(foundCycle.selector is SortContext.VisitStatus.Selector.cycleFound);
    writefln("%d ctx return cycle %s", n, foundCycle);
    return foundCycle;
}

unittest
{
    auto fvisit(CellIndex c)
    {
        if (c & 1)
            return SortContext.VisitStatus();
        return SortContext.VisitStatus(c);
    }

    auto isCycle(SortContext.VisitStatus s)
    {
        return s.selector is SortContext.VisitStatus.Selector.cycleFound;
    }

    auto mapped = map!fvisit([2]);
    auto found = find!isCycle(mapped);
    assert(!found.empty);
    assert(found.front.selector is SortContext.VisitStatus.Selector.cycleFound);

}

unittest
{
    immutable edges = [Edge(0, 1), Edge(2, 1), Edge(1, 3), Edge(3, 2)];
    auto graph = Graph.make_from_edges(edges);
    graph.dump();
    auto gv = graph.generate_dot_text("mygr");
    toFile(gv, "temp.gv");
    auto sorted = graph.tsort();
    writefln("sorted: %s", sorted.result);
}
