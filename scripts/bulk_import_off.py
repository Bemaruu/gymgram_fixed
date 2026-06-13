"""Bulk import Open Food Facts a custom_foods.

Descarga productos por país desde OFF v1 search API, filtra por calidad
(nutrition_grades, completeness, kcal presente), mapea a custom_foods y
genera archivos SQL listos para aplicar vía MCP execute_sql.

Uso:
    python scripts/bulk_import_off.py <country_iso> <country_off_name> <pages> <out.sql>

Ejemplo:
    python scripts/bulk_import_off.py CL chile 5 scripts/off_cl.sql
"""
import json
import re
import sys
import time
import urllib.request

UA = "GymGramBulkImport/1.0 (support@gymgram.fit)"


def normalize(s: str) -> str:
    s = s.lower()
    tr = str.maketrans("áàäâéèëêíìïîóòöôúùüû", "aaaaeeeeiiiioooouuuu")
    s = s.translate(tr)
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def guess_category(name: str, brand: str | None) -> str:
    s = f"{name.lower()} {(brand or '').lower()}"
    rules = [
        (r"\b(monster|red bull|powerade|gatorade|coca|sprite|fanta|pepsi|agua|cerveza|vino|jugo|jugo|nectar|leche|cafe|coffee|te |nescafe|smoothie|bebida|kombucha|tonica|inca kola|jugo)\b", "Bebidas"),
        (r"\b(yogur|yogurt|queso|crema|mantequilla|manjar|arequipe|kefir)\b", "Lacteos"),
        (r"\b(cereal|corn flakes|chocapic|nesquik cereal|quaker|frosted|granola)\b", "Cereales"),
        (r"\b(pan|baguette|hallulla|marraqueta|tortilla|fideos|pasta|arroz|avena|quinoa|harina|tostada|biscot|cracker)\b", "Cereales"),
        (r"\b(snickers|kitkat|twix|chocolate|chocman|sublime|chips|papas fritas|galleta|barra|alfajor|bombon|brownie|nuget|wafer|cookie|donut|nutella|gomita|caramel)\b", "Snacks"),
        (r"\b(pollo|chicken|carne|res|beef|cerdo|pork|atun|tuna|salmon|huevo|jamon|pavo|chorizo|tocino|sardinas|whey|proteina|hamburguesa|tofu|seitan|tempeh|salchicha|embutido)\b", "Proteinas"),
        (r"\b(lentejas|garbanzos|porotos|frijoles|arvejas|habas|soja|edamame|legumbre|alubia)\b", "Legumbres"),
        (r"\b(tomate|lechuga|cebolla|zanahoria|brocoli|coliflor|espinaca|papa|camote|zapallo|pimenton|berenjena|verdura|salsa de tomate)\b", "Verduras"),
        (r"\b(platano|banana|manzana|naranja|pera|uva|sandia|melon|frutilla|fresa|kiwi|durazno|pina|piña|palta|aguacate|frambuesa|arandano|mango|papaya|fruta)\b", "Frutas"),
        (r"\b(aceite|mantequilla mani|nueces|almendras|chia|linaza|mani|peanut|nut|aceituna)\b", "Grasas"),
    ]
    for pat, cat in rules:
        if re.search(pat, s):
            return cat
    return "Snacks"


COUNTRY_MAP_TO_ISO = {
    "chile": "CL", "argentina": "AR", "mexico": "MX",
    "colombia": "CO", "peru": "PE", "spain": "ES",
    "united-states": "US", "brazil": "BR", "brasil": "BR",
    "uruguay": "UY", "ecuador": "EC", "venezuela": "VE",
}


def country_relevance_from_tags(tags: list[str]) -> list[str]:
    out: list[str] = []
    for tag in tags:
        key = tag.split(":")[-1].lower()
        iso = COUNTRY_MAP_TO_ISO.get(key)
        if iso and iso not in out:
            out.append(iso)
        if len(out) >= 6:
            break
    if not out:
        out = ["GLOBAL"]
    return out


def sql_str(s: str | None) -> str:
    if s is None:
        return "NULL"
    s = s.replace("'", "''")
    return f"'{s}'"


def sql_num(v) -> str:
    if v is None:
        return "NULL"
    try:
        return f"{float(v):.2f}"
    except (TypeError, ValueError):
        return "NULL"


def sql_arr(arr: list[str]) -> str:
    if not arr:
        return "ARRAY[]::text[]"
    safe = ",".join(f"'{x}'" for x in arr)
    return f"ARRAY[{safe}]::text[]"


