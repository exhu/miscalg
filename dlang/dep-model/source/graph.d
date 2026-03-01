import std.algorithm.iteration;
import std.algorithm.comparison;
import std.algorithm.searching;
import std.stdio;
import std.format;
import std.traits;
import std.string;
import std.range;

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
            auto found_cycle = ctx.visit(i);
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
        assert(foundCycle.selector is VisitStatus.Selector.cycleFound);
        writefln("%d ctx return cycle %s", n, foundCycle);
        return foundCycle;
    }
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
// metaprogramming experiments
version (none)
{
    private string generateMembers(E, Types...)()
    {
        string members;
        assert(Types.length >= 1);
        static foreach (i, t; Types)
        {
            members ~= "private " ~ t.stringof ~ " " ~ __traits(identifier, EnumMembers!E[i]) ~ ";";
        }
        return members;
    }

    private string generateAccessors(E, Types...)()
    {
        string members;
        assert(Types.length >= 1);
        foreach (i, t; Types)
        {
            auto eId = __traits(identifier, EnumMembers!E[i]);
            auto eName = __traits(identifier, E);
            auto funcName = "get_" ~ eId;
            members ~= t.stringof ~ " " ~ funcName ~ "(){" ~ "assert(selector == "
                ~ eName ~ "." ~ eId ~ ", \"" ~ funcName ~ "\");" ~ "return " ~ eId ~ ";}";
        }
        return members;
    }

    template adtUnion(E, Types...) if (EnumMembers!E.length == Types.length)
    {
        enum string adtUnion = "private " ~ E.stringof ~ " selector; union{" ~ generateMembers!(E,
                    Types)() ~ "}" ~ E.stringof ~ " getTag() { return selector; }" ~ generateAccessors!(E,
                    Types)();
    }

    template adtMembers(E, Types...) if (EnumMembers!E.length == Types.length)
    {
        enum string adtMembers = E.stringof ~ " selector; " ~ generateMembers!(E, Types)();
    }

    struct TestAdt
    {
        enum Selector
        {
            first,
            second,
            empty,
            fourth,
            fifth,
        }

        struct First
        {
            int a = 1;
        }

        struct Second
        {
            int b = 2;
        }

        struct Empty
        {
        }

        struct Fourth
        {
            string s = "fourth";
        }

        mixin(adtUnion!(Selector, First, Second, Empty, Fourth, Empty));
        //mixin(adtMembers!(Selector, First, Second, Empty, Fourth, Empty));
    }

    unittest
    {
        import std.conv;

        //writefln("%s", to!string(typeof(l)));
        auto g = Graph.make_from_edges([Edge(0, 1), Edge(1, 2), Edge(3, 4)]);
        assert(g.nodesCount == 5);

        TestAdt a, b;
        assert(a.selector == TestAdt.Selector.first);
        b = a;
        assert(a.first.a == 1);
        a.fourth.s = "hh test";
        writefln("first = %d, second = %d, third = %s", a.first.a, a.second.b, a.fourth.s);
        string members = generateMembers!(TestAdt.Selector, TestAdt.First, TestAdt.Second);
        writefln("%s", members);
        a.getTag();
        a.get_first();
        a.get_second();
    }

} // version

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
