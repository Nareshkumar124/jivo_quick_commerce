# ruff: noqa: RUF001 (the en dashes are part of the published text)
"""Launch policy pages (v1, 2026-11-28), loaded by `manage.py load_legal_pages`.

Converted from `docs/legal/policies.md` (that file is not in the Docker image, so the text lives
here). Keep the two in step: edit the markdown first, then this module. The HTML uses only the
tags `apps.cms.html.sanitize_html` keeps; the sanitiser has no tables, so the refund table is a
list. The page title is served separately (`Page.title`), so bodies start below it.
"""

TERMS_VERSION = "2026-11-28"
# Links between pages must be absolute https (the sanitiser drops relative links): bodies carry
# this token, replaced by `page_html()` with `--base-url` (or DEFAULT_BASE_URL).
BASE_URL_TOKEN = "__JQC_LEGAL_BASE_URL__"  # noqa: S105 (a placeholder, not a secret)
DEFAULT_BASE_URL = "https://quick.jivo.in"
SUPPORT_PHONE = "+918595349565"
SUPPORT_EMAIL = "info@jivo.in"

_EMAIL = '<a href="mailto:info@jivo.in">info@jivo.in</a>'
_PHONE = '<a href="tel:+918595349565">+91 8595 349 565</a>'
_ADDRESS = "Khasra No. 20//9/2 & 10/1/2, Bhakarpur, Ganaur, District Sonipat, Haryana – 131101"
_UPDATED = "<p><strong>Last updated: 28 November 2026</strong></p>"

TERMS_HTML = f"""{_UPDATED}
<p>These terms apply to the Jivo Quick Commerce customer app and website ("the app"), run by \
<strong>Jivo Beverages Pvt. Ltd.</strong>, {_ADDRESS} ("Jivo", "we", "us"). By creating an account or \
placing an order you agree to these terms, our Privacy policy, our Refund and cancellation policy \
and our Delivery policy.</p>
<h2>1. Who can use the app</h2>
<p>You must be at least 18 years old and able to enter a binding contract under Indian law. You \
are responsible for keeping your login (phone number or email and the one-time code) to yourself \
and for all orders placed from your account.</p>
<h2>2. Products and prices</h2>
<ul>
<li>We sell only Jivo products, from our own stores. Product photos are for illustration; the \
product label is the final word on ingredients, nutrition and use.</li>
<li>Prices are in Indian Rupees and include GST. The price, fees and total are shown in the bill \
before you place the order. The price you pay is the one in the bill when you order.</li>
<li>Stock is limited. If an item becomes unavailable after you order, we will remove it and lower \
your bill (see the Refund and cancellation policy).</li>
<li>Some products have a minimum or maximum quantity per order, shown in the cart.</li>
</ul>
<h2>3. Orders</h2>
<ul>
<li>An order is confirmed when the app shows it as placed. We may refuse or cancel an order, for \
example when an item is out of stock, the address cannot be served, the price shown was clearly \
wrong, or we suspect misuse. We will tell you in the app.</li>
<li>You may cancel an order in the app until the store starts packing it.</li>
</ul>
<h2>4. Payment</h2>
<ul>
<li>Right now we accept <strong>cash on delivery</strong> only. You can pay the rider in cash. \
Online payment will be added later and will then be handled by our payment partner; Jivo does not \
store card details.</li>
<li>If you refuse cash-on-delivery orders again and again, we may turn off cash on delivery for \
your account.</li>
</ul>
<h2>5. Delivery</h2>
<p>Delivery areas, times and fees are described in the Delivery policy. Share the delivery code \
shown in the app only with the rider when you receive your order.</p>
<h2>6. Acceptable use</h2>
<p>Do not misuse the app: no fake orders, no reselling in bulk, no abuse of riders or staff, no \
attempts to break or overload the app, and no use of someone else's account. We may suspend or \
close accounts that break these rules.</p>
<h2>7. Your account</h2>
<p>You can update your details in the app and delete your account from Account → Delete account. \
Orders that are still open must be completed or cancelled first. Some records (such as invoices) \
must be kept by law even after deletion; see the Privacy policy.</p>
<h2>8. Liability</h2>
<p>We take care to deliver the right products in good condition. Our total liability for any \
order is limited to the amount you paid for that order, except where Indian law does not allow \
such a limit. We are not responsible for delays caused by events outside our control (for example \
weather, strikes, traffic restrictions or network outages).</p>
<h2>9. Changes</h2>
<p>We may update these terms. The app will show the new version and ask you to accept it when you \
next log in.</p>
<h2>10. Law and disputes</h2>
<p>These terms are governed by the laws of India. Courts in Sonipat, Haryana have jurisdiction. Before \
going to court, please contact us (see the Contact page) so we can try to solve the problem.</p>
"""

