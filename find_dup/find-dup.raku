# TODO compare lists

sub append($h, $k, $v) {
    with $h{$k} {
        if $_.WHAT === Array {
            $_.push($v);
        }
        else {
            $_ = [$_, $v];
        }
    } else {
        $_ = $v;
    }
}

sub gather-files(IO::Path $path) {
    my %files-map;
    my @dirs;

    for dir $path -> $f {
        if $f.f {
            my $basename = $f.basename;
            append(%files-map, $basename, $f);
        } elsif $f.d {
            @dirs.push($f);
        }
    }
    
    my %dirs-files;
    for @dirs { %dirs-files.append(gather-files($_)) };

    %files-map.append(%dirs-files);
    %files-map
}

sub MAIN(
    Str:D $a where *.IO.d, #= original path
    Str:D $b where *.IO.d, #= destination path
) {
    say "A=$a, B=$b";
    # gather files from A into set{basename => file|@files}, gather files from B
    my %files-a = gather-files $a.IO;
    my %files-b = gather-files $b.IO;

    say "Found A:{%files-a.elems}, B:{%files-b.elems} unique file names.";
    say %files-a;
}
