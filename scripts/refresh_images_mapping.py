#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将 assets/recipes/images.json 中的 .jpg/.jpeg/.png 映射，尽可能替换为同名 .webp（仅当文件存在）。
"""
import os, json, re

ROOT = os.path.dirname(os.path.dirname(__file__))
MAP = os.path.join(ROOT, "assets", "recipes", "images.json")
IMG_DIR = os.path.join(ROOT, "assets", "images")

def main():
    if not os.path.exists(MAP):
        print("images.json not found, skip.")
        return 0
    with open(MAP, "r", encoding="utf-8") as f:
        data = json.load(f)

    changed = False
    for k, v in list(data.items()):
        if not isinstance(v, str):
            continue
        base, ext = os.path.splitext(v)
        if ext.lower() in [".jpg", ".jpeg", ".png"]:
            webp = base + ".webp"
            # 确认 webp 真实存在
            if os.path.exists(os.path.join(ROOT, webp)):
                data[k] = webp
                changed = True

    if changed:
        with open(MAP, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print("images.json updated.")
    else:
        print("No mapping changes.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