PRIVACY_HTML = f"""{_UPDATED}
<p>Jivo Beverages Pvt. Ltd. ("Jivo", "we") runs the Jivo Quick Commerce apps. This policy explains \
what personal data we collect, why, and your rights under the Digital Personal Data Protection \
Act, 2023.</p>
<h2>What we collect</h2>
<ul>
<li><strong>Account:</strong> your phone number and/or email address, name (if you give it).</li>
<li><strong>Addresses and location:</strong> the delivery addresses you save, and your device \
location when you allow it, to check whether we deliver to you and to place the pin on the \
map.</li>
<li><strong>Orders:</strong> what you ordered, bills, invoices, order status, delivery code \
checks, and your support messages and photos.</li>
<li><strong>Device and app:</strong> app version, device type, a push-notification token, and \
crash and error reports.</li>
<li><strong>Riders (rider app only):</strong> identity and KYC documents, vehicle and bank \
details, and live location while on duty, used to assign and track deliveries and to pay \
riders.</li>
</ul>
<p>We do not collect card details. When online payment is added, it will be handled by our \
payment partner (Razorpay) under its own privacy policy.</p>
<h2>Why we use it</h2>
<p>To create your account and log you in (one-time codes), to check delivery and deliver your \
orders, to show live order tracking, to send order updates by notification, to give support, to \
issue GST invoices, to prevent fraud and misuse, and to meet legal duties. We do not sell your \
personal data and do not use it for third-party advertising.</p>
<h2>Who we share it with</h2>
<p>Only as needed to run the service: our riders (your name, delivery address and phone number \
for your order), our cloud hosting and storage, Sentry (app error reports, without your name, \
phone or address), Google (Firebase for push notifications; Google Maps services, which receive \
map coordinates but not your name, phone or address text), SMS and email providers that deliver \
login codes, and government authorities when the law requires it.</p>
<h2>How long we keep it</h2>
<p>Account data is kept while your account is active. Order records and invoices are kept for as \
long as tax and accounting laws require (generally 8 years). Rider live-location history is kept \
for a short period for delivery support and then deleted. When you delete your account we delete \
or anonymise your data, except records we must keep by law.</p>
<h2>Your rights</h2>
<p>You can see and correct your details in the app, withdraw consent, and delete your account \
from Account → Delete account (see <a href="{BASE_URL_TOKEN}/legal/delete-account/">Delete your \
account</a> for other ways and what is kept). For any other request (a copy of your data, a \
correction, or a complaint), write to the grievance contact below. We reply within 30 days.</p>
<h2>Security</h2>
<p>Data is sent over encrypted connections (HTTPS). Sensitive rider data (such as bank details) \
is stored encrypted, and staff access is limited by role.</p>
<h2>Children</h2>
<p>The app is not meant for anyone under 18. We do not knowingly collect children's data.</p>
<h2>Contact and grievance</h2>
<p>Grievance contact, Jivo Beverages Pvt. Ltd., {_ADDRESS}. Email: {_EMAIL}. Phone: {_PHONE}.</p>
"""

REFUND_HTML = f"""{_UPDATED}
<h2>Cancelling an order</h2>
<ul>
<li>You can cancel an order in the app until the store starts packing it: open the order and tap \
<strong>Cancel order</strong>.</li>
<li>After packing has started, the app no longer allows cancelling. Contact us (see the Contact \
page) and we will help where we can.</li>
<li>Jivo may cancel an order, for example when items are out of stock or the address cannot be \
served. We will tell you in the app.</li>
</ul>
<h2>What you pay or get back</h2>
<p>Right now all orders are <strong>cash on delivery</strong>:</p>
<ul>
<li><strong>You cancel before packing starts:</strong> nothing to pay.</li>
<li><strong>Jivo cancels the order:</strong> nothing to pay.</li>
<li><strong>Some items are not available:</strong> you pay only for the items delivered; the bill \
is lowered.</li>
<li><strong>We could not deliver:</strong> nothing to pay.</li>
</ul>
<p>When online payment is added, a full refund is made for cancelled or undelivered orders and \
for missing items, back to the original payment method, usually within 5–7 working days. If we \
could not deliver because you could not be reached or refused the order, the delivery fee is not \
refunded.</p>
<h2>Damaged, wrong or missing items</h2>
<p>If an item arrives damaged, leaking, expired, wrong or missing, tell us through \
<strong>Help</strong> in the app or at {_EMAIL} / {_PHONE} <strong>within 48 hours of \
delivery</strong>, with a photo if possible. After checking, we will refund the item or send a \
replacement. Because our products are food items, opened or used items cannot be returned unless \
they were faulty.</p>
"""

