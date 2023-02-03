import std.file : exists, isDir, isFile, dirEntries, SpanMode;
import std.path : baseName;
import std.stdio : writeln, stderr;
import std.sumtype;

alias FileOrMulti = SumType!(string, string[]);
alias PathsMap = FileOrMulti[string];

pure void append(ref PathsMap m, string k, string full)
{
    if (k !in m)
    {
        m[k] = full;
    }
    else
    {
        m[k].match!(
            (string s) { m[k] = [s, full]; },
            (string[] a) { a ~= full; },
        );
    }
}

pure void append(ref PathsMap m, string k, in FileOrMulti full)
{
    const as_array = full.match!(
        (in string s) { return [s]; },
        (in string[] m) { return m; }
    );

    m[k].match!(
        (string s) { m[k] = [s] ~ as_array; },
        (string[] a) { a ~= as_array; },
    );
}

PathsMap gatherFiles(string root)
{
    PathsMap result;
    foreach (string name; dirEntries(root, SpanMode.depth))
    {
        if (name.isFile)
        {
            append(result, name.baseName, name);
        }
    }
    return result;
}

void printPaths(in FileOrMulti files)
{
    files.match!(
        (string s) { writeln(s); },
        (in string[] a) {
        foreach (f; a)
            writeln(f);
    }
    );
}

PathsMap collectSameNames(in PathsMap listA, in PathsMap listB)
{
    PathsMap result;
    // print file name, then the paths it's found in listA,
    // then in listB
    foreach (k, v; listA)
    {
        v.match!(
            (in string[] m) { result[k] = v; },
        (_) {},
        );
        if (k in listB)
        {
            append(result, k, listB[k]);
        }
    }

    return result;

}

PathsMap processDups(in PathsMap listA, in PathsMap listB)
{
    PathsMap sameNames = collectSameNames(listA, listB);

    // TODO filter sameNames by areSameFiles

    PathsMap result;
    return result;
}

bool areSameFiles(in string fileA, string fileB)
{
    import std.process : execute;

    // Exit status is 0 if inputs are the same, 1 if different, 2 if trouble.
    return execute(["cmp", fileA, fileB]).status == 0;
}

void usage()
{
    writeln("Usage: find_dup <path a> [path b]");
}

void printDups(in PathsMap dups)
{
    foreach (k, v; dups)
    {
        writeln(k);
        printPaths(v);
    }
}

int main(string[] args)
{
    if (args.length < 2 || args.length > 3)
    {
        usage();
        return 1;
    }

    const pathA = args[1];
    const pathB = args.length == 3 ? args[2] : null;

    const pathBok = !pathB || (pathB.exists() && pathB.isDir());

    if (pathA.exists() && pathA.isDir() && pathBok)
    {
        const listA = gatherFiles(pathA);
        const listB = pathB ? gatherFiles(pathB) : new PathsMap;
        const dups = processDups(listA, listB);
        printDups(dups);
        return 0;
    }

    writeln(stderr, "Must be existing directories.");

    return 1;
}
