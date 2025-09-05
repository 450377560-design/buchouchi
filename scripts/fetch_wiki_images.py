#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 assets/recipes/seed_names.txt 与 assets/recipes/seed_more.json 读取菜名，
调用维基百科 API (zh→en) 抓取配图，保存到 assets/images/，
并生成/更新 assets/recipes/images.json (菜名 -> 本地 assets 路径)。
策略：
  1) REST Summary
  2) REST Media List
  3) Action API (pageimages)
  4) 语言回退 zh -> en
  5) 常见菜名英文别名映射
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

UA = {"User-Agent": "buchouchi-image-fetcher/1.0 (GitHub Actions)"}

ALT_TITLES = {
    "宫保鸡丁": ["宫保雞丁", "Kung Pao chicken"],
    "麻婆豆腐": ["Mapo tofu"],
    "鱼香肉丝": ["魚香肉絲", "Yuxiang shredded pork"],
    "回锅肉":   ["回鍋肉", "Twice-cooked pork"],
    "水煮鱼":   ["水煮魚", "Shuizhu fish"],
    "白切鸡":   ["白切雞", "White cut chicken", "Bai qie ji"],
    "豉汁蒸排骨": ["Steamed pork ribs with black bean sauce"],
    "清蒸鲈鱼": ["清蒸鱸魚", "Steamed sea bass", "Steamed perch"],
    "干炒牛河": ["干炒牛河粉", "Beef chow fun"],
    "叉烧":     ["叉燒", "Char siu"],
    "松鼠桂鱼": ["Squirrel fish"],
    "红烧狮子头": ["Lion's head (food)"],
    "叫花鸡":   ["Beggar's chicken"],
    "酱鸭":     ["Soy-braised duck"],
    "西湖醋鱼": ["West Lake fish in vinegar gravy"],
    "东坡肉":   ["Dongpo pork"],
    "龙井虾仁": ["Longjing shrimp"],
    "油焖春笋": ["Braised spring bamboo shoots"],
    "佛跳墙":   ["Buddha Jumps Over the Wall"],
    "海蛎煎":   ["Oyster omelette"],
    "卤面":     ["Lǔ noodles", "Lumen (noodles)"],
    "荔枝肉":   ["Litchi pork"],
    "剁椒鱼头": ["Steamed fish head with diced hot red peppers"],
    "毛氏红烧肉": ["Mao shi hongshao rou", "Hunan braised pork"],
    "辣椒炒肉": ["La Jiao Chao Rou", "Stir-fried pork with chili"],
    "口味虾":   ["Spicy crayfish", "Mala crayfish"],
    "臭鳜鱼":   ["臭桂魚", "Stinky mandarin fish"],
    "笋干烧肉": ["Braised pork with dried bamboo shoots"],
    "徽州一品锅": ["Hui-style yipin pot"],
    "毛豆腐":   ["Fermented tofu (Mao tofu)"],
    "葱爆海参": ["Stir-fried sea cucumber with scallion"],
    "九转大肠": ["Jiu zhuan da chang", "Sweet and sour pork intestine"],
    "糖醋鲤鱼": ["Sweet and sour carp"],
    "四喜丸子": ["Four-Joy Meatballs", "Lion's head (food)"],
}

def slugify(s: str) -> str:
    s = re.sub(r"\s+", "_", s.strip())
    s = re.sub(r"[^\w\u4e00-\u9fff\-_.]", "", s, flags=re.UNICODE)
    return s or "img"

def ext_from_url(u: str) -> str:
    m = re.search(r"\.(jpg|jpeg|png|webp|gif)(?:\?|$)", u, re.I)
    return f".{m.group(1).lower()}" if m else ".jpg"

def download(url: str, path: str):
    r = requests.get(url, timeout=20, stream=True, headers=UA)
    r.raise_for_status()
    with open(path, "wb") as f:
        for chunk in r.iter_content(1024 * 32):
            if chunk:
                f.write(chunk)

def api_rest_summary(title: str, lang: str) -> dict | None:
    url = f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{quote(title)}"
    try:
        r = requests.get(url, timeout=10, headers=UA)
        print(f"  [REST summary {lang}] {title} -> {r.status_code}")
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        print(f"  [REST summary {lang} err] {e}")
    return None

def api_rest_media_list(title: str, lang: str) -> dict | None:
    url = f"https://{lang}.wikipedia.org/api/rest_v1/page/media-list/{quote(title)}"
    try:
        r = requests.get(url, timeout=10, headers=UA)
        print(f"  [REST media   {lang}] {title} -> {r.status_code}")
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        print(f"  [REST media {lang} err] {e}")
    return None

