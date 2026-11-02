# Mystree: uploads icons/out/*.png to Roblox (Open Cloud Assets API) as Decals owned by the group, and
# records key -> decal asset id in icons/uploaded.json. Already-uploaded keys are skipped.
# The API key comes from the ROBLOX_KEY environment variable (never printed).
import json, os, sys, time, uuid, urllib.request, urllib.error

GROUP = 35685335
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
DONE = os.path.join(HERE, "uploaded.json")
KEY = os.environ.get("ROBLOX_KEY", "")
if not KEY:
    sys.exit("ROBLOX_KEY not set")


def call(url, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, method=method or ("POST" if data else "GET"))
    req.add_header("x-api-key", KEY)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode()[:300]}


def upload(key, path):
    boundary = uuid.uuid4().hex
    meta = {
        "assetType": "Decal",
        "displayName": "Mystree Icon " + key,
        "description": "Mystree UI icon",
        "creationContext": {"creator": {"groupId": GROUP}},
    }
    body = b""
    body += ("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n" % boundary).encode()
    body += json.dumps(meta).encode() + b"\r\n"
    body += ("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s.png\"\r\nContent-Type: image/png\r\n\r\n" % (boundary, key)).encode()
    body += open(path, "rb").read() + b"\r\n"
    body += ("--%s--\r\n" % boundary).encode()
    op = call("https://apis.roblox.com/assets/v1/assets", body, {"Content-Type": "multipart/form-data; boundary=" + boundary})
    if "error" in op:
        return None, op
    name = op.get("path") or op.get("operationId")
    for _ in range(40):
        if op.get("done") and op.get("response"):
            return op["response"].get("assetId"), None
        time.sleep(1.5)
        op = call("https://apis.roblox.com/assets/v1/" + name if not name.startswith("http") else name)
        if "error" in op:
            return None, op
    return None, {"error": "timeout"}


def main():
    done = json.load(open(DONE)) if os.path.exists(DONE) else {}
    keys = sorted(f[:-4] for f in os.listdir(OUT) if f.endswith(".png"))
    if len(sys.argv) > 1:
        keys = [k for k in keys if k in sys.argv[1:]]
    for key in keys:
        if key in done and len(sys.argv) == 1:
            continue
        asset, err = upload(key, os.path.join(OUT, key + ".png"))
        if asset:
            done[key] = asset
            json.dump(done, open(DONE, "w"), indent=1, sort_keys=True)
            print("ok", key, asset)
        else:
            print("FAIL", key, err)
            if err and err.get("error") == 429:
                time.sleep(20)
        time.sleep(0.8)
    print(len(done), "uploaded in total")


main()
