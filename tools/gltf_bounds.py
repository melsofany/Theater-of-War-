import json
from pathlib import Path
import sys

for name in sys.argv[1:]:
    path = Path(name)
    data = json.loads(path.read_text())
    bounds = []
    for accessor in data.get('accessors', []):
        if accessor.get('type') == 'VEC3' and 'min' in accessor and 'max' in accessor:
            bounds.append((accessor['min'], accessor['max']))
    if not bounds:
        print(f'{path}: no bounds')
        continue
    mins = [min(b[0][i] for b in bounds) for i in range(3)]
    maxs = [max(b[1][i] for b in bounds) for i in range(3)]
    size = [maxs[i] - mins[i] for i in range(3)]
    print(f'{path.name}: min={mins} max={maxs} size={size}')
