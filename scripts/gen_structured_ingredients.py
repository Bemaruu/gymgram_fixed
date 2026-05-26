# -*- coding: utf-8 -*-
"""Genera la migración que puebla ai_meal_templates.ingredientes_estructurados.
Cada ingrediente del texto libre se mapea a un alimento de custom_foods
(name_normalized) con gramos base por rol; luego se calibra el total para que
los kcal derivados se acerquen a los kcal objetivo de la receta."""
import json
import re
import unicodedata


def _strip(s):
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return s.lower().strip()


# name_normalized -> kcal por 100g (catálogo custom_foods)
FOODS = {
    "agua con gas":0,"cafe negro sin azucar":2,"jugo de naranja natural":45,
    "leche de almendras sin azucar":17,"te sin azucar":1,
    "arroz blanco cocido":130,"arroz integral cocido":111,"avena cocida":71,
    "cous cous cocido":112,"fideos tallarines cocidos":156,"galletas de agua":418,
    "harina de trigo":364,"maiz cocido":96,"mote trigo cocido":122,
    "pan de molde blanco":265,"pan hallulla":285,"pan integral":247,
    "pan marraqueta":275,"pan pita integral":266,"pasta cocida espagueti":158,
    "porotos granados cocidos":127,"quinoa cocida":120,"tortilla de maiz":218,
    "tortilla de trigo":312,"tostadas integrales":350,
    "arandano":57,"ciruela":46,"durazno melocoton":39,"frambuesa":52,
    "frutilla fresa":32,"kiwi":61,"limon":29,"mandarina":53,"mango":60,
    "manzana":52,"maracuya granadilla":97,"melon":34,"naranja":47,
    "palta aguacate":160,"papaya":43,"pera":57,"pina anana":50,
    "platano banana":89,"sandia":30,"uva":69,
    "aceite de oliva":884,"aceite vegetal canola":884,"almendras":579,
    "mani tostado sin sal":567,"mantequilla de mani":588,"nueces":654,
    "semillas de chia":486,"semillas de linaza":534,
    "crema de leche":345,"helado de vainilla":207,"leche condensada":321,
    "leche descremada":34,"leche entera":61,"leche semidescremada":46,
    "mantequilla":717,"queso crema":342,"queso fresco cottage":98,
    "queso gauda":356,"queso mantecoso":380,"queso parmesano rallado":431,
    "yogur griego":97,"yogur natural descremado":56,"yogur natural entero":61,
    "arvejas cocidas":81,"edamame":121,"garbanzos cocidos":164,"habas cocidas":110,
    "lentejas cocidas":116,"lupino chocho cocido":116,"porotos blancos cocidos":139,
    "porotos colorados cocidos":127,"porotos negros cocidos":132,
    "porotos pintos cocidos":143,"proteina vegetal en polvo":375,
    "soja soya cocida":173,"soya texturizada hidratada":130,"tempeh":192,
    "tofu firme":144,
    "empanada de pino al horno":295,"empanada de queso":320,"humitas":155,
    "milanesa de carne":255,"milanesa de pollo":230,"pure de papas":113,"pebre":35,
    "albondigas de carne":235,"atun en agua escurrido":116,"camarones cocidos":99,
    "carne asada parrilla":220,"carne de cordero cocida":258,
    "carne de vacuno magra cocida":215,"carne molida cocida":250,
    "chorizo cocido":325,"clara de huevo cocida":52,"congrio cocido":112,
    "filete de cerdo":195,"higado de pollo":167,"higado de vacuno":175,
    "huevo entero cocido":155,"jamon de cerdo":145,"jamon de pavo":107,
    "lomo de cerdo cocido":185,"longaniza cocida":310,"merluza cocida":90,
    "muslo de pollo cocido":185,"pavo a la plancha":170,
    "pechuga de pollo a la plancha":165,"pollo entero cocido":215,
    "pollo rostizado":239,"reineta cocida":105,"salchicha de cerdo":296,
    "salmon cocido":208,"sardinas en aceite":208,"tocino panceta cocida":541,
    "yema de huevo":322,
    "azucar blanca":387,"barra de cereal":370,"ketchup":112,"mayonesa":680,
    "miel":304,"manjar dulce de leche":321,"mermelada de fresa":250,
    "acelga":20,"ajo":149,"apio":16,"betarraga remolacha":44,"brocoli":34,
    "camote batata cocida":86,"cebolla":40,"champinon":22,"choclo maiz dulce":86,
    "coliflor":25,"espinaca":23,"lechuga":15,"papa patata cocida":77,"pepino":15,
    "pimenton rojo":31,"pimenton verde":20,"repollo col":25,"tomate":18,
    "zanahoria":41,"zapallo calabaza":26,
    "arepa":219,"cachapa":210,"masa de maiz":200,"yuca":112,"platano verde":122,
    "nopales":15,"pescado blanco":100,"mariscos surtidos":90,"pulpo":164,
    "calamar":92,"bacalao":105,"trucha":190,"leche de coco":230,"mole poblano":250,
}

