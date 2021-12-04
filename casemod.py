from typing import Union
from dataclasses import dataclass
from sys import argv, exit

def _modstring(lowercase_input, start) -> Union[str, None]:
    c = lowercase_input[start]
    if c.isalpha():
        c = c.upper()
    else:
        return None
    return ''.join([lowercase_input[:start], c, lowercase_input[start+1:]])

@dataclass
class Node:
    start: int
    text: str

def casemod(lowercase_input):
    input_len = len(lowercase_input)
    if input_len == 0:
        return ['']

    last_pos = input_len-1
    nodes = [Node(start = -1, text = lowercase_input)]
    result = []
    while len(nodes) > 0:
        node = nodes.pop()
        if node.start == last_pos:
            result.append(node.text)
        else:
            start = node.start+1
            cur_text = node.text
            mod_str = modstring(cur_text, start)

            nodes.append(Node(start = start, text = cur_text))
            if mod_str is not None:
                nodes.append(Node(start = start, text = mod_str))

    return result
    

def _main():
    if len(argv) == 2:
        for x in casemod(argv[1]):
            print(x)
    else:
        print("pass a string as an argument")
        exit(1)

if __name__ == '__main__':
    _main()

