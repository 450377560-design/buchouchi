#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
聚合抓图脚本：
  1) Wikipedia (zh→en)：REST Summary / Media List / Action API
  2) Bing Image Search API（可选，需设置环境变量 BING_IMAGE_API_KEY）
保存：
  - assets/images/*.jpg|png|webp
  - assets/recipes/images.json        （菜名 -> 本地asset路径）
  - assets/recipes/fetch_report.md    （人读报告）
  - assets/recipes/fetch_report.csv   （明细：name,status,source,lang/title/url,asset_path,error）
特性：
  - 已有映射且文件存在 -> 跳过，不重复下载
  - 日志详细，便于排查
"""

import os, re, json, sys, time, csv
from urllib.parse import quote
import requests

ROOT = os.path.dirname(os.path.dirname(__file__))
ASSETS = os.path.join(ROOT, "assets")
IMG_DIR = os.path.join(ASSETS, "images")
REC_DIR = os.path.join(ASSETS, "recipes")
MAP_FILE = os.path.join(REC_DIR, "images.json")
REPORT_MD = os.path.join(REC_DIR, "fetch_report.md")
REPORT_CSV = os.path.join(REC_DIR, "fetch_report.csv")
NAMES_FILE = os.path.join(REC_DIR, "seed_names.txt")
SEED_MORE = os.path.join(REC_DIR, "seed_more.json")
LISTS_DIR = os.path.join(REC_DIR, "lists")

os.makedirs(IMG_DIR, exist_ok=True)
os.makedirs(REC_DIR, exist_ok=True)

UA = {"User-Agent": "buchouchi-image-fetcher/2.0 (GitHub Actions)"}

# ==== 可选：Bing Image Search API 配置（到仓库 Settings → Secrets → Actions 添加 BING_IMAGE_API_KEY） ====
BING_KEY = os.environ.get("BING_IMAGE_API_KEY", "").strip()
BING_ENDPOINT = "https://api.bing.microsoft.com/v7.0/images/search"
BING_MKT = os.environ.get("BING_MARKET", "zh-CN")
BING_SAFE = os.environ.get("BING_SAFE", "Moderate")  # Off/Moderate/Strict
BING_LICENSE = os.environ.get("BING_LICENSE", "Any") # Any/All/Share/ShareCommercially/Modify/ModifyCommercially

# 常见菜名的英文别名映射（提高wiki命中率）
ALT_TITLES = {
    "宫保鸡丁": ["宫保雞丁", "Kung Pao chicken"],
    "麻婆豆腐": ["Mapo tofu"],
    "鱼香肉丝": ["魚香肉絲", "Yuxiang shredded pork"],
    "回锅肉":   ["回鍋肉", "Twice-cooked pork"],
    "水煮鱼":   ["水煮魚", "Shuizhu fish"],
    "白切鸡":   ["白切雞", "White cut chicken", "Bai qie ji"],
    "豉汁蒸排骨": ["Steamed pork ribs with black bean sauce"],
    "清蒸鲈鱼": ["清蒸鱸魚", "Steamed sea bass", "Steamed perch"],
    "干炒牛河": ["Beef chow fun"],
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
    "毛氏红烧肉": ["Hunan braised pork"],
    "辣椒炒肉": ["Stir-fried pork with chili"],
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
    r = requests.get(url, timeout=25, stream=True, headers=UA)
    r.raise_for_status()
    with open(path, "wb") as f:
        for chunk in r.iter_content(1024 * 64):
            if chunk:
                f.write(chunk)

# -------- Wikipedia APIs ----------
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
            srcset = it.get("srcset") or it.get("sources") or []
            if isinstance(srcset, list) and srcset:
                last = srcset[-1]
                if isinstance(last, dict) and isinstance(last.get("src"), str):
                    return last["src"]
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

def get_image_from_wiki(name: str):
    """尝试从 Wikipedia 获取，返回 (url, 'wiki', meta_str) 或 (None, None, None)"""
    tries = [(name, "zh"), (f"{name}（菜肴）", "zh"), (f"{name}(菜肴)", "zh")]
    for alt in ALT_TITLES.get(name, []):
        tries.append((alt, "en"))
    tries.append((name, "en"))

    for title, lang in tries:
        # summary
        j = api_rest_summary(title, lang)
        url = from_summary(j) if j else None
        if url:
            print(f"  -> FOUND [{lang}] {title} : {url}")
            return url, "wiki", f"{lang}:{title}"
        # media list
        j = api_rest_media_list(title, lang)
        url = from_media_list(j) if j else None
        if url:
            print(f"  -> FOUND [{lang}] {title} : {url}")
            return url, "wiki", f"{lang}:{title}"
        # action api
        j = api_action_pageimages(title, lang)
        url = from_action_pageimages(j) if j else None
        if url:
            print(f"  -> FOUND [{lang}] {title} : {url}")
            return url, "wiki", f"{lang}:{title}"
    print("  -> not found via Wikipedia")
    return None, None, None

# -------- Bing Image Search ----------
def get_image_from_bing(name: str):
    """使用 Bing Image Search API。需要 BING_IMAGE_API_KEY。
    返回 (url, 'bing', query) 或 (None, None, None)
    """
    if not BING_KEY:
        return None, None, None
    headers = {"Ocp-Apim-Subscription-Key": BING_KEY, **UA}
    # 尝试多个查询
    queries = [
        f"{name} 美食",
        f"{name} 菜",
        f"{name} 料理",
        f"{name} dish",
        f"{name} Chinese food",
    ]
    for q in queries:
        try:
            params = {
                "q": q,
                "mkt": BING_MKT,
                "safeSearch": BING_SAFE,
                "imageType": "Photo",
                "count": 30,
                "license": BING_LICENSE,
            }
            r = requests.get(BING_ENDPOINT, headers=headers, params=params, timeout=10)
            print(f"  [Bing] {q} -> {r.status_code}")
            if r.status_code != 200:
                continue
            data = r.json()
            values = data.get("value", [])
            # 选择分辨率较高且 url 可用的
            best = None
            best_score = -1
            for v in values:
                url = v.get("contentUrl") or v.get("hostPageUrl")
                if not isinstance(url, str) or not url:
                    continue
                width = v.get("width") or 0
                height = v.get("height") or 0
                score = (width or 0) * (height or 0)
                if score > best_score:
                    best_score = score
                    best = url
            if best:
                print(f"  -> FOUND [bing] {q} : {best}")
                return best, "bing", q
        except Exception as e:
            print(f"  [Bing err] {q} : {e}")
    print("  -> not found via Bing")
    return None, None, None

# -------- 汇总逻辑 ----------
def load_names() -> set[str]:
    names: set[str] = set()
    # seed_names.txt
    if os.path.exists(NAMES_FILE):
        with open(NAMES_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    names.add(line)
    # seed_more.json
    if os.path.exists(SEED_MORE):
        try:
            arr = json.load(open(SEED_MORE, "r", encoding="utf-8"))
            for item in arr:
                nm = str(item.get("name", "")).strip()
                if nm:
                    names.add(nm)
        except Exception:
            pass
    # lists/*.txt
    if os.path.isdir(LISTS_DIR):
        for fn in os.listdir(LISTS_DIR):
            if not fn.endswith(".txt"): continue
            try:
                with open(os.path.join(LISTS_DIR, fn), "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#"):
                            names.add(line)
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

    success_rows = []  # name,status,source,meta/url,asset_path,""
    fail_rows = []     # name,status,source,meta/url,"",error
    changed = False

    for name in names:
        print(f"[dish] {name}")
        # 已有且文件存在 -> 跳过
        if name in mapping and os.path.exists(os.path.join(ROOT, mapping[name])):
            print(f"  -> skip existing: {mapping[name]}")
            success_rows.append([name, "exists", "cache", "", mapping[name], ""])
            continue

        # 先 wiki
        url, source, meta = get_image_from_wiki(name)
        # 再 bing
        if not url:
            url, source, meta = get_image_from_bing(name)

        if not url:
            msg = "no image from wiki/bing"
            print(f"  [warn] {msg}: {name}")
            fail_rows.append([name, "not_found", "none", "", "", msg])
            continue

        ext = ext_from_url(url)
        fname = slugify(name) + ext
        out_path = os.path.join(IMG_DIR, fname)
        rel_path = f"assets/images/{fname}"

        try:
            print(f"  [download] ({source}) {url} -> {rel_path}")
            download(url, out_path)
            mapping[name] = rel_path
            success_rows.append([name, "downloaded", source, meta or url, rel_path, ""])
            changed = True
            time.sleep(0.25)
        except Exception as e:
            msg = f"download_failed: {e}"
            print(f"  [err] {msg}")
            fail_rows.append([name, "download_failed", source or "", meta or url or "", "", str(e)])

    # 写映射
    with open(MAP_FILE, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)
    print(f"[done] mapping saved: {MAP_FILE}, size={len(mapping)}")

    # 写 CSV
    with open(REPORT_CSV, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["name","status","source","meta_or_query","asset_path","error"])
        for r in success_rows + fail_rows:
            w.writerow(r)

    # 写 Markdown 摘要
    with open(REPORT_MD, "w", encoding="utf-8") as f:
        f.write(f"# 抓取报告\n\n")
        f.write(f"- 总计菜名：{len(names)}\n")
        f.write(f"- 成功（含已存在）：{len(success_rows)}\n")
        f.write(f"- 失败：{len(fail_rows)}\n\n")
        if fail_rows:
          f.write("## 未成功的菜名（节选）\n\n")
          for r in fail_rows[:100]:
            f.write(f"- {r[0]} · {r[1]}\n")
          f.write("\n")

    print(f"[report] {REPORT_MD}")
    print(f"[report] {REPORT_CSV}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