# (keyword, food name_normalized, gramos base). Match por palabra completa sobre
# texto sin acentos. Orden: platos preparados y términos específicos primero.
MAP = [
    # Platos preparados (deben ganar sobre proteína/carbo genéricos)
    ("empanadas de carne","empanada de pino al horno",150),
    ("empanada","empanada de pino al horno",120),
    ("sorrentinos","pasta cocida espagueti",160),
    ("ravioles","pasta cocida espagueti",160),
    ("humitas","humitas",140),
    ("cachapa de maiz","cachapa",150),
    ("cachapa","cachapa",150),
    ("anticuchos","carne asada parrilla",150),
    ("pino","carne molida cocida",120),
    # Proteínas específicas
    ("pollo apanado","milanesa de pollo",160),
    ("milanesa","milanesa de carne",150),
    ("pollo desmechado","pollo entero cocido",150),
    ("pollo mechado","pollo entero cocido",150),
    ("pollo deshilachado","pollo entero cocido",150),
    ("pollo rostizado","pollo rostizado",150),
    ("pechuga de pollo","pechuga de pollo a la plancha",170),
    ("pechuga","pechuga de pollo a la plancha",170),
    ("tuto de pollo","muslo de pollo cocido",160),
    ("pollo","pechuga de pollo a la plancha",160),
    ("ojo de bife","carne de vacuno magra cocida",170),
    ("bife magro","carne de vacuno magra cocida",170),
    ("bife","carne de vacuno magra cocida",170),
    ("entrana","carne de vacuno magra cocida",170),
    ("lomo liso","carne de vacuno magra cocida",170),
    ("lomito","carne de vacuno magra cocida",160),
    ("lomo magro","carne de vacuno magra cocida",160),
    ("solomillo","carne de vacuno magra cocida",160),
    ("carrillera","carne de vacuno magra cocida",170),
    ("bondiola","lomo de cerdo cocido",160),
    ("posta","carne de vacuno magra cocida",160),
    ("carne mechada","carne de vacuno magra cocida",150),
    ("carne desmechada","carne de vacuno magra cocida",150),
    ("carne magra guisada","carne de vacuno magra cocida",160),
    ("carne asada","carne asada parrilla",160),
    ("carne molida","carne molida cocida",150),
    ("carne picada","carne molida cocida",150),
    ("res magra","carne de vacuno magra cocida",160),
    ("carne magra","carne de vacuno magra cocida",150),
    ("vacuno","carne de vacuno magra cocida",150),
    ("anticuchos","carne asada parrilla",150),
    ("cordero","carne de cordero cocida",150),
    ("cochinita","lomo de cerdo cocido",150),
    ("cerdo magro","lomo de cerdo cocido",150),
    ("pernil","lomo de cerdo cocido",150),
    ("filete de cerdo","filete de cerdo",150),
    ("cerdo","lomo de cerdo cocido",150),
    ("lomo","carne de vacuno magra cocida",160),
    ("carne","carne de vacuno magra cocida",150),
    ("res","carne de vacuno magra cocida",150),
    ("jamon de pavo","jamon de pavo",60),
    ("jamon serrano","jamon de cerdo",40),
    ("jamon cocido","jamon de cerdo",50),
    ("jamonada","jamon de cerdo",50),
    ("jamon","jamon de cerdo",50),
    ("pavo molido","pavo a la plancha",150),
    ("pavo","pavo a la plancha",150),
    ("chorizo","chorizo cocido",40),
    ("longaniza","longaniza cocida",50),
    ("atun","atun en agua escurrido",120),
    ("jurel","sardinas en aceite",100),
    ("salmon ahumado","salmon cocido",80),
    ("salmon","salmon cocido",150),
    ("merluza","merluza cocida",150),
    ("reineta","reineta cocida",150),
    ("congrio","congrio cocido",150),
    ("bacalao","bacalao",150),
    ("trucha","trucha",150),
    ("pulpo","pulpo",120),
    ("calamar","calamar",120),
    ("camaron","camarones cocidos",120),
    ("mariscos","mariscos surtidos",120),
    ("pargo","pescado blanco",150),
    ("dorada","pescado blanco",150),
    ("pescado blanco","pescado blanco",150),
    ("pescado","pescado blanco",150),
    ("claras","clara de huevo cocida",120),
    ("clara","clara de huevo cocida",120),
    ("tortilla de huevo","huevo entero cocido",120),
    ("huevos","huevo entero cocido",100),
    ("huevo","huevo entero cocido",100),
    # Legumbres / vegetales proteicos
    ("tofu","tofu firme",150),
    ("tempeh","tempeh",120),
    ("soya texturizada","soya texturizada hidratada",120),
    ("edamame","edamame",100),
    ("lenteja","lentejas cocidas",140),
    ("garbanzo","garbanzos cocidos",140),
    ("caraotas","porotos negros cocidos",140),
    ("frijoles negros","porotos negros cocidos",140),
    ("porotos negros","porotos negros cocidos",140),
    ("frijoles","porotos negros cocidos",140),
    ("fabes","porotos blancos cocidos",140),
    ("porotos granados","porotos granados cocidos",140),
    ("porotos","porotos colorados cocidos",140),
    ("arvejas","arvejas cocidas",80),
    ("habas","habas cocidas",100),
    # Carbohidratos
    ("arroz integral","arroz integral cocido",150),
    ("arroz basmati","arroz blanco cocido",150),
    ("arroz sushi","arroz blanco cocido",150),
    ("arroz arborio","arroz blanco cocido",150),
    ("arroz","arroz blanco cocido",150),
    ("sorrentinos","pasta cocida espagueti",160),
    ("ravioles","pasta cocida espagueti",160),
    ("noquis","pasta cocida espagueti",160),
    ("ñoquis","pasta cocida espagueti",160),
    ("fideua","pasta cocida espagueti",150),
    ("fideos integrales","fideos tallarines cocidos",150),
    ("fideos","fideos tallarines cocidos",150),
    ("tallarines","fideos tallarines cocidos",150),
    ("pasta integral","pasta cocida espagueti",150),
    ("pasta","pasta cocida espagueti",150),
    ("espagueti","pasta cocida espagueti",150),
    ("quinoa","quinoa cocida",140),
    ("avena","avena cocida",200),
    ("cous cous","cous cous cocido",140),
    ("mote","mote trigo cocido",140),
    ("tostadas integrales","tostadas integrales",40),
    ("tostadas horneadas","tortilla de maiz",60),
    ("totopos","tortilla de maiz",50),
    ("tortillas de maiz","tortilla de maiz",90),
    ("tortilla de maiz","tortilla de maiz",90),
    ("tortilla integral","tortilla de trigo",70),
    ("tortillas","tortilla de maiz",90),
    ("taco","tortilla de maiz",90),
    ("pan integral","pan integral",60),
    ("pan pita","pan pita integral",60),
    ("pan de molde","pan de molde blanco",60),
    ("marraqueta","pan marraqueta",90),
    ("hallulla","pan hallulla",90),
    ("pan","pan marraqueta",80),
    ("galletas","galletas de agua",30),
    ("crutones","galletas de agua",20),
    ("granola","barra de cereal",40),
    ("maiz pozolero","maiz cocido",120),
    ("pozolero","maiz cocido",120),
    ("maiz blanco","maiz cocido",120),
    ("mazorca","choclo maiz dulce",100),
    ("maiz","maiz cocido",80),
    ("masa de maiz","masa de maiz",120),
    ("masa de harina","harina de trigo",60),
    ("masa de tarta","harina de trigo",60),
    ("harina","harina de trigo",50),
    ("empanadas de carne","empanada de pino al horno",150),
    ("empanada","empanada de pino al horno",120),
    ("arepa","arepa",120),
    ("cachapa","cachapa",150),
    ("humitas","humitas",120),
    # Tubérculos
    ("pure de papas","pure de papas",180),
    ("puré de papas","pure de papas",180),
    ("papa amarilla","papa patata cocida",150),
    ("papa al horno","papa patata cocida",150),
    ("papas","papa patata cocida",150),
    ("papa","papa patata cocida",150),
    ("patata","papa patata cocida",150),
    ("camote","camote batata cocida",150),
    ("batata","camote batata cocida",150),
    ("yuca","yuca",150),
    ("ocumo","yuca",150),
    ("name","papa patata cocida",150),
    ("platano verde","platano verde",120),
    ("patacon","platano verde",120),
    ("platano","platano banana",80),
    ("plátano","platano banana",80),
    ("banana","platano banana",80),
    # Verduras / base
    ("zapallo italiano","zapallo calabaza",80),
    ("zapallo","zapallo calabaza",80),
    ("calabaza","zapallo calabaza",80),
    ("calabacin","zapallo calabaza",80),
    ("auyama","zapallo calabaza",80),
    ("brocoli","brocoli",80),
    ("brócoli","brocoli",80),
    ("espinaca","espinaca",60),
    ("acelga","acelga",80),
    ("champinon","champinon",60),
    ("champiñones","champinon",60),
    ("setas","champinon",60),
    ("nopales","nopales",80),
    ("repollo","repollo col",60),
    ("rabano","repollo col",30),
    ("pepino","pepino",50),
    ("judias verdes","brocoli",70),
    ("pimiento","pimenton rojo",50),
    ("pimientos","pimenton rojo",50),
    ("pimenton","pimenton rojo",40),
    ("zanahoria","zanahoria",60),
    ("betarraga","betarraga remolacha",50),
    ("choclo","choclo maiz dulce",80),
    ("cebolla de verdeo","cebolla",20),
    ("cebollin","cebolla",15),
    ("cebolla","cebolla",30),
    ("ajo","ajo",5),
    ("pico de gallo","tomate",40),
    ("hogao","tomate",30),
    ("sofrito","tomate",30),
    ("gazpacho","tomate",200),
    ("salsa de tomate","tomate",60),
    ("salsa tomate","tomate",60),
    ("salsa verde","tomate",40),
    ("tuco","tomate",60),
    ("tomate","tomate",60),
    ("ensalada criolla","lechuga",70),
    ("ensalada chilena","tomate",70),
    ("ensalada","lechuga",60),
    ("lechuga","lechuga",40),
    ("verduras","zanahoria",70),
    ("guascas","espinaca",10),
    # Palta / aguacate
    ("palta","palta aguacate",50),
    ("aguacate","palta aguacate",50),
    # Frutas
    ("frutos rojos","frambuesa",60),
    ("arandano","arandano",50),
    ("frambuesa","frambuesa",50),
    ("frutilla","frutilla fresa",60),
    ("fresa","frutilla fresa",60),
    ("mango","mango",80),
    ("fruta","manzana",100),
    # Lácteos / grasas / salsas
    ("queso parmesano","queso parmesano rallado",20),
    ("queso crema","queso crema",30),
    ("queso untable","queso crema",30),
    ("queso fresco","queso fresco cottage",40),
    ("queso costeno","queso fresco cottage",40),
    ("queso blanco","queso fresco cottage",40),
    ("queso gauda","queso gauda",30),
    ("queso chanco","queso gauda",30),
    ("queso ligero","queso fresco cottage",30),
    ("queso","queso gauda",30),
    ("yogur griego","yogur griego",150),
    ("yogur","yogur griego",120),
    ("yogurt","yogur griego",120),
    ("leche de coco","leche de coco",40),
    ("coco","leche de coco",40),
    ("crema ligera","crema de leche",20),
    ("crema","crema de leche",20),
    ("leche","leche semidescremada",150),
    ("aceite oliva","aceite de oliva",8),
    ("aceite de oliva","aceite de oliva",8),
    ("aceite","aceite vegetal canola",6),
    ("mantequilla mani","mantequilla de mani",15),
    ("mantequilla maní","mantequilla de mani",15),
    ("mantequilla","mantequilla",8),
    ("manteca","mantequilla",8),
    ("mani","mani tostado sin sal",20),
    ("maní","mani tostado sin sal",20),
    ("nueces","nueces",15),
    ("almendra","almendras",15),
    ("mayonesa","mayonesa",10),
    ("mayo","mayonesa",10),
    ("ketchup","ketchup",15),
    ("miel","miel",10),
    ("aceituna","aceite de oliva",5),
    ("mole","mole poblano",60),
    ("pebre","pebre",20),
    ("caldo","caldo de pollo",50) if "caldo de pollo" in FOODS else ("caldo","tomate",10),
]


