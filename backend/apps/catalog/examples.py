"""Example payloads for the Phase 2 catalog contract. The apps build their fakes from these, so each
one is a complete, valid instance of its schema (checked by tests/test_schema_examples.py).

Money is consistent: discount_amount = mrp - selling_price, discount_percent = floor of the percent
off MRP, unit prices per 100 ml. Store 1 is "Jivo Sector 14, Gurugram" (see apps.stores.examples).
"""

from apps.stores.examples import STORE_CLOSED_FOR_NIGHT, STORE_OPEN

MEDIA = "https://media.jivo.in/catalog"


def image(key: str, alt_text: str = "") -> dict:
    return {
        "thumbnail": f"{MEDIA}/{key}-256.webp",
        "medium": f"{MEDIA}/{key}-512.webp",
        "large": f"{MEDIA}/{key}-1024.webp",
        "alt_text": alt_text,
    }


# --------------------------------------------------------------------------- categories

EDIBLE_OILS = {
    "id": 1,
    "name": "Edible Oils",
    "slug": "edible-oils",
    "image": image("c7a41e/edible-oils", "Edible oils"),
}
WELLNESS_BEVERAGES = {
    "id": 2,
    "name": "Wellness Beverages",
    "slug": "wellness-beverages",
    "image": image("0b93d2/wellness-beverages", "Wellness beverages"),
}
SEEDS_SUPERFOODS = {
    "id": 3,
    "name": "Seeds & Superfoods",
    "slug": "seeds-superfoods",
    "image": None,
}
CANOLA_OIL_CATEGORY = {
    "id": 11,
    "name": "Canola Oil",
    "slug": "canola-oil",
    "image": image("5d2e8a/canola-oil", "Canola oil"),
}
OLIVE_OIL_CATEGORY = {
    "id": 12,
    "name": "Olive Oil",
    "slug": "olive-oil",
    "image": image("9a1f07/olive-oil", "Olive oil"),
}
MUSTARD_OIL_CATEGORY = {
    "id": 13,
    "name": "Mustard Oil",
    "slug": "mustard-oil",
    "image": image("e40c6b/mustard-oil", "Mustard oil"),
}
JUICES_CATEGORY = {
    "id": 21,
    "name": "Health Juices",
    "slug": "health-juices",
    "image": image("2c8d55/health-juices", "Health juices"),
}

CATEGORY_TREE = {
    "results": [
        {
            **EDIBLE_OILS,
            "children": [CANOLA_OIL_CATEGORY, OLIVE_OIL_CATEGORY, MUSTARD_OIL_CATEGORY],
        },
        {**WELLNESS_BEVERAGES, "children": [JUICES_CATEGORY]},
        {**SEEDS_SUPERFOODS, "children": []},
    ]
}

# --------------------------------------------------------------------------- variants

CANOLA_1L_IMAGE = image("8f3b2c/canola-1l", "Jivo Cold Pressed Canola Oil 1 L bottle")
CANOLA_5L_IMAGE = image("1e7d90/canola-5l", "Jivo Cold Pressed Canola Oil 5 L jar")
OLIVE_1L_IMAGE = image("4b6a13/pomace-olive-1l", "Jivo Pomace Olive Oil 1 L bottle")
MUSTARD_1L_IMAGE = image("d2905f/mustard-1l", "Jivo Kachi Ghani Mustard Oil 1 L bottle")
WHEATGRASS_IMAGE = image("6c0e4a/wheatgrass-500ml", "Jivo Wheatgrass Juice 500 ml bottle")
ALOE_IMAGE = image("a37f21/aloe-vera-1l", "Jivo Aloe Vera Juice 1 L bottle")

