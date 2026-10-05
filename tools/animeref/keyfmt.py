"""Rewrite a key-pose JSON (game/assets/authored/keys/*.json) in the compact house layout.

    python keyfmt.py <file.json> [--set f:limb.side.field=[x,y,z] ...]

--set edits one field of the key at rules frame f, e.g. 11:arms.right.blade=[0.1,-0.55,1].
"""
import json
import sys


def dump(d: dict) -> str:
    c = lambda v: json.dumps(v, separators=(", ", ": "))
    out = ["{"]
    head = [k for k in d if k != "keys"]
    for k in head:
        out.append(f'  "{k}": {c(d[k])},')
    out.append('  "keys": [')
    for i, key in enumerate(d["keys"]):
        out.append("    {")
        lines = [f'      "f": {key["f"]}, "note": {c(key.get("note", ""))}']
        lines.append(f'      "hips": {c(key["hips"])}')
        lines.append("      " + ", ".join(f'"{s}": {c(key[s])}' for s in ("spine", "chest", "upper_chest", "neck", "head") if s in key))
        for group in ("legs", "arms"):
            if group in key:
                inner = ",\n".join(f'        "{side}": {c(v)}' for side, v in key[group].items())
                lines.append(f'      "{group}": {{\n{inner}\n      }}')
        out.append(",\n".join(lines))
        out.append("    }" + ("," if i < len(d["keys"]) - 1 else ""))
    out.append("  ]")
    out.append("}")
    return "\n".join(out) + "\n"


def main() -> None:
    path = sys.argv[1]
    d = json.load(open(path, encoding="utf-8"))
    args = sys.argv[2:]
    for i, a in enumerate(args):
        if a != "--set":
            continue
        spec = args[i + 1]
        f, rest = spec.split(":", 1)
        field, value = rest.split("=", 1)
        key = next(k for k in d["keys"] if k["f"] == int(f))
        node = key
        parts = field.split(".")
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node[parts[-1]] = json.loads(value)
    open(path, "w", encoding="utf-8", newline="\n").write(dump(d))


if __name__ == "__main__":
    main()