_MAP_NORM = [(_strip(kw), food, g) for kw, food, g in MAP]


def map_ingredients(text):
    parts = [_strip(p) for p in text.split(",") if p.strip()]
    chosen = {}
    for part in parts:
        part = part.replace("opcional", "").strip()
        for kw, food, g in _MAP_NORM:
            if re.search(r"\b" + re.escape(kw), part):
                if food not in chosen:
                    chosen[food] = g
                break
    return chosen


def main():
    recipes = json.loads(RAW)["data"] if False else RECIPES
    lines = []
    warnings = []
    for r in recipes:
        chosen = map_ingredients(r["ing"])
        if len(chosen) < 2:
            warnings.append(f"{r['id']}: solo {len(chosen)} ingredientes de '{r['ing']}'")
        derived = sum(g * FOODS[f] / 100 for f, g in chosen.items())
        if derived <= 0:
            warnings.append(f"{r['id']}: derived kcal 0, SKIP")
            continue
        scale = r["kcal"] / derived
        scale = max(0.5, min(2.2, scale))
        items = []
        for f, g in chosen.items():
            gg = max(5, round(g * scale))
            items.append({"food": f, "g": gg})
        payload = json.dumps(items, ensure_ascii=False).replace("'", "''")
        lines.append(f"('{r['id']}','{payload}')")
    header = (
        "-- Structured ingredients for every recipe. Macros are derived from\n"
        "-- these at generation time; grams calibrated so derived kcal approximate\n"
        "-- the recipe's intended kcal. Generated by scripts/gen_structured_ingredients.py\n\n"
        "update public.ai_meal_templates t\n"
        "set ingredientes_estructurados = v.j::jsonb\n"
        "from (values\n"
    )
    body = ",\n".join(lines)
    footer = "\n) as v(eid, j)\nwhere t.external_id = v.eid;\n"
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(header + body + footer)
    print(f"Wrote {len(lines)} updates to {OUT}")
    print(f"Warnings ({len(warnings)}):")
    for w in warnings:
        print("  " + w)


OUT = "supabase/migrations/20260523000009_populate_structured_ingredients.sql"
RAW = ""
RECIPES = __import__("json").loads(open("scripts/_recipes.json", encoding="utf-8").read())

if __name__ == "__main__":
    main()
