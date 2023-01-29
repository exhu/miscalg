import std.stdio;
import std.file;
import std.path;
import std.sumtype;

alias FileOrMulti = SumType!(string, string[]);
alias PathsMap = FileOrMulti[string];

pure void append(ref PathsMap m, string k, string full) {
    if (k !in m) {
        m[k] = full;
    } else {
        m[k].match!(
            (string s) { m[k] = [s, full]; },
            (string[] a) { a~=full; },
        );
    }
}

PathsMap gather_files(string root) {
    PathsMap result;
    foreach (string name; dirEntries(root, SpanMode.depth)) {
        if (name.isFile) {
            append(result, name.baseName, name);
        }
    }
    return result;
}

void print_paths(in FileOrMulti files) {
    files.match!(
        (string s) { writeln(s); },
        (in string[] a) { foreach(f; a) writeln(f); }
    );
}

void process_dups(in PathsMap listA, in PathsMap listB) {
    foreach (k, v; listA)
    {
        if (k in listB) {
            print_paths(v);
            print_paths(listB[k]);
        }
    }
}

void usage() {
    writeln("Usage: find_dup <path a> <path b>");
}

int main(string[] args) {
    if (args.length != 3) {
        usage();
        return 1;
    }

    const pathA = args[1];
    const pathB = args[2];

    if (pathA.exists() && pathB.exists() && pathA.isDir() && pathB.isDir()) {
        const listA = gather_files(pathA);
        const listB = gather_files(pathB);
        process_dups(listA, listB);
        return 0;
    }

    stderr.writeln("Must be existing directories.");

    return 1;
}