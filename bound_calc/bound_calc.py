from typing import Dict, List

class Value:
    value = None
    def __init__(self, value):
        self.value = value

    def update(self, data, updates):
        return False

class Immediate:
    value = None
    def __init__(self, value):
        self.value = value

    def update(self, data, updates):
        return False


def get_value(a, data: Dict):
    return data[a].value if type(a) is str else a.value

def check_depends(a, updates: List) -> bool:
    if type(a) is str:
        if updates.count(a) > 0:
            return True
    return False

class Sum:
    value = None
    a = None
    b = None
    # either name or Immediate
    def __init__(self, a, b):
        self.a = a
        self.b = b
    
    def calc(self, data: Dict):
        a = get_value(self.a, data)
        b = get_value(self.b, data)
        if (a is None) or (b is None):
            self.value = None
        else:
            self.value = a+b

    # True if changed
    def update(self, data: Dict, updates: List) -> bool:
        if check_depends(self.a, updates) or check_depends(self.b, updates):
            self.calc(data)
            return True
        return False
        

def tick(data, updates, next_updates) -> bool:
    print("updates = %s" % updates)
    for i in data.items():
        changed = i[1].update(data, updates)
        if changed:
            next_updates.append(i[0])

    updates.clear()
    updates.extend(next_updates)
    next_updates.clear()
    
    return len(updates) > 0


def process():
    # data in the system
    bound_data = {'a': Value(1), 'b': Sum('a', Immediate(3)), 'c': Sum('b', 'a')}

    # this tick updates
    updates = ['a', 'b', 'c']

    # updates for the next tick
    next_updates = []

    while tick(bound_data, updates, next_updates):
        pass

process()