"""Compares the client's WorldMapOverlay.dbc with the hardcoded overlay tables
in the reveal addons. Usage: compare.py <dbc json dir> <addons dir>"""
import json, os, re, sys

dbc_dir, addons = sys.argv[1], sys.argv[2]
ov = json.load(open(os.path.join(dbc_dir, "WorldMapOverlay.json")))
wa = json.load(open(os.path.join(dbc_dir, "WorldMapArea.json")))
s = lambda d, v: d["str"].get(str(v), "")
areas = {r[0]: s(wa, r[3]) for r in wa["rows"]}

client = {}
for r in ov["rows"]:
    _id, mapid, a1, a2, a3, a4, mpx, mpy, tex, w, h, ox, oy = r[:13]
    name = s(ov, tex)
    if not name:
        continue  # no texture (e.g. area-only rows)
    e = "%s:%d:%d:%d:%d" % (name.upper(), w, h, ox, oy)
    if mpx or mpy:
        e += ":%d:%d" % (mpx, mpy)
    client.setdefault(areas.get(mapid, "?%d" % mapid), []).append(e)

def lua_tables(path, start=None):
    text = open(path, encoding="utf-8", errors="replace").read()
    blocks = {}
    # split into the separate table literals by their assignment line
    for m in re.finditer(r'(\w+(?:\.\w+)?)\s*=\s*\{\s*\n(.*?)\n\s*\}', text, re.S):
        body = m.group(2)
        rows = dict((k, re.findall(r'"([^"]+)"', v)) for k, v in re.findall(r'\["(\w+)"\]\s*=\s*\{([^}]*)\}', body))
        if rows:
            blocks.setdefault(m.group(1), []).append((text[:m.start()].count("\n") + 1, rows))
    return blocks

def norm(e):
    p = e.split(":")
    return ":".join([p[0].upper()] + p[1:])

def diff(label, table):
    print("== %s" % label)
    miss_maps = sorted(k for k in client if k not in table)
    extra_maps = sorted(k for k in table if k not in client)
    print("  maps in client, absent from table:", miss_maps)
    print("  maps in table, absent from client:", extra_maps)
    for k in sorted(set(client) & set(table)):
        c = {norm(e) for e in client[k]}
        t = {norm(e) for e in table[k]}
        cn = {e.split(":")[0]: e for e in c}
        tn = {e.split(":")[0]: e for e in t}
        missing = sorted(set(cn) - set(tn))
        extra = sorted(set(tn) - set(cn))
        changed = sorted(n for n in set(cn) & set(tn) if cn[n] != tn[n])
        if missing or extra or changed:
            print("  %-22s client %3d table %3d | missing %s | extra %s | changed %s" % (
                k, len(c), len(t), missing, extra, ["%s %s -> %s" % (n, tn[n][len(n):], cn[n][len(n):]) for n in changed]))

print("client maps with overlays:", len(client), sum(len(v) for v in client.values()), "overlays")
print("client areas:", sorted(client))
for rel in ("ShaguTweaks-extras/mods/worldmap-reveal.lua", "ShaguTweaks-mods/mods/worldmap-reveal.lua",
            "ShaguPlates/env/tables.lua", "ShaguPlates/modules/turtle-wow.lua",
            "pfUI/env/tables.lua", "pfUI/modules/turtle-wow.lua"):
    for name, found in lua_tables(os.path.join(addons, rel)).items():
        for line, rows in found:
            if any(k in client for k in rows):
                diff("%s:%d %s" % (rel, line, name), rows)
json.dump(client, open(os.path.join(dbc_dir, "client-overlays.json"), "w"), indent=0, sort_keys=True)