def api_action_pageimages(title: str, lang: str) -> dict | None:
    url = (
        f"https://{lang}.wikipedia.org/w/api.php"
        f"?action=query&prop=pageimages|info&inprop=url&format=json"
        f"&pithumbsize=1200&piprop=original|thumbnail&redirects=1&titles={quote(title)}"
    )
    try:
        r = requests.get(url, timeout=10, headers=UA)
        print(f"  [Action API   {lang}] {title} -> {r.status_code}")
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        print(f"  [Action API {lang} err] {e}")
    return None

def from_summary(j: dict) -> str | None:
    for k in ("originalimage", "thumbnail"):
        v = j.get(k, {})
        if isinstance(v, dict):
            u = v.get("source")
            if isinstance(u, str) and u:
                return u
    return None

def from_media_list(j: dict) -> str | None:
    items = j.get("items", [])
    for it in items:
        if it.get("type") == "image":
            # 尝试 original 再 thumbnail
            src = it.get("srcset") or it.get("sources") or []
            # srcset 是列表，取最后一项（最大）
            if isinstance(src, list) and src:
                last = src[-1]
                if isinstance(last, dict) and isinstance(last.get("src"), str):
                    return last["src"]
            # 兜底
            if isinstance(it.get("src"), str):
                return it["src"]
    return None

def from_action_pageimages(j: dict) -> str | None:
    q = j.get("query", {})
    pages = q.get("pages", {})
    for _, page in pages.items():
        if "original" in page and isinstance(page["original"].get("source"), str):
            return page["original"]["source"]
        if "thumbnail" in page and isinstance(page["thumbnail"].get("source"), str):
            return page["thumbnail"]["source"]
    return None

def get_image_url_by_title(title: str, lang: str) -> str | None:
    # 1) REST Summary
    j = api_rest_summary(title, lang)
    url = from_summary(j) if j else None
    if url: return url
    # 2) REST Media List
    j = api_rest_media_list(title, lang)
    url = from_media_list(j) if j else None
    if url: return url
    # 3) Action API
    j = api_action_pageimages(title, lang)
    url = from_action_pageimages(j) if j else None
    return url

def get_best_image_url(name: str) -> str | None:
    # zh 直接尝试
    tries = [(name, "zh")]
    # zh 额外尝试（带“（菜肴）”）
    tries += [(f"{name}（菜肴）", "zh"), (f"{name}(菜肴)", "zh")]
    # en 回退（包含别名）
    for alt in ALT_TITLES.get(name, []):
        tries.append((alt, "en"))
    tries.append((name, "en"))

    for title, lang in tries:
        url = get_image_url_by_title(title, lang)
        if url:
            print(f"  -> FOUND [{lang}] {title} : {url}")
            return url
    print("  -> not found via all strategies")
    return None

def load_names() -> set[str]:
    names: set[str] = set()
    if os.path.exists(NAMES_FILE):
        with open(NAMES_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    names.add(line)
    if os.path.exists(SEED_MORE):
        try:
            arr = json.load(open(SEED_MORE, "r", encoding="utf-8"))
            for item in arr:
                nm = str(item.get("name", "")).strip()
                if nm: names.add(nm)
        except Exception:
            pass
    return names

def main():
    names = sorted(load_names())
    if not names:
        print("No names found; nothing to do.")
        return 0

    # 读取现有映射
    mapping = {}
    if os.path.exists(MAP_FILE):
        try:
            mapping = json.load(open(MAP_FILE, "r", encoding="utf-8"))
        except Exception:
            mapping = {}

    changed = False

    for name in names:
        print(f"[dish] {name}")
        # 已有且文件存在：跳过
        if name in mapping and os.path.exists(os.path.join(ROOT, mapping[name])):
            print(f"  -> skip existing: {mapping[name]}")
            continue

        img_url = get_best_image_url(name)
        if not img_url:
            print(f"  [warn] no image: {name}")
            continue

        ext = ext_from_url(img_url)
        fname = slugify(name) + ext
        out_path = os.path.join(IMG_DIR, fname)
        rel_path = f"assets/images/{fname}"

        try:
            print(f"  [download] {img_url} -> {rel_path}")
            download(img_url, out_path)
            mapping[name] = rel_path
            changed = True
            time.sleep(0.4)
        except Exception as e:
            print(f"  [err] download failed: {e}")

    # 保存映射（即使无改变也保持存在）
    with open(MAP_FILE, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)
    print(f"[done] mapping saved: {MAP_FILE}, size={len(mapping)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