def fetch_page(country_off_name: str, page: int, page_size: int = 50) -> dict:
    url = (
        "https://world.openfoodfacts.org/cgi/search.pl"
        f"?action=process&tagtype_0=countries&tag_contains_0=contains"
        f"&tag_0={country_off_name}"
        f"&page_size={page_size}&page={page}&json=1"
        "&fields=code,product_name,brands,nutriments,countries_tags,completeness,nutrition_grades,image_small_url"
    )
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def map_row(p: dict, default_iso: str) -> dict | None:
    name = (p.get("product_name") or "").strip()
    if not name or len(name) < 2:
        return None
    nut = p.get("nutriments") or {}
    kcal = nut.get("energy-kcal_100g")
    if kcal is None:
        # Algunos productos solo tienen kJ
        kj = nut.get("energy_100g") or nut.get("energy-kj_100g")
        if kj:
            try:
                kcal = float(kj) / 4.184
            except (TypeError, ValueError):
                kcal = None
    if not kcal or kcal <= 0:
        return None
    try:
        kcal_f = float(kcal)
    except (TypeError, ValueError):
        return None
    # filtros calidad
    completeness = p.get("completeness", 0)
    try:
        completeness = float(completeness)
    except (TypeError, ValueError):
        completeness = 0
    if completeness < 0.5:
        return None

    brand = (p.get("brands") or "").split(",")[0].strip() or None
    display = f"{name} ({brand})" if brand else name
    if len(display) > 120:
        display = display[:120]

    # OFF guarda sodium_100g en GRAMOS según spec, pero algunos productos vienen
    # mal cargados con el valor ya en mg. Cap defensivo a 5000 mg/100g
    # (≈5 g sal/100g, máximo realista). Si excede, descartamos.
    sodium_g = nut.get("sodium_100g")
    sodium_mg = None
    if sodium_g is not None:
        try:
            v = float(sodium_g) * 1000
            if 0 <= v <= 5000:
                sodium_mg = round(v, 2)
        except (TypeError, ValueError):
            sodium_mg = None

    # Mismos caps para sugar y sat_fat (>100 g por 100g es imposible)
    sugar_v = nut.get("sugars_100g")
    sat_fat_v = nut.get("saturated-fat_100g")
    try:
        sugar_v = float(sugar_v) if sugar_v is not None and 0 <= float(sugar_v) <= 100 else None
    except (TypeError, ValueError):
        sugar_v = None
    try:
        sat_fat_v = float(sat_fat_v) if sat_fat_v is not None and 0 <= float(sat_fat_v) <= 100 else None
    except (TypeError, ValueError):
        sat_fat_v = None

    tags = p.get("countries_tags") or []
    relevance = country_relevance_from_tags(tags)
    if default_iso not in relevance and "GLOBAL" not in relevance:
        relevance.append(default_iso)

    return {
        "name": display,
        "name_normalized": normalize(display),
        "category": guess_category(name, brand),
        "serving_grams": 100,
        "serving_description": "100 g",
        "kcal_per_100g": round(kcal_f, 2),
        "protein_per_100g": nut.get("proteins_100g") or 0,
        "carbs_per_100g": nut.get("carbohydrates_100g") or 0,
        "fat_per_100g": nut.get("fat_100g") or 0,
        "fiber_per_100g": nut.get("fiber_100g") or 0,
        "sodium_mg_per_100g": sodium_mg,
        "sugar_per_100g": sugar_v,
        "sat_fat_per_100g": sat_fat_v,
        "source": "OFF_BULK",
        "off_product_id": str(p.get("code") or "").strip() or None,
        "image_url": p.get("image_small_url"),
        "brand": brand,
        "country_relevance": relevance,
        "ai_exclude_from_plan": True,
    }


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    iso = sys.argv[1].upper()
    off_name = sys.argv[2]
    pages = int(sys.argv[3])
    out_path = sys.argv[4]

    rows: list[dict] = []
    seen_norm: set[str] = set()
    seen_off_id: set[str] = set()
    for page in range(1, pages + 1):
        print(f"[{iso}] page {page}/{pages}...", file=sys.stderr)
        try:
            body = fetch_page(off_name, page)
        except Exception as e:
            print(f"  ERROR page {page}: {e}", file=sys.stderr)
            time.sleep(2)
            continue
        products = body.get("products") or []
        if not products:
            print(f"  no products on page {page}, stopping.", file=sys.stderr)
            break
        for p in products:
            row = map_row(p, iso)
            if not row:
                continue
            if row["name_normalized"] in seen_norm:
                continue
            if row["off_product_id"] and row["off_product_id"] in seen_off_id:
                continue
            seen_norm.add(row["name_normalized"])
            if row["off_product_id"]:
                seen_off_id.add(row["off_product_id"])
            rows.append(row)
        time.sleep(0.6)  # politeness OFF API

    print(f"[{iso}] {len(rows)} rows accepted, writing SQL...", file=sys.stderr)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(
            "-- Auto-generated bulk import from Open Food Facts.\n"
            "-- Source: world.openfoodfacts.org/cgi/search.pl\n"
            f"-- Country: {iso} ({off_name}). Rows: {len(rows)}.\n"
            "INSERT INTO public.custom_foods (\n"
            "  name, name_normalized, category, serving_description, serving_grams,\n"
            "  kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g,\n"
            "  sodium_mg_per_100g, sugar_per_100g, sat_fat_per_100g,\n"
            "  source, off_product_id, image_url, brand,\n"
            "  country_relevance, ai_exclude_from_plan\n"
            ") VALUES\n"
        )
        chunks = []
        for r in rows:
            chunks.append(
                "(" + ",".join([
                    sql_str(r["name"]),
                    sql_str(r["name_normalized"]),
                    sql_str(r["category"]),
                    sql_str(r["serving_description"]),
                    sql_num(r["serving_grams"]),
                    sql_num(r["kcal_per_100g"]),
                    sql_num(r["protein_per_100g"]),
                    sql_num(r["carbs_per_100g"]),
                    sql_num(r["fat_per_100g"]),
                    sql_num(r["fiber_per_100g"]),
                    sql_num(r["sodium_mg_per_100g"]),
                    sql_num(r["sugar_per_100g"]),
                    sql_num(r["sat_fat_per_100g"]),
                    sql_str(r["source"]),
                    sql_str(r["off_product_id"]),
                    sql_str(r["image_url"]),
                    sql_str(r["brand"]),
                    sql_arr(r["country_relevance"]),
                    "true" if r["ai_exclude_from_plan"] else "false",
                ]) + ")"
            )
        f.write(",\n".join(chunks))
        f.write("\nON CONFLICT (name_normalized) DO NOTHING;\n")
    print(f"[{iso}] SQL written to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
