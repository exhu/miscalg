module recalc;
import std.stdio : writefln, writeln;
import std.format : format;

// build dependency tree
// on changes mark nodes to be updated in dep. order
// for each marked node do recalc

/*
a
b = a + 3
c = b * d
d = a + 4
e = c + d

a -> b
a -> d
b -> c
d -> c
c -> e
d -> e


if 'a' changes:
    update b (aN, 3), c (bN, dOLD!)

*/

class ValueNode
{
    void update(int newData)
    {
        writefln("update %s with %d, old %d", name, newData, data);
        data = newData;
    }

    void updateWithDeps(int newData)
    {
        update(newData);
        foreach (i; deps)
        {
            i.updateWithDeps(data);
        }
    }

    this(immutable string aName)
    {
        name = aName;
    }

    override string toString() const @safe 
    {
        string sdeps;
        foreach (d; deps)
        {
            sdeps ~= format("%s,\n",d.toString());
        }
        string result = format("%s=%d,[%s]", name, data, sdeps);
        return result;
    }

    int data = 0;
    immutable string name;
    ValueNode[] deps;
}

ValueNode build()
{
    ValueNode a = new ValueNode("a");
    auto b = new ValueNode("b");
    auto c = new ValueNode("c");
    auto d = new ValueNode("d");
    auto e = new ValueNode("e");

    /*
    a -> b
    a -> d
    b -> c
    d -> c
    c -> e
    d -> e
    */
    a.deps ~= b;
    a.deps ~= d;
    b.deps ~= c;
    d.deps ~= c;
    c.deps ~= e;
    d.deps ~= e;

    return a;
}

ValueNode[] topSorted(ValueNode start)
{
    debug
    {
        bool[ValueNode] nodes = [start: true];
        struct Edge
        {
            ValueNode from, to;
            string toString() const
            {
                return "from " ~ from.name ~ " to " ~ to.name;
            }
        }
        Edge[] edges;
        // discover all nodes and edges
        void collect(ValueNode s)
        {
            foreach (n; s.deps)
            {
                nodes[n] = true;
                edges ~= Edge(s, n);
                collect(n);
            }
        }

        collect(start);

        import std.algorithm : map;
        import std.conv : to;
        writefln("Nodes = %s", nodes.keys.map!(n => n.name));
        writefln("Edges = %s", edges.map!(to!string));
    }

    ValueNode[] result;
    bool[ValueNode] permanent, temp;

    void visitNode(ValueNode n)
    {
        if (n in permanent) return;
        if (n in temp) throw new Exception("cyclic graph, no topo. order exists");

        temp[n] = true;
        // can exhaust stack
        foreach (d; n.deps) visitNode(d);

        temp.remove(n);
        permanent[n] = true;
        result ~= n;
    }

    visitNode(start);

    import std.algorithm : reverse;
    return reverse(result);
}

void updateTopsorted()
{
    writeln("updateTopSorted");
    auto root = build();

    auto sorted = topSorted(root);
    import std.algorithm : map;
    writefln("topSorted = %s", sorted.map!(a => a.name));
    writefln("before = %s", root);

    foreach(n; sorted)
    {
        n.update(1);
    }

    writefln("after = %s", root);
}

void updateWithDeps()
{
    writeln("updateWithDeps");
    auto root = build();
    writefln("before = %s", root);
    root.updateWithDeps(1);
    writefln("after = %s", root);
}

void main()
{
    updateWithDeps();
    updateTopsorted();
}