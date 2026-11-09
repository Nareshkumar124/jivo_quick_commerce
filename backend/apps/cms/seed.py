"""seed_demo step: app configuration with version policies that never force an update locally."""

from apps.accounts.choices import AppName, Platform
from apps.cms.models import AppConfig, AppVersionPolicy

POLICIES = [
    (
        AppName.CUSTOMER,
        Platform.ANDROID,
        "https://play.google.com/store/apps/details?id=in.jivo.quick",
    ),
    (AppName.CUSTOMER, Platform.IOS, "https://apps.apple.com/in/app/jivo"),
    (
        AppName.RIDER,
        Platform.ANDROID,
        "https://play.google.com/store/apps/details?id=in.jivo.rider",
    ),
]


def seed_app_config(stdout, options) -> None:
    config = AppConfig.load()
    for app, platform, store_url in POLICIES:
        AppVersionPolicy.objects.get_or_create(
            app=app,
            platform=platform,
            defaults={
                "config": config,
                "min_supported_version": "0.0.0",
                "latest_version": "1.0.0",
                "store_url": store_url,
            },
        )
    stdout.write(f"  app config with {config.versions.count()} version policies")


# --------------------------------------------------------------------------- P7: pages and FAQs

PLACEHOLDER_NOTE = (
    "<blockquote><p><strong>Placeholder; legal text pending.</strong> This page is demo text "
    "and is not Jivo's final policy.</p></blockquote>"
)
SUPPORT_LINK = '<a href="mailto:support@jivo.in">support@jivo.in</a>'

PAGES = {
    "about": (
        "About Jivo",
        "<h1>About Jivo</h1><p>Jivo Wellness brings cold-pressed oils, ghee and wellness foods "
        f"to your door in minutes.</p><p>Questions? Write to {SUPPORT_LINK}.</p>",
    ),
    "terms": (
        "Terms of Service",
        "<h1>Terms of Service</h1><p>By using the Jivo app you agree to these terms.</p>"
        "<h2>1. Orders</h2><ol><li>Prices and availability are set by Jivo.</li>"
        "<li>You can cancel an order until the store starts packing it.</li></ol>"
        "<h2>2. Payments</h2><ul><li>UPI, cards, net banking and <em>cash on delivery</em>."
        "</li></ul>",
    ),
    "privacy": (
        "Privacy Policy",
        "<h1>Privacy Policy</h1><p>We use your phone number, addresses and orders to deliver "
        "to you and to support you.</p><p>To ask about or delete your data, write to "
        f"{SUPPORT_LINK}.</p>",
    ),
    "refund-policy": (
        "Refund Policy",
        "<h1>Refund Policy</h1><p>Refunds go back to the original payment method within 5 to 7 "
        "working days.</p><ul><li>Cancelled orders are refunded in full.</li><li>Items the "
        "store could not supply are refunded automatically.</li></ul>",
    ),
    "rider-agreement": (
        "Delivery Partner Agreement",
        "<h1>Delivery Partner Agreement</h1><p>This agreement sets out how you deliver Jivo "
        "orders as an independent delivery partner.</p><ul><li>Earnings are paid weekly.</li>"
        "<li>Cash collected must be deposited at the store.</li></ul>"
        f"<p>Questions? Write to {SUPPORT_LINK}.</p>",
    ),
    "rider-location-disclosure": (
        "Location Use",
        "<h1>How we use your location</h1><p>While you are online, the Jivo Rider app collects "
        "your location, also in the background, to offer you nearby orders and show customers "
        "where their order is.</p><p>Location is not collected while you are offline.</p>",
    ),
}

FAQS = [
    # (app, category, question, answer, sort_order)
    (
        "customer",
        "Orders",
        "How long does delivery take?",
        "Most orders arrive in 10 to 30 minutes. You can follow your order live from the order "
        "screen.",
        10,
    ),
    (
        "customer",
        "Orders",
        "Can I cancel my order?",
        "Yes, until the store starts packing it. Open the order and tap Cancel order.",
        20,
    ),
    (
        "customer",
        "Payments & refunds",
        "When will I get my refund?",
        "Refunds go back to the original payment method within 5 to 7 working days.",
        30,
    ),
    (
        "customer",
        "Payments & refunds",
        "Is cash on delivery available?",
        "Yes, for orders up to the limit shown at checkout.",
        40,
    ),
    (
        "customer",
        "Account",
        "How do I delete my account?",
        "Open Account, then Delete account. You can undo it by logging in again within 30 days.",
        50,
    ),
    (
        "rider",
        "Deliveries",
        "What if the customer does not answer?",
        "Call the customer from the app, wait at the door, then call ops before marking the "
        "delivery as failed.",
        10,
    ),
    (
        "rider",
        "Cash",
        "Where do I deposit cash?",
        "Deposit cash collected on delivery at your home store. The store manager records it.",
        20,
    ),
]


def seed_pages_and_faqs(stdout, options) -> None:
    """Placeholder pages (clearly marked: legal text pending) and a few FAQs per app. Existing
    pages are left alone so an edited page is never overwritten."""
    from apps.cms.models import FAQ, PAGE_SLUGS, Page

    created_pages = 0
    for slug in PAGE_SLUGS:
        title, html = PAGES[slug]
        _, created = Page.objects.get_or_create(
            slug=slug, defaults={"title": title, "body_html": PLACEHOLDER_NOTE + html}
        )
        created_pages += created
    created_faqs = 0
    for app, category, question, answer, sort_order in FAQS:
        _, created = FAQ.objects.get_or_create(
            app=app,
            question=question,
            defaults={"category": category, "answer": answer, "sort_order": sort_order},
        )
        created_faqs += created
    stdout.write(f"  cms: {created_pages} pages and {created_faqs} FAQs created (placeholders)")