CANOLA_1L = {
    "id": 1001,
    "name": "1 L",
    "mrp": "349.00",
    "selling_price": "279.00",
    "discount_amount": "70.00",
    "discount_percent": 20,
    "unit_price": {"amount": "27.90", "per": "100 ml"},
    "stock_status": "IN_STOCK",
    "orderable_quantity": 5,
    "units_left": None,
    "max_qty_per_order": 5,
    "image": CANOLA_1L_IMAGE,
}
CANOLA_5L = {
    "id": 1002,
    "name": "5 L",
    "mrp": "1650.00",
    "selling_price": "1299.00",
    "discount_amount": "351.00",
    "discount_percent": 21,
    "unit_price": {"amount": "25.98", "per": "100 ml"},
    "stock_status": "LOW_STOCK",
    "orderable_quantity": 2,
    "units_left": 2,
    "max_qty_per_order": 3,
    "image": CANOLA_5L_IMAGE,
}
OLIVE_1L = {
    "id": 1003,
    "name": "1 L",
    "mrp": "899.00",
    "selling_price": "699.00",
    "discount_amount": "200.00",
    "discount_percent": 22,
    "unit_price": {"amount": "69.90", "per": "100 ml"},
    "stock_status": "IN_STOCK",
    "orderable_quantity": 5,
    "units_left": None,
    "max_qty_per_order": 5,
    "image": OLIVE_1L_IMAGE,
}
MUSTARD_1L = {
    "id": 1004,
    "name": "1 L",
    "mrp": "210.00",
    "selling_price": "189.00",
    "discount_amount": "21.00",
    "discount_percent": 10,
    "unit_price": {"amount": "18.90", "per": "100 ml"},
    "stock_status": "OUT_OF_STOCK",
    "orderable_quantity": 0,
    "units_left": None,
    "max_qty_per_order": 5,
    "image": MUSTARD_1L_IMAGE,
}
WHEATGRASS_500ML = {
    "id": 2001,
    "name": "500 ml",
    "mrp": "250.00",
    "selling_price": "225.00",
    "discount_amount": "25.00",
    "discount_percent": 10,
    "unit_price": {"amount": "45.00", "per": "100 ml"},
    "stock_status": "IN_STOCK",
    "orderable_quantity": 4,
    "units_left": None,
    "max_qty_per_order": 4,
    "image": WHEATGRASS_IMAGE,
}
ALOE_1L = {
    "id": 2002,
    "name": "1 L",
    "mrp": "299.00",
    "selling_price": "299.00",
    "discount_amount": "0.00",
    "discount_percent": 0,
    "unit_price": {"amount": "29.90", "per": "100 ml"},
    "stock_status": "IN_STOCK",
    "orderable_quantity": 4,
    "units_left": None,
    "max_qty_per_order": 4,
    "image": ALOE_IMAGE,
}

# --------------------------------------------------------------------------- product cards

CANOLA = {
    "id": 101,
    "slug": "jivo-cold-pressed-canola-oil",
    "name": "Jivo Cold Pressed Canola Oil",
    "brand": "Jivo",
    "is_veg": True,
    "image": CANOLA_1L_IMAGE,
    "default_variant_id": 1001,
    "variants": [CANOLA_1L, CANOLA_5L],
}
CANOLA_5L_DEAL = {**CANOLA, "image": CANOLA_5L_IMAGE, "default_variant_id": 1002}
OLIVE = {
    "id": 102,
    "slug": "jivo-pomace-olive-oil",
    "name": "Jivo Pomace Olive Oil",
    "brand": "Jivo",
    "is_veg": True,
    "image": OLIVE_1L_IMAGE,
    "default_variant_id": 1003,
    "variants": [OLIVE_1L],
}
MUSTARD = {
    "id": 103,
    "slug": "jivo-kachi-ghani-mustard-oil",
    "name": "Jivo Kachi Ghani Mustard Oil",
    "brand": "Jivo",
    "is_veg": True,
    "image": MUSTARD_1L_IMAGE,
    "default_variant_id": 1004,
    "variants": [MUSTARD_1L],
}
WHEATGRASS = {
    "id": 201,
    "slug": "jivo-wheatgrass-juice",
    "name": "Jivo Wheatgrass Juice",
    "brand": "Jivo",
    "is_veg": True,
    "image": WHEATGRASS_IMAGE,
    "default_variant_id": 2001,
    "variants": [WHEATGRASS_500ML],
}
ALOE = {
    "id": 202,
    "slug": "jivo-aloe-vera-juice",
    "name": "Jivo Aloe Vera Juice",
    "brand": "Jivo",
    "is_veg": True,
    "image": ALOE_IMAGE,
    "default_variant_id": 2002,
    "variants": [ALOE_1L],
}

# --------------------------------------------------------------------------- home

BANNERS = [
    {
        "id": 1,
        "title": "Cold pressed canola oil: up to 21% off",
        "image": image("b1c9e2/banner-canola-offer", "Canola oil offer"),
        "link_type": "collection",
        "link_value": "offers",
    },
    {
        "id": 2,
        "title": "Start your day with wheatgrass",
        "image": image("f05d7a/banner-wheatgrass", "Jivo Wheatgrass Juice"),
        "link_type": "product",
        "link_value": "jivo-wheatgrass-juice",
    },
    {
        "id": 3,
        "title": "Healthy cooking tips",
        "image": image("7e44b8/banner-healthy-cooking", "Healthy cooking"),
        "link_type": "url",
        "link_value": "https://jivo.in/healthy-cooking",
    },
]
COLLECTION_BESTSELLERS = {
    "id": 1,
    "name": "Bestsellers",
    "slug": "bestsellers",
    "products": [CANOLA, OLIVE, WHEATGRASS],
    "has_more": True,
}
COLLECTION_OFFERS = {
    "id": 2,
    "name": "Offers",
    "slug": "offers",
    "products": [CANOLA_5L_DEAL, OLIVE, MUSTARD],
    "has_more": False,
}
HOME_ANONYMOUS = {
    "store": STORE_OPEN,
    "banners": BANNERS,
    "categories": [EDIBLE_OILS, WELLNESS_BEVERAGES, SEEDS_SUPERFOODS],
    "collections": [COLLECTION_BESTSELLERS, COLLECTION_OFFERS],
    "buy_again": [],
}
HOME_SIGNED_IN = {**HOME_ANONYMOUS, "buy_again": [OLIVE, CANOLA_5L_DEAL, ALOE]}
HOME_STORE_CLOSED = {**HOME_SIGNED_IN, "store": STORE_CLOSED_FOR_NIGHT}

# --------------------------------------------------------------------------- product lists

API = "https://api.jivo.in/api/v1"
PRODUCTS_EDIBLE_OILS = {
    "count": 3,
    "next": None,
    "previous": None,
    "results": [CANOLA, OLIVE, MUSTARD],
}
PRODUCTS_PRICE_ASC_PAGE_1 = {
    "count": 23,
    "next": f"{API}/products/?category=wellness-beverages&page=2&page_size=2&sort=price_asc",
    "previous": None,
    "results": [WHEATGRASS, ALOE],
}
PRODUCTS_EMPTY = {"count": 0, "next": None, "previous": None, "results": []}
SEARCH_OIL = PRODUCTS_EDIBLE_OILS

# --------------------------------------------------------------------------- product detail

JIVO_CARE = "Consumer care: 1800-123-4567 (toll free), care@jivo.in. Jivo Wellness Pvt. Ltd."
JIVO_ADDRESS = (
    "Jivo Wellness Pvt. Ltd., Plot 21, HSIIDC Industrial Estate, Kundli, Sonipat, Haryana"
)

CANOLA_DETAIL = {
    "id": 101,
    "slug": "jivo-cold-pressed-canola-oil",
    "name": "Jivo Cold Pressed Canola Oil",
    "brand": "Jivo",
    "is_veg": True,
    "category": CANOLA_OIL_CATEGORY,
    "short_description": "Cold pressed canola oil, rich in omega-3 and low in saturated fat.",
    "description": (
        "Jivo Cold Pressed Canola Oil is extracted without heat to keep its natural nutrients.\n\n"
        "Its light taste and high smoke point suit everyday Indian cooking: sauteing, shallow "
        "frying and baking."
    ),
    "highlights": [
        "Lowest saturated fat among common cooking oils",
        "Rich in omega-3 (ALA) and vitamin E",
        "Cholesterol free",
    ],
    "default_variant_id": 1001,
    "variants": [
        {
            **CANOLA_1L,
            "sku": "JV-CAN-CP-1L",
            "net_quantity": "1 L",
            "images": [
                CANOLA_1L_IMAGE,
                image("3a6f9c/canola-1l-back", "Back label: nutrition table"),
                image("c18e47/canola-cooking", "Cooking with canola oil"),
            ],
        },
        {
            **CANOLA_5L,
            "sku": "JV-CAN-CP-5L",
            "net_quantity": "5 L",
            "images": [CANOLA_5L_IMAGE, image("c18e47/canola-cooking", "Cooking with canola oil")],
        },
    ],
    "ingredients": "Cold pressed canola oil (100%).",
    "nutrition": {
        "columns": ["Per 100 ml", "Per serving (15 ml)"],
        "rows": [
            {"name": "Energy (kcal)", "values": ["828", "124"], "is_sub_row": False},
            {"name": "Total fat (g)", "values": ["92", "13.8"], "is_sub_row": False},
            {"name": "Saturated fat (g)", "values": ["6.4", "1"], "is_sub_row": True},
            {"name": "Monounsaturated fat (g)", "values": ["58", "8.7"], "is_sub_row": True},
            {"name": "Polyunsaturated fat (g)", "values": ["27.6", "4.1"], "is_sub_row": True},
            {"name": "Trans fat (g)", "values": ["0", "0"], "is_sub_row": True},
            {"name": "Cholesterol (mg)", "values": ["0", "0"], "is_sub_row": False},
        ],
    },
    "shelf_life": "9 months from the date of manufacture",
    "storage_instructions": "Store in a cool, dry place away from direct sunlight.",
    "country_of_origin": "India",
    "manufacturer": JIVO_ADDRESS,
    "marketer": "",
    "importer": "",
    "consumer_care": JIVO_CARE,
    "fssai_license_no": "10020064000123",
    "similar_products": [OLIVE, MUSTARD],
}
OLIVE_DETAIL = {
    "id": 102,
    "slug": "jivo-pomace-olive-oil",
    "name": "Jivo Pomace Olive Oil",
    "brand": "Jivo",
    "is_veg": True,
    "category": OLIVE_OIL_CATEGORY,
    "short_description": "Olive oil for high-heat Indian cooking.",
    "description": "Pomace olive oil from Spain, suited to deep frying and tadka.",
    "highlights": ["Imported from Spain", "High smoke point", "Neutral taste"],
    "default_variant_id": 1003,
    "variants": [
        {**OLIVE_1L, "sku": "JV-OLV-POM-1L", "net_quantity": "1 L", "images": [OLIVE_1L_IMAGE]}
    ],
    "ingredients": "Refined olive-pomace oil and virgin olive oil.",
    "nutrition": {
        "columns": ["Per 100 ml"],
        "rows": [
            {"name": "Energy (kcal)", "values": ["828"], "is_sub_row": False},
            {"name": "Total fat (g)", "values": ["92"], "is_sub_row": False},
            {"name": "Saturated fat (g)", "values": ["14"], "is_sub_row": True},
        ],
    },
    "shelf_life": "18 months from the date of packing",
    "storage_instructions": "Store in a cool, dark place. Close the cap after use.",
    "country_of_origin": "Spain",
    "manufacturer": "Almazara Ejemplo S.L. (example packer), Poligono Industrial, Jaen, Spain",
    "marketer": JIVO_ADDRESS,
    "importer": JIVO_ADDRESS,
    "consumer_care": JIVO_CARE,
    "fssai_license_no": "10020064000123",
    "similar_products": [CANOLA, MUSTARD],
}

# --------------------------------------------------------------------------- search & collections

SUGGEST_CAN = {
    "query": "can",
    "suggestions": [
        {
            "type": "product",
            "text": "Jivo Cold Pressed Canola Oil",
            "query": "canola oil",
            "id": 101,
            "slug": "jivo-cold-pressed-canola-oil",
            "image": CANOLA_1L_IMAGE,
        },
        {
            "type": "category",
            "text": "Canola Oil",
            "query": "canola oil",
            "id": 11,
            "slug": "canola-oil",
            "image": CANOLA_OIL_CATEGORY["image"],
        },
        {
            "type": "keyword",
            "text": "canola oil 5 l",
            "query": "canola oil 5 l",
            "id": None,
            "slug": None,
            "image": None,
        },
    ],
}
SUGGEST_TRENDING = {
    "query": "",
    "suggestions": [
        {"type": "keyword", "text": term, "query": term, "id": None, "slug": None, "image": None}
        for term in ("olive oil", "wheatgrass juice", "mustard oil")
    ],
}
SUGGEST_NONE = {"query": "xyz", "suggestions": []}

COLLECTION_BESTSELLERS_DETAIL = {
    "id": 1,
    "name": "Bestsellers",
    "slug": "bestsellers",
    "products": [CANOLA, OLIVE, WHEATGRASS, ALOE, MUSTARD],
}
