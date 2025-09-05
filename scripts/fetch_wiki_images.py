#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
读取 assets/recipes/seed_names.txt 与 assets/recipes/seed_more.json，
从 zh→en Wikipedia Summary API 解析缩略图/原图，下载到 assets/images/，
并生成/更新 assets/recipes/images.json 作为 name->asset 路径映射。
"""
import os, re, json, sys, time
from urllib.parse import quote
import requests

ROOT = os.path.dirname(os.path.dirname(__file__))
ASSETS = os.path.join(ROOT, "assets")
IMG_DIR = os.path.join(ASSETS, "images")
MAP_FILE = os.path.join(ASSETS, "recipes", "images.json")
NAMES_FILE = os.path.join(ASSETS, "recipes", "seed_names.txt")
SEED_MORE = os.path.join(ASSETS, "recipes", "seed_more.json")

os.makedirs(IMG_DIR, exist_ok=True)

def slugify(s: str) -> str:
    # 保留中英文、数字，把其他字符替换为下划线
    s = re.sub(r"\s+", "_", s.strip())
    s = re.sub(r"[^\w\u4e00-\u9fff\-_.]", "", s, flags=re.UNICODE)
    return s or "img"

def api_summary(title: str, lang: str) -> dict | None:
    url = f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{quote(title)}"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
          return r.json()
    except Exception:
        pass
    return None

def pick_image_url(j: dict) -> str | None:
    for k in ("originalimage", "thumbnail"):
        v = j.get(k, {})
        if isinstance(v, dict):
            u = v.get("source")
            if isinstance(u, str) and u:
                return u
    return None

def ext_from_url(u: str) -> str:
    m = re.search(r"\.(jpg|jpeg|png|webp|gif)(?:\?|$)", u, re.I)
    return f".{m.group(1).lower()}" if m else ".jpg"

def download(url: str, path: str):
    r = requests.get(url, timeout=20, stream=True)
    r.raise_for_status()
    with open(path, "wb") as f:
        for chunk in r.iter_content(1024 * 32):
            if chunk:
                f.write(chunk)

def load_names() -> set[str]:
    names = set()
    # 1) seed_names.txt
    if os.path.exists(NAMES_FILE):
        with open(NAMES_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    names.add(line)
    # 2) seed_more.json
    if os.path.exists(SEED_MORE):
        try:
            arr = json.load(open(SEED_MORE, "r", encoding="utf-8"))
            for item in arr:
                nm = str(item.get("name", "")).strip()
                if nm:
                    names.add(nm)
        except Exception:
            pass
    return names

def main():
    names = sorted(load_names())
    if not names:
        print("No names found; nothing to do.")
        return 0

    # 现有映射
    mapping = {}
    if os.path.exists(MAP_FILE):
        try:
            mapping = json.load(open(MAP_FILE, "r", encoding="utf-8"))
        except Exception:
            mapping = {}

    changed = False

    for name in names:
        if name in mapping and os.path.exists(os.path.join(ROOT, mapping[name])):
            print(f"[skip] {name} -> {mapping[name]}")
            continue

        # zh -> en
        img_url = None
        j = api_summary(name, "zh")
        if j:
            img_url = pick_image_url(j)
        if not img_url:
            j = api_summary(name, "en")
            if j:
                img_url = pick_image_url(j)
        if not img_url:
            print(f"[warn] no image: {name}")
            continue

        ext = ext_from_url(img_url)
        fname = slugify(name) + ext
        out_path = os.path.join(IMG_DIR, fname)
        rel_path = f"assets/images/{fname}"

        try:
            print(f"[get] {name} <- {img_url}")
            download(img_url, out_path)
            mapping[name] = rel_path
            changed = True
            time.sleep(0.4)  # 轻微限速，避免触发风控
        except Exception as e:
            print(f"[err] {name}: {e}")

    if changed:
        with open(MAP_FILE, "w", encoding="utf-8") as f:
            json.dump(mapping, f, ensure_ascii=False, indent=2)
        print(f"[done] mapping saved: {MAP_FILE}")
    else:
        print("[noop] no changes")
    return 0

if __name__ == "__main__":
    sys.exit(main())
