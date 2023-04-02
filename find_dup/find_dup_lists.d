/*
   take list A and list B.
   exclude full paths that are in list B
   make list of same file names.
   cmp each
   build groups of same files
   display sorted by groups
*/
import std.file;
import std.stdio;
import std.array;
import std.string;
import std.path : baseName;

void process(string[] listA, string[] listB, bool ignoreContents)
{
    stderr.writeln("to process ", listA.length, ", ", listB.length);
    int groupNumber = 0;
    int[string] pathToGroup;

    void updateGroup(string pathA, string pathB)
    {
        if (pathA !in pathToGroup)
        {
            if (pathB !in pathToGroup)
            {
                pathToGroup[pathA] = groupNumber;
                pathToGroup[pathB] = groupNumber;
                groupNumber++;
            }
            else
            {
                pathToGroup[pathA] = pathToGroup[pathB];
            }
        }
        else
        {
            if (pathB !in pathToGroup)
            {
                pathToGroup[pathB] = pathToGroup[pathA];
            }
        }
    }

    foreach (pathA; listA)
    {
        foreach (pathB; listB)
        {
            // skip the same paths, e.g. when we search for dups in the same dir
            if (pathA != pathB)
            {
                // check only the same named files
                if (sameName(pathA, pathB) &&
                    (ignoreContents || sameFileContents(pathA, pathB)))
                {
                    updateGroup(pathA, pathB);
                }
            }
        }
    }

    string[][int] groups;
    foreach (k, v; pathToGroup)
    {
        groups[v] ~= k;
    }

    foreach (k, v; groups)
    {
        writefln("#%d,%s:", k, v[0].baseName);
        foreach (f; v)
        {
            writeln(f);
        }
    }
}

bool sameName(string a, string b)
{
    auto baseA = baseName(a);
    auto baseB = baseName(b);

    import std.uni : sicmp;

    return sicmp(baseA, baseB) == 0;
}

unittest
{
    assert(sameName("/IMG_9812.JPG", "/IMG_9812.jpg"));
}

bool sameFileContents(string fileA, string fileB)
{
    if (getSize(fileA) == getSize(fileB))
    {
        //stderr.writeln("Comparing ", fileA, ", ", fileB);
        auto f1 = File(fileA, "rb");
        auto f2 = File(fileB, "rb");
        enum chunkSize = 4096;
        auto f1_range = f1.byChunk(chunkSize);
        auto f2_range = f2.byChunk(chunkSize);

        import std.algorithm.comparison : equal;

        return equal(f1_range, f2_range);
    }
    return false;
}

string[] readLines(string fn)
{
    return readText(fn).splitLines();
}

import std.getopt;

void usage(GetoptResult helpInfo)
{
    defaultGetoptPrinter("Usage: find_dup_lists [options] file1 file2\n\nWhere files contain
absolute file names separated by new line.

You can generate those lists with 'fd -t f . /my-dir-to-list/subdir/'

Note: case folding is basic, i.e. no special rules are used for Greek, German
etc. where letters not merely change case, but may be replaced with several
letters.
", helpInfo.options);
}

int main(string[] args)
{
    bool ignoreContents = false;
    auto helpInfo = getopt(args, "n",
        "Do not check file contents, print only matching filenames (case-insensitive)",
        &ignoreContents);

    if (helpInfo.helpWanted)
    {
        usage(helpInfo);
        return 0;
    }

    enum minArgs = 3;
    enum maxArgs = 3;

    if (args.length < minArgs || args.length > maxArgs)
    {
        usage(helpInfo);
        return 1;
    }

    process(readLines(args[1]), readLines(args[2]), ignoreContents);

    return 0;
}
