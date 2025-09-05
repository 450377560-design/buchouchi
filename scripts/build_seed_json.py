#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
读取 assets/recipes/lists/*.txt （每行一个菜名），
生成 assets/recipes/seed_more.json，字段包含：
  name, cuisine, image_url(空), instructions(默认), ingredients([])
"""
import os, json, glob

ROOT = os.path.dirname(os.path.dirname(__file__))
LIST_DIR = os.path.join(ROOT, "assets", "recipes", "lists")
OUT = os.path.join(ROOT, "assets", "recipes", "seed_more.json")

# 文件名到菜系 key 的映射
MAP = {
  "chuancai.txt": "chuancai",
  "yuecai.txt": "yuecai",
  "sucai.txt": "sucai",
  "zhecai.txt": "zhecai",
  "mincai.txt": "mincai",
  "xiangcai.txt": "xiangcai",
  "huicai.txt": "huicai",
  "lucai.txt": "lucai",
}

def default_steps(name: str) -> str:
    return (
        "1) 准备好食材并完成基础处理；\n"
        "2) 热锅冷油依次下主辅料；\n"
        "3) 调味后根据口感收汁或焖煮；\n"
        f"4) 出锅装盘，即成《{name}》。"
    )

def load_names(path: str):
    names = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            names.append(line)
    return names

def main():
    entries = []
    for txt in sorted(glob.glob(os.path.join(LIST_DIR, "*.txt"))):
        fn = os.path.basename(txt)
        cuisine = MAP.get(fn)
        if not cuisine:
            print(f"[skip] {fn} 未在映射表中")
            continue
        names = load_names(txt)
        for name in names:
            entries.append({
                "name": name,
                "cuisine": cuisine,
                "image_url": "",
                "instructions": default_steps(name),
                "ingredients": []
            })
        print(f"[ok] {fn}: {len(names)} items")
    # 去重（按 name+cuisine）
    seen = set()
    dedup = []
    for e in entries:
        key = (e["name"], e["cuisine"])
        if key in seen: continue
        seen.add(key)
        dedup.append(e)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(dedup, f, ensure_ascii=False, indent=2)
    print(f"[done] write {OUT}, total={len(dedup)}")

if __name__ == "__main__":
    main()