DELIVERY_HTML = f"""{_UPDATED}
<h2>Where we deliver</h2>
<p>We deliver only to addresses served by one of our stores. The app checks your address before \
you order and tells you if we do not deliver there yet.</p>
<h2>How fast</h2>
<p>Most orders arrive within 10–30 minutes after the store accepts them. The app shows the \
expected time before you order and lets you track the rider live. Heavy rain, traffic or very \
busy hours can make it longer.</p>
<h2>Delivery hours</h2>
<p>Each store's opening hours are shown in the app. Outside them, the app shows when ordering \
opens again.</p>
<h2>Charges</h2>
<p>Any delivery, small-order or handling fee is shown in the bill before you place the order. All \
prices are in Indian Rupees and include GST.</p>
<h2>At delivery</h2>
<ul>
<li>Share the <strong>delivery code</strong> shown in the app with the rider to receive your \
order.</li>
<li>Pay the rider in cash for cash-on-delivery orders.</li>
<li>If the rider cannot reach you, they will call you and wait about 10 minutes before returning \
the order to the store.</li>
</ul>
<h2>Shipping</h2>
<p>We deliver only with our own riders inside our delivery areas. We do not ship by courier or \
outside India.</p>
"""

CONTACT_HTML = f"""<p><strong>Jivo Quick Commerce</strong> is run by \
<strong>Jivo Beverages Pvt. Ltd.</strong><br>{_ADDRESS}<br>GSTIN: 06AAGCJ4460J1ZG</p>
<ul>
<li><strong>Orders and support:</strong> {_PHONE}</li>
<li><strong>Email:</strong> {_EMAIL}</li>
<li><strong>In the app:</strong> Account → <strong>Help</strong> for any question about an \
order.</li>
</ul>
<p><strong>Grievance contact</strong> (Consumer Protection (E-Commerce) Rules, 2020 and DPDP Act, \
2023): Grievance Officer, Jivo Beverages Pvt. Ltd., at the address above, {_EMAIL}, {_PHONE}. We \
acknowledge complaints within 48 hours and aim to resolve them within one month.</p>
"""

DELETE_ACCOUNT_HTML = f"""{_UPDATED}
<p>This page explains how to delete your account in the <strong>Jivo Quick Commerce</strong> \
customer app or the <strong>Jivo Rider</strong> app, run by Jivo Beverages Pvt. Ltd.</p>
<h2>Delete in the app</h2>
<ol>
<li>Open the app and log in.</li>
<li>Go to <strong>Account → Delete account</strong>.</li>
<li>Confirm. You are logged out and your account is closed.</li>
</ol>
<p>Your personal data is erased 30 days later. If you log in again within those 30 days, the \
account is restored and the deletion is cancelled.</p>
<h2>Delete by email</h2>
<p>If you cannot use the app, email <strong>{_EMAIL}</strong> from the email address registered \
on your account (or include your registered phone number) with the subject <strong>"Delete my \
account"</strong>. We check that the request comes from the account holder and delete the account \
within 30 days.</p>
<h2>Before you delete</h2>
<p>Open orders (and, for riders, an active delivery or unsettled cash) must be finished first.</p>
<h2>What is deleted</h2>
<p>Your profile (name, email, phone number), saved addresses, push-notification tokens and app \
login sessions. For riders, also your live-location history and profile.</p>
<h2>What we keep, and for how long</h2>
<ul>
<li><strong>Invoices and order records:</strong> kept as tax and accounting laws require \
(generally 8 years), with your personal details removed where the law allows.</li>
<li><strong>Riders:</strong> payout, cash-collection and KYC records are kept as long as the law \
requires, then deleted.</li>
</ul>
<p>Questions: {_EMAIL} or {_PHONE}.</p>
"""

# slug -> (title, body_html), in the order the web index lists them.
LEGAL_PAGES: dict[str, tuple[str, str]] = {
    "terms": ("Terms of use", TERMS_HTML),
    "privacy": ("Privacy policy", PRIVACY_HTML),
    "refund-policy": ("Refund and cancellation policy", REFUND_HTML),
    "delivery-policy": ("Delivery policy", DELIVERY_HTML),
    "contact": ("Contact us", CONTACT_HTML),
    "delete-account": ("Delete your account", DELETE_ACCOUNT_HTML),
}


def page_html(slug: str, base_url: str | None = None) -> str:
    """Body of one launch page with inter-page links pointing at `base_url`."""
    base = (base_url or DEFAULT_BASE_URL).rstrip("/")
    return LEGAL_PAGES[slug][1].replace(BASE_URL_TOKEN, base)
