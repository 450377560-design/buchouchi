#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os, json, csv, sys

ROOT = os.path.dirname(os.path.dirname(__file__))
SEED = os.path.join(ROOT, "assets", "recipes", "seed_more.json")
TSV  = os.path.join(ROOT, "assets", "recipes", "instructions", "instructions.tsv")

CUISINE_MAP = {
    "川菜":"chuancai","粤菜":"yuecai","苏菜":"sucai","浙菜":"zhecai",
    "闽菜":"mincai","湘菜":"xiangcai","徽菜":"huicai","鲁菜":"lucai",
    "自定义":"custom","custom":"custom","chuancai":"chuancai","yuecai":"yuecai",
    "sucai":"sucai","zhecai":"zhecai","mincai":"mincai","xiangcai":"xiangcai",
    "huicai":"huicai","lucai":"lucai",
}

def load_seed():
    if not os.path.exists(SEED):
        print("seed_more.json not found, creating new one.")
        return []
    with open(SEED, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
            return data if isinstance(data, list) else []
        except Exception:
            return []

def save_seed(arr):
    with open(SEED, "w", encoding="utf-8") as f:
        json.dump(arr, f, ensure_ascii=False, indent=2)

def main():
    seed = load_seed()
    by_key = {(it.get("name",""), it.get("cuisine","")): it for it in seed}

    if not os.path.exists(TSV):
        print("instructions.tsv not found.")
        return 0

    updated, added = 0, 0
    with open(TSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            name = (row.get("name") or "").strip()
            cuisine_in = (row.get("cuisine") or "").strip()
            instr = (row.get("instructions") or "").replace("\\n", "\n").strip()
            if not name or not instr:
                continue
            key = CUISINE_MAP.get(cuisine_in, cuisine_in or "custom")
            obj = by_key.get((name, key))
            if obj:
                obj["instructions"] = instr
                updated += 1
            else:
                seed.append({"name": name, "cuisine": key, "instructions": instr})
                by_key[(name, key)] = seed[-1]
                added += 1

    save_seed(seed)
    print(f"done. updated={updated}, added={added}, total={len(seed)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
