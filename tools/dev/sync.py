# Dev helper: 3-way merges local edits (src) with Studio's current copies (tools/dev/pulled,
# POSTed by Studio) against the last synced copy (tools/dev/base). Usage:
#   python3 sync.py merge <rel path>...   -> merges into src, reports conflicts
#   python3 sync.py done <rel path>...    -> after pushing: base = pulled = src
import os, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "src"))
mode, paths = sys.argv[1], sys.argv[2:]
for rel in paths:
    src, base, pulled = (os.path.join(SRC, rel), os.path.join(HERE, "base", rel), os.path.join(HERE, "pulled", rel))
    if mode == "merge":
        if not os.path.exists(base):
            print(rel, "no base: comparing pulled vs src only", "SAME" if open(pulled).read() == open(src).read() else "DIFFERENT")
            continue
        if open(pulled).read() == open(base).read():
            print(rel, "studio unchanged")
            continue
        r = subprocess.run(["git", "merge-file", src, base, pulled])
        print(rel, "merged" if r.returncode == 0 else "CONFLICTS %d" % r.returncode)
    elif mode == "done":
        for d in (base, pulled):
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copyfile(src, d)
        print(rel, "synced")
