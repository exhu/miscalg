#!/usr/bin/python3
import sys, re

def print_usage():
    print("parse_envs.py <envfile.txt> -- output of windows 'set' command.")


def parse_lines(lines):
    line_re = re.compile('(.*)=(.*)')
    parsed_dict = {}
    for l in lines:
        m = line_re.match(l)
        if m:
            k,v = m.group(1,2)
            parsed_dict[k] = v
    
    return parsed_dict

def main():
    if len(sys.argv) != 2:
        print_usage()
        sys.exit(1)

    f = open(sys.argv[1], 'r')
    lines = f.readlines()
    f.close()

    parsed = parse_lines(lines)
    print(parsed)

    sys.exit(0)

main()