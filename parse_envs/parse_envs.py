#!/usr/bin/python3
import sys, re

def parse_lines(lines: list) -> dict:
    line_re = re.compile('(.*)=(.*)')
    parsed_dict = {}
    for l in lines:
        m = line_re.match(l)
        if m:
            k,v = m.group(1,2)
            parsed_dict[k] = v
    
    return parsed_dict


def parse_file(fname: str) -> dict:
    f = open(fname, 'r')
    lines = f.readlines()
    f.close()
    parsed = parse_lines(lines)
    return parsed


def _print_usage():
    print("parse_envs.py <envfile.txt> -- output of windows 'set' command.")

def _main():
    if len(sys.argv) != 2:
        _print_usage()
        sys.exit(1)

    parsed = parse_file(sys.argv[1])
    print(parsed)

    sys.exit(0)


if __name__ == "__main__":
    _main()