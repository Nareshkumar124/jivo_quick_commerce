# Health-claim wording clean-up (2026-11-28)

Reason: Google Play / App Store review. Product text must state facts about the product, not health outcomes.

Scope: `data/catalog/products.csv`, columns `short_description`, `description`, `highlights` only. No other column changed (checked row by row against `HEAD`): SKUs, slugs, prices, GST, HSN, label fields, `variants.csv` and `categories.csv` are untouched. `search_keywords` and `name` had no claims. 33 of 49 products changed, 116 phrase changes below. The same sentence appears in `short_description` and `description` for many products, so one row lists both fields.

Rules used: removed cholesterol, heart, immunity, digestion, weight, blood sugar, detox, skin/hair, brain, bone and "health benefits" wording; removed "healthy", "superfood", "boost", "powerhouse"; kept plain composition facts the source already stated (contains MUFA/PUFA/omega-3, vitamin E, fortified with vitamins A and D, cold pressed, fibre content, gluten-free). No new product fact was added.

## Change list (product, field, old phrase, new phrase)

| Product | Field | Old | New |
|---|---|---|---|
| Jivo Cold Pressed Groundnut Oil (`jivo-cold-press-groundnut-oil`) | description, short_description | , which help lower cholesterol levels. | . |
| Jivo Cold Pressed Groundnut Oil (`jivo-cold-press-groundnut-oil`) | description | Its low saturated fat content makes it suitable for balanced diets and mindful eating. | (removed) |
| Jivo Kachi Ghani Mustard Oil (`jivo-kachi-ghani-mustard-oil`) | description | , which contributes to the maintenance of normal blood cholesterol levels. | . |
| Jivo Soyabean Oil (`jivo-soyabean-oil`) | description | These essential fatty acids support the maintenance of normal blood cholesterol levels when consumed as part of a balanced diet. | (removed) |
| Jivo Cold Pressed Sunflower Oil (`jivo-cold-press-sunflower-oil`) | short_description | This oil retains valuable nutrients including omega-6 polyunsaturated fatty acids, which is an essential fatty acid important for maintaining normal blood cholesterol levels. | This oil contains omega-6 polyunsaturated fatty acids (PUFA). |
| Jivo Cold Pressed Canola Oil (`jivo-cold-press-canola-oil`) | description, short_description | contains a high level of MUFA, which helps maintain blood cholesterol levels when consumed in moderation as part of a balanced diet. | contains a high level of MUFA. |
| Jivo Yellow Mustard Oil (`jivo-first-pressed-yellow-mustard-oil`) | description | (sentence matched by pattern) kitchen staple that.s not only versatile but also packed with benefits | kitchen staple that is versatile for everyday cooking |
| Jivo Rice Bran Oil (`jivo-rice-bran-oil`) | description | , which may help in lowering cholesterol levels when consumed as part of a balanced diet. | . |
| Jivo Gold Refined Oil (`jivo-gold-refined-oil`) | description, short_description | suitable for balanced nutrition | suitable for everyday cooking |
| Jivo Gold Refined Oil (`jivo-gold-refined-oil`) | description, short_description | , which maintains cholesterol levels as part of a varied diet. | . |
| Jivo Extra Virgin Coconut Oil (`jivo-extra-virgin-coconut-oil`) | description, short_description | retaining unsaturated goodness without | without |
| Jivo Extra Virgin Coconut Oil (`jivo-extra-virgin-coconut-oil`) | description | Virgin coconut oil for hair, skin, and cooking suits daily use. | Virgin coconut oil suits everyday cooking. |
| Jivo Extra Virgin Coconut Oil (`jivo-extra-virgin-coconut-oil`) | description | Using chemical-free oil regularly may help improve hair and skin integrity and enhance meal flavors. | It can be used in cooking to enhance meal flavors. |
| Jivo Extra Virgin Coconut Oil (`jivo-extra-virgin-coconut-oil`) | description | (sentence matched by pattern)  ?For hair, consistent massage into the scalp may help achieve nourishing shine\. | (removed) |
| Jivo Extra Virgin Coconut Oil (`jivo-extra-virgin-coconut-oil`) | description | (sentence matched by pattern)  ?On skin, it works best as a moisturizer when applied post-bath.*?sensitivity\. | (removed) |
| Jivo First Pressed Mustard Oil (`jivo-first-pressed-mustard-oil`) | description | One of the widely appreciated benefits of mustard oil is its versatility in the kitchen, allowing it to be used | Mustard oil is versatile in the kitchen, allowing it to be used |
| Sano Sunflower Oil (`sano-sunflower-oil`) | description | a product that guarantees purity, taste, and nutrition | a quality product |
| Sano Sunflower Oil (`sano-sunflower-oil`) | description | Rich in Nutrients: Packed with essential nutrients like Vitamin E and Omega-6 fatty acids, our Sun Flower Oil promotes overall well-being and supports a healthy lifestyle. | Contains Vitamin E and Omega-6 fatty acids. |
| Sano Sunflower Oil (`sano-sunflower-oil`) | description | Maximum Health Benefits: With its natural composition and essential nutrients, our Sun Flower Oil promotes heart health, strengthens the immune system, and supports healthy skin and hair. | Natural Composition: Made from 100% pure sunflower seeds. |
| Sano Sunflower Oil (`sano-sunflower-oil`) | highlights | Heart-Healthy Choice | Contains Vitamin E |
| Sano Sunflower Oil (`sano-sunflower-oil`) | highlights | Nutrient-Packed | Contains Omega-6 Fatty Acids |
| Sano Soyabean Oil (`sano-soyabean-oil`) | description, short_description | the perfect choice for health-conscious individuals who seek pure, natural, and nutrient-rich cooking oil for their culinary delights | a pure and natural cooking oil for everyday cooking |
| Sano Soyabean Oil (`sano-soyabean-oil`) | description | Not only does sano Soyabean Oil bring out the flavours of your dishes, but it also offers numerous health benefits. | sano Soyabean Oil brings out the flavours of your dishes. |
| Sano Soyabean Oil (`sano-soyabean-oil`) | description | Packed with heart-healthy unsaturated fats, it can help reduce bad cholesterol levels while promoting good cholesterol. | It contains unsaturated fats. |
| Sano Soyabean Oil (`sano-soyabean-oil`) | description | The abundance of omega-3 and omega-6 fatty acids in this oil supports brain health, improves skin elasticity, and boosts overall well-being. | It contains omega-3 and omega-6 fatty acids. |
| Sano Soyabean Oil (`sano-soyabean-oil`) | description | sano Soyabean Oil is an excellent source of Vitamin E, a powerful antioxidant that protects your cells from damage caused by free radicals. | sano Soyabean Oil contains Vitamin E, a natural antioxidant. |
| Sano Soyabean Oil (`sano-soyabean-oil`) | description | It also contains essential vitamins and minerals, including Vitamin K, phosphorus, and potassium, which contribute to maintaining healthy bones, muscles, and overall body function. | It also contains Vitamin K, phosphorus, and potassium. |
| Sano Soyabean Oil (`sano-soyabean-oil`) | highlights | Nutrient-Rich & Heart-Healthy | Contains Vitamin E & Omega Fatty Acids |
| Sano Soyabean Oil (`sano-soyabean-oil`) | highlights | Antioxidant Powerhouse | Contains Natural Antioxidant (Vitamin E) |
| Sano Canola Oil (`sano-canola-oil`) | description | Canola oil may help in lowering bad cholesterol and may reduce the risk of heart disease. | (removed) |
| Sano Canola Oil (`sano-canola-oil`) | description | Another bonus: Canola oil contains phytosterols, molecules that reduce the absorption of cholesterol in your body. | Canola oil contains phytosterols. |
| Sano Canola Oil (`sano-canola-oil`) | highlights | Reduces the risk of heart disease | Contains Phytosterols |
| Sano Classic Olive Oil (`sano-classic-olive-oil`) | description | renowned for their rich flavor and health benefits | renowned for their rich flavor |
| Sano Classic Olive Oil (`sano-classic-olive-oil`) | description | celebrated for its numerous health benefits. | celebrated for its flavour. |
| Sano Classic Olive Oil (`sano-classic-olive-oil`) | description | Rich in heart-healthy monounsaturated fats, antioxidants, and essential vitamins, it supports overall well-being and promotes a balanced diet. | It contains monounsaturated fats (MUFA). |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | packed with flavour, nutrition, and health benefits. | packed with flavour. |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | Our mustard oil is known for its rich content of Omega-3 fatty acids, which are essential for a healthy heart and overall well-being. | Our mustard oil contains Omega-3 fatty acids. |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | It is also loaded with antioxidants that promote immunity and combat free radicals. | It also contains natural antioxidants. |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | Not only is our Kachi Ghani Mustard Oil a versatile cooking oil, but it also offers various health benefits. | Our Kachi Ghani Mustard Oil is a versatile cooking oil. |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | It aids digestion, boosts metabolism and promotes better absorption of nutrients. | (removed) |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | The presence of allyl isothiocyanate in mustard oil is known to have antimicrobial and anti-inflammatory properties. | Mustard oil contains allyl isothiocyanate, which gives it its characteristic pungency. |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | description | Experience the authentic taste and health benefits of | Experience the authentic taste of |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | highlights | Boosts Heart Health | Contains Omega-3 Fatty Acids |
| Sano Kachi Ghani Mustard Oil (`sano-kachi-ghani-mustard-oil`) | highlights | Immunity Booster | Contains Natural Antioxidants |
| Sano Pomace Olive Oil (`sano-pomace-olive-oil`) | description | (sentence matched by pattern) It.s versatility and health benefits make it an ideal choice for Indian cuisine, offering a delectable touch to your dishes while keeping you on track towards a healthier lifestyle | Its versatility makes it an ideal choice for Indian cuisine, offering a delectable touch to your dishes |
| Sano Pomace Olive Oil (`sano-pomace-olive-oil`) | highlights | Heart-Healthy & Nutrient-Packed | Contains Monounsaturated Fats |
| Sano Pomace Olive Oil (`sano-pomace-olive-oil`) | highlights | Healthier Cooking Choice | Versatile Cooking Oil |
| Sano Extra Virgin Olive Oil (`sano-extra-virgin-olive-oil`) | description | prepare healthy Indian recipes | prepare Indian recipes |
| Sano Extra Virgin Olive Oil (`sano-extra-virgin-olive-oil`) | description | True benefits of olive oil lie in moderate consumption as part of a balanced diet. | (removed) |
| Sano Extra Virgin Olive Oil (`sano-extra-virgin-olive-oil`) | description | for a cleaner and healthier cooking experience every day | for everyday cooking |
| Sano Extra Virgin Olive Oil (`sano-extra-virgin-olive-oil`) | description | is considered one of the best oil choices for everyday cooking as part of a balanced diet. | is widely used for everyday cooking. |
| Sano Pure Honey (`sano-pure-honey`) | description, short_description | Its 100% Pure and full of health benefits.Honey is considered to have numerous nutrients that offer us immense health benefit. | Sano Pure Honey is 100% pure honey. |
| Sano Pure Honey (`sano-pure-honey`) | description | It Helps to manage weight, helps improve digestion & metabolism, Helps manage a healthy and active lifestyle. | (removed) |
| Sano Pure Honey (`sano-pure-honey`) | description | (sentence matched by pattern) Honey conforms strictly with all requirements of FSSAI and international norms of Pu.*?mineralsrity\. | Honey conforms to the requirements of FSSAI. |
| Sano Pure Honey (`sano-pure-honey`) | description | Add Jivo Sano Honey with warm water and consume daily to see visible benefits. | Add Jivo Sano Honey to warm water, tea or breakfast, to taste. |
| Sano Pure Honey (`sano-pure-honey`) | highlights | Substitute for sugar | Natural Sweetener |
| Jivo Raw Pumpkin Seeds (`jivo-pumpkin-seeds`) | description | These seeds are rich in immunity-boosting vitamins and minerals like zinc and vitamin E, while their high fiber content supports digestive health. | These seeds contain zinc and vitamin E and are high in dietary fiber. |
| Jivo Raw Pumpkin Seeds (`jivo-pumpkin-seeds`) | description | Packed with antioxidants, they help combat oxidative stress, promoting overall wellness. | They also contain natural antioxidants. |
| Jivo Raw Pumpkin Seeds (`jivo-pumpkin-seeds`) | description | Heart-healthy omega-3 fatty acids and magnesium make them a smart choice for maintaining cardiovascular well-being. | They also contain omega-3 fatty acids and magnesium. |
| Jivo Raw Pumpkin Seeds (`jivo-pumpkin-seeds`) | highlights | Rich in Immunity-Boosting Nutrients | Contains Zinc and Vitamin E |
| Jivo Raw Pumpkin Seeds (`jivo-pumpkin-seeds`) | highlights | Natural Antioxidant Powerhouse | Contains Natural Antioxidants |
| Jivo Raw Pumpkin Seeds (`jivo-pumpkin-seeds`) | highlights | Heart-Healthy | Contains Omega-3 and Magnesium |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | description | Magnesium also possesses nerve-calming properties and may also help in managing blood pressure levels. | (removed) |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | description | packed with essential vitamins, minerals, and healthy fats | packed with vitamins, minerals, and fats |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | description | High in vitamin E, magnesium, and selenium, they support heart health, immune function, and overall well-being. | They are high in vitamin E, magnesium, and selenium. |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | description | Enjoy the crunchy goodness and multitude of health benefits with these premium sunflower seeds. | Enjoy the crunchy goodness of these premium sunflower seeds. |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | description | Embrace a healthier lifestyle with Jivo! | (removed) |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | highlights | Diet Food | Ready-to-Eat Seeds |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | highlights | Low-Calorie Snack | Crunchy Snack |
| Jivo Raw Sunflower Seeds (`jivo-sunflower-seeds`) | highlights | Sleep Cycle | Raw Seeds |
| Jivo Raw Chia Seeds (`jivo-chia-seeds`) | description | have No Added Sugar, are low in calories and cholesterol, also free from any chemicals or preservatives, hence can be really healthy by keeping you free from any risk of health hazards. | have No Added Sugar and are free from chemicals and preservatives. |
| Jivo Raw Chia Seeds (`jivo-chia-seeds`) | highlights | Heart health | Raw Whole Seeds |
| Jivo Raw Chia Seeds (`jivo-chia-seeds`) | highlights | Healthy Snacks for All | Easy to Add to Meals |
| Jivo Raw Chia Seeds (`jivo-chia-seeds`) | highlights | Antioxidants loaded | No Added Sugar |
| Jivo Flax Seeds (`jivo-flax-seeds`) | description, short_description | Boost your health with Jivo Organic Flax Seeds in a convenient pack. | Jivo Organic Flax Seeds in a convenient pack. |
| Jivo Flax Seeds (`jivo-flax-seeds`) | description | , they support heart health, digestion, and overall wellness. | . |
| Jivo Flax Seeds (`jivo-flax-seeds`) | description | Add a nutty flavor and a wealth of health benefits to your meals with these high-quality flax seeds. | Add a nutty flavor to your meals with these high-quality flax seeds. |
| Jivo Flax Seeds (`jivo-flax-seeds`) | description | Elevate your nutrition and enjoy a healthier lifestyle with Jivo | Elevate your meals with Jivo |
| Jivo Flax Seeds (`jivo-flax-seeds`) | highlights | Diet Snack | Versatile Seeds |
| Jivo Flax Seeds (`jivo-flax-seeds`) | highlights | Blood Sugar Level | Gluten-Free |
| Jivo Flax Seeds (`jivo-flax-seeds`) | highlights | Immunity Booster | 100% Natural |
| Jivo Flax Seeds (`jivo-flax-seeds`) | highlights | Skin Health | Vegan-Friendly |
| Jivo Flax Seeds (`jivo-flax-seeds`) | description, short_description | These tiny seeds are a nutrient powerhouse, packed with omega-3 fatty acids, dietary fiber, and essential nutrients. | These tiny seeds contain omega-3 fatty acids and dietary fiber. |
| Jivo Basil Seeds (`jivo-basil-seeds`) | description, short_description | Discover the health benefits of Jivo Fiber-Rich Basil Seeds, specially selected for their high fiber content and numerous wellness advantages. | Discover Jivo Fiber-Rich Basil Seeds, specially selected for their high fiber content. |
| Jivo Basil Seeds (`jivo-basil-seeds`) | description | Perfect for anyone looking to boost their dietary fiber intake, these seeds are an excellent addition to your daily routine, supporting weight management and overall health. | Perfect for anyone looking to add dietary fiber to their meals, these seeds are an easy addition to your daily routine. |
| Jivo Basil Seeds (`jivo-basil-seeds`) | highlights | Versatile Superfood | Versatile Seeds |
| Jivo Basil Seeds (`jivo-basil-seeds`) | highlights | Hydration Boost | Use in Drinks and Desserts |
| Jivo Fizzy Soda Lemon (`jivo-fizzy-soda-lemon`) | description | the perfect choice for those looking to indulge in a refreshing drink without compromising on their health goals | a refreshing carbonated drink |
| Jivo Wheatgrass Juice Ginger Ale Sugar Free (`jivo-wheatgrass-juice-ginger-ale`) | description, short_description | Our plant-based juice contains a powerful combination of vitamins, minerals, and antioxidants to give your body the natural boost it needs. | Our plant-based juice is made with wheatgrass. |
| Jivo Wheatgrass Juice Ginger Ale Sugar Free (`jivo-wheatgrass-juice-ginger-ale`) | description | WHEATGRASS JUICE, you can get all the benefits of a nutrient-rich diet without having to sacrifice taste. | Wheatgrass juice with a refreshing ginger ale taste. |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | description, short_description | Elevate your wellness routine with JIVO Healthy Wheatgrass Juice with Mango Flavor. | JIVO Wheatgrass Juice with Mango Flavor. |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | description | (sentence matched by pattern) Each 500ml bottle of this nutrient-packed drink contains cold-pressed wheatgrass juice, delivering the nutritional equivalent of 2 kg of vegetables, perfect for those seeking a healthy and convenient boost\. | Each 500ml bottle of this drink contains cold-pressed wheatgrass juice, perfect for those seeking a convenient drink. |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | description | Known for its detoxifying properties, wheatgrass supports immunity and overall wellness, while the refreshing mango flavor makes each sip a delightful experience. | The refreshing mango flavor makes each sip a delightful experience. |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | description | Made from all-natural ingredients, this juice offers a clean, energizing solution for those who prioritize health and taste in their daily diet. | Made from natural ingredients, this juice offers a refreshing option for your daily routine. |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | highlights | Nutrient-Packed Formula | Cold-Pressed Wheatgrass Juice |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | highlights | Detox and Immune Support | Plant-Based |
| Jivo Wheatgrass Juice Mango (`jivo-wheatgrass-juice-mango`) | highlights | On-the-Go Nutrition | Convenient 500 ml Bottle |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | description | Revered as one of the healthiest foods on the planet, quinoa seeds offer a wide array of benefits for both the body and the environment. With growing popularity in health-conscious diets around the globe, quinoa has earned its reputation as a "superfood. | (removed) |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | description | perfect for anyone looking to improve their diet and embrace a healthier lifestyle | perfect for anyone looking to add variety to their meals |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | description | including their nutritional benefits, | including their nutritional information, |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | highlights | Improved Digestive Health | Versatile Whole Seed |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | highlights | Weight Management | Easy to Cook |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | highlights | Heart Health | Everyday Ingredient |
| Jivo Premium Quinoa (`jivo-premium-quinoa`) | highlights | Blood Sugar Regulation | Suits Salads and Bowls |
| Jivo A2 Cow Ghee (`jivo-a2-cow-ghee`) | description, short_description | offers the benefits of A2 ghee through its traditional Bilona method | is made through the traditional Bilona method |
| Jivo A2 Cow Ghee (`jivo-a2-cow-ghee`) | description | The benefits of A2 ghee shine in its quality for everyday use and special occasions. | It suits everyday use and special occasions. |
| Jivo Cumin Seeds (`jivo-cumin-seeds`) | description | making them a healthy and safe choice for your meals | making them a simple choice for your meals |
| Jivo Whole Black Pepper (`jivo-whole-black-pepper`) | description | Rich in antioxidants, these peppercorns not only enhance the taste of your meals but also contribute to your overall health by combating free radicals. | These peppercorns enhance the taste of your meals. |
| Jivo Whole Black Pepper (`jivo-whole-black-pepper`) | highlights | Rich in Antioxidants | Pungent & Aromatic |
| Jivo Whole Black Pepper (`jivo-whole-black-pepper`) | highlights | Aids Digestion | Adds Heat and Aroma |
| Jivo Whole Black Pepper (`jivo-whole-black-pepper`) | description | making it a safe, wholesome, and flavorful addition to your culinary repertoire | making it a flavorful addition to your culinary repertoire |
| Jivo Green Cardamom (`jivo-green-cardamom`) | description | the best in both taste and health benefits | the best in taste and aroma |
| Jivo Kashmiri Saffron (`jivo-kashmiri-saffron`) | description | Cultural Tradition: In Ayurveda, saffron is traditionally valued for its natural qualities and is commonly used in practices that emphasize balance and overall well-being. | Cultural Tradition: Saffron is traditionally used in Indian cooking and festive dishes. |
| Jivo Kashmiri Saffron (`jivo-kashmiri-saffron`) | description, highlights | Key Bioactives | Natural Colour and Aroma Compounds |
| Jivo Black Sliced Olives (`jivo-black-sliced-olives`) | description | (sentence matched by pattern) Packed with essential nutrients, they.re not only delicious but also a healthy choice for your lifestyle | They are delicious and ready to use |
| Jivo Black Sliced Olives (`jivo-black-sliced-olives`) | highlights | Healthy and Nutritious | Delicious and Versatile |

## Left unchanged on purpose, but Jivo / compliance should confirm

These are factual-looking claims, not health outcomes, but app stores or FSSAI may still ask for proof.

1. "Cholesterol free" / "Cholesterol & Trans Fat Free" on vegetable oils (jivo-pomace-olive-oil, jivo-first-pressed-mustard-oil, jivo-first-pressed-sunflower-oil, jivo-first-pressed-sesame-oil, jivo-so-olive-oil, plus highlights). Plants contain no cholesterol, and FSSAI claim rules limit this wording on oils. Ask Jivo's regulatory team whether to keep it. Easy to remove later.
2. "Rich in Antioxidants" (jivo-basil-seeds, jivo-premium-quinoa highlights) and "contains natural antioxidants" (several oils and seeds). FSSAI expects the named nutrient (e.g. vitamin E). Needs the nutrition panel from Jivo.
3. "A2" / "A2 Gir Cow" on jivo-a2-cow-ghee. FSSAI has issued advisories on A2 claims. Ask Jivo.
4. "Organic" on jivo-sunflower-seeds, jivo-flax-seeds, jivo-cinnamon-bark. Needs an organic certification number.
5. "100% pure" / "pure honey" on sano-pure-honey. Needs FSSAI standard confirmation.
6. Composition statements kept from the source and not verified against labels: "high in dietary fiber" (pumpkin seeds), "contains Vitamin K, phosphorus and potassium" (sano-soyabean-oil), "omega-3 fatty acids" (sano-kachi-ghani-mustard-oil), "fortified with Vitamins A and D". Compare with the nutrition panel before launch.
7. jivo-extra-virgin-coconut-oil: the sentence "retaining unsaturated goodness" was also factually wrong (coconut oil is mostly saturated fat) and was removed. The hair and skin use lines were removed because the product is sold as an edible oil.
8. Sano descriptions are copied from Amazon and still contain a few marketing phrases such as "finest" and "premium" (not health claims, left as is).

## Validator

`python -I data/tools/validate_catalog.py --images-pending`: 0 hard errors (same gaps as before: missing HSN, FSSAI, SAP codes, nutrition and so on). Text rules (no HTML, plain text) pass.

## Apply to production: text only

Prices, stock and images are in `variants.csv`, the inventory tables and the image tables. They are never touched by a products-only import.

A text-only file is prepared: `data/catalog/text_only/products.csv`. It has four columns (`slug`, `short_description`, `description`, `highlights`) and only the 33 changed products. The import (`apps/catalog/admin/resources.py`, `ProductResource`) updates only the columns that are present and keeps the current value of every column that is missing. This matters because the full `products.csv` also holds `gst_rate`, `is_active`, `sort_order` and the label fields. Importing it whole would reset any value Finance or the admin has changed on production since the file was made (for example the 5% GST placeholder, DL-67).

Steps (PM runs them, nothing was run by this agent):

1. Copy `data/catalog/text_only/` to the server (for example `/srv/jqc/catalog_text/`).
2. Dry run (the default, saves nothing): `python manage.py import_catalog --dir /srv/jqc/catalog_text` inside the backend container. Expect `products.csv: 0 created, 33 updated, 0 unchanged, 0 error(s)` (a count below 33 means the server already had the new text, which is fine). `categories.csv` and `variants.csv` print "not found, skipped", because the folder has only products.csv. If it says "created" for any row, stop: a slug does not exist on production.
3. Save: same command with `--commit --yes` (`--yes` is needed because the database is not on the same machine as the command). One transaction, nothing is saved if any row fails, nothing is deleted.
4. Do not use `--dir data/catalog` on production, and do not pass `variants.csv` (that is where prices live).

Alternative without a server command: Admin, Products, Import, upload `data/catalog/text_only/products.csv` (shows a dry run first, then Confirm).

Caveat: the partial-column behaviour comes from reading the resource code; it was not run against a database. The dry run in step 2 proves it. If the dry run lists "created" or any error, use the full `products.csv` only after checking production values first.

Also: the text lives only in the database, so the app picks it up on the next catalog fetch (cache may delay it). The app's own screens, store listing text and `design/` mockups are outside this task.
