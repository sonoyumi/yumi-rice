#!/usr/bin/env python3
"""Регистрирует отдельное бесплатное устройство Cloudflare WARP для прокси yumi-music (как wgcf).
Отдельное — чтобы не делить ключ с VPN «VPN WARP»: один ключ из двух туннелей сразу перебивает друг друга.
Пишет рядом warp.conf и warp-account.json (0600). Повторный запуск ничего не делает, если файлы есть."""
import base64, json, os, sys, time, urllib.request
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives import serialization

D = os.path.dirname(os.path.abspath(__file__))
CONF, ACC = os.path.join(D, "warp.conf"), os.path.join(D, "warp-account.json")
if os.path.exists(CONF) and "--force" not in sys.argv:
    print("уже зарегистрировано"); sys.exit(0)

priv = X25519PrivateKey.generate()
raw = lambda k: base64.b64encode(k).decode()
priv_b64 = raw(priv.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()))
pub_b64 = raw(priv.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw))
body = json.dumps({"install_id": "", "fcm_token": "", "key": pub_b64, "type": "Android", "locale": "en_US",
                   "tos": time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())}).encode()
req = urllib.request.Request("https://api.cloudflareclient.com/v0a2158/reg", data=body, method="POST",
                             headers={"Content-Type": "application/json; charset=UTF-8", "User-Agent": "okhttp/3.12.1",
                                      "CF-Client-Version": "a-6.30-3596"})
with urllib.request.urlopen(req, timeout=20) as r:
    d = json.load(r)
cfg = d["config"]
peer = cfg["peers"][0]
addr = cfg["interface"]["addresses"]
host = peer["endpoint"]["v4"].rsplit(":", 1)[0] or "162.159.192.6"
conf = f"""[Interface]
PrivateKey = {priv_b64}
Address = {addr['v4']}/32, {addr['v6']}/128
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = {peer['public_key']}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = {host}:2408
PersistentKeepalive = 25
"""
old = os.umask(0o077)
with open(CONF, "w") as f:
    f.write(conf)
with open(ACC, "w") as f:
    json.dump({"id": d["id"], "token": d["token"]}, f)
os.umask(old)
print("зарегистрировано:", d["id"][:8] + "…", "endpoint", host)
