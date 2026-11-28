# Jivo Quick Commerce: policy pages (v1, 2026-11-28)

Status: **published text for launch** (owner instruction 2026-11-28: create the policies, take contact details from shop.jivo.in). Jivo's legal team should still review it. Contact details come from the shop.jivo.in footer (Jivo Mart Pvt. Ltd., Mayapuri address, +91 8595 349 565, info@jivo.in). Not on shop.jivo.in and still to be added when Jivo gives them: GSTIN, FSSAI licence number, CIN, grievance officer name. The earlier `policy-pages-draft.md` is replaced by this file.

Slugs (CMS `Page` rows, served in the apps at `GET /api/v1/pages/<slug>/` and on the web at `/legal/<slug>/`): `terms`, `privacy`, `refund-policy`, `delivery-policy`, `contact`, `delete-account`. The text is embedded for the server in `backend/apps/cms/legal_pages.py` and loaded with `manage.py load_legal_pages --base-url https://quick.jivo.in`; change both together.

Terms version: `2026-11-28`.

---

## terms: Terms of use

**Last updated: 28 November 2026**

These terms apply to the Jivo Quick Commerce customer app and website ("the app"), run by **Jivo Mart Pvt. Ltd.**, A-35/1, Industrial Area Phase 1, Mayapuri, New Delhi – 110064 ("Jivo", "we", "us"). By creating an account or placing an order you agree to these terms, our Privacy policy, our Refund and cancellation policy and our Delivery policy.

### 1. Who can use the app
You must be at least 18 years old and able to enter a binding contract under Indian law. You are responsible for keeping your login (phone number or email and the one-time code) to yourself and for all orders placed from your account.

### 2. Products and prices
- We sell only Jivo products, from our own stores. Product photos are for illustration; the product label is the final word on ingredients, nutrition and use.
- Prices are in Indian Rupees and include GST. The price, fees and total are shown in the bill before you place the order. The price you pay is the one in the bill when you order.
- Stock is limited. If an item becomes unavailable after you order, we will remove it and lower your bill (see the Refund and cancellation policy).
- Some products have a minimum or maximum quantity per order, shown in the cart.

### 3. Orders
- An order is confirmed when the app shows it as placed. We may refuse or cancel an order, for example when an item is out of stock, the address cannot be served, the price shown was clearly wrong, or we suspect misuse. We will tell you in the app.
- You may cancel an order in the app until the store starts packing it.

### 4. Payment
- Right now we accept **cash on delivery** only. You can pay the rider in cash. Online payment will be added later and will then be handled by our payment partner; Jivo does not store card details.
- If you refuse cash-on-delivery orders again and again, we may turn off cash on delivery for your account.

### 5. Delivery
Delivery areas, times and fees are described in the Delivery policy. Share the delivery code shown in the app only with the rider when you receive your order.

### 6. Acceptable use
Do not misuse the app: no fake orders, no reselling in bulk, no abuse of riders or staff, no attempts to break or overload the app, and no use of someone else's account. We may suspend or close accounts that break these rules.

### 7. Your account
You can update your details in the app and delete your account from Account → Delete account. Orders that are still open must be completed or cancelled first. Some records (such as invoices) must be kept by law even after deletion; see the Privacy policy.

### 8. Liability
We take care to deliver the right products in good condition. Our total liability for any order is limited to the amount you paid for that order, except where Indian law does not allow such a limit. We are not responsible for delays caused by events outside our control (for example weather, strikes, traffic restrictions or network outages).

### 9. Changes
We may update these terms. The app will show the new version and ask you to accept it when you next log in.

### 10. Law and disputes
These terms are governed by the laws of India. Courts in New Delhi have jurisdiction. Before going to court, please contact us (see the Contact page) so we can try to solve the problem.

---

## privacy: Privacy policy

**Last updated: 28 November 2026**

Jivo Mart Pvt. Ltd. ("Jivo", "we") runs the Jivo Quick Commerce apps. This policy explains what personal data we collect, why, and your rights under the Digital Personal Data Protection Act, 2023.

### What we collect
- **Account:** your phone number and/or email address, name (if you give it).
- **Addresses and location:** the delivery addresses you save, and your device location when you allow it, to check whether we deliver to you and to place the pin on the map.
- **Orders:** what you ordered, bills, invoices, order status, delivery code checks, and your support messages and photos.
- **Device and app:** app version, device type, a push-notification token, and crash and error reports.
- **Riders (rider app only):** identity and KYC documents, vehicle and bank details, and live location while on duty, used to assign and track deliveries and to pay riders.

We do not collect card details. When online payment is added, it will be handled by our payment partner (Razorpay) under its own privacy policy.

### Why we use it
To create your account and log you in (one-time codes), to check delivery and deliver your orders, to show live order tracking, to send order updates by notification, to give support, to issue GST invoices, to prevent fraud and misuse, and to meet legal duties. We do not sell your personal data and do not use it for third-party advertising.

### Who we share it with
Only as needed to run the service: our riders (your name, delivery address and phone number for your order), our cloud hosting and storage, Sentry (app error reports, without your name, phone or address), Google (Firebase for push notifications; Google Maps services, which receive map coordinates but not your name, phone or address text), SMS and email providers that deliver login codes, and government authorities when the law requires it.

### How long we keep it
Account data is kept while your account is active. Order records and invoices are kept for as long as tax and accounting laws require (generally 8 years). Rider live-location history is kept for a short period for delivery support and then deleted. When you delete your account we delete or anonymise your data, except records we must keep by law.

### Your rights
You can see and correct your details in the app, withdraw consent, and delete your account from Account → Delete account (see [Delete your account](https://quick.jivo.in/legal/delete-account/) for other ways and what is kept). For any other request (a copy of your data, a correction, or a complaint), write to the grievance contact below. We reply within 30 days.

### Security
Data is sent over encrypted connections (HTTPS). Sensitive rider data (such as bank details) is stored encrypted, and staff access is limited by role.

### Children
The app is not meant for anyone under 18. We do not knowingly collect children's data.

### Contact and grievance
Grievance contact, Jivo Mart Pvt. Ltd., A-35/1, Industrial Area Phase 1, Mayapuri, New Delhi – 110064. Email: info@jivo.in. Phone: +91 8595 349 565.

---

## refund-policy: Refund and cancellation policy

**Last updated: 28 November 2026**

### Cancelling an order
- You can cancel an order in the app until the store starts packing it: open the order and tap **Cancel order**.
- After packing has started, the app no longer allows cancelling. Contact us (see the Contact page) and we will help where we can.
- Jivo may cancel an order, for example when items are out of stock or the address cannot be served. We will tell you in the app.

### What you pay or get back
Right now all orders are **cash on delivery**:

| What happened | Cash on delivery |
|---|---|
| You cancel before packing starts | Nothing to pay |
| Jivo cancels the order | Nothing to pay |
| Some items are not available | You pay only for the items delivered; the bill is lowered |
| We could not deliver | Nothing to pay |

When online payment is added, a full refund is made for cancelled or undelivered orders and for missing items, back to the original payment method, usually within 5–7 working days. If we could not deliver because you could not be reached or refused the order, the delivery fee is not refunded.

### Damaged, wrong or missing items
If an item arrives damaged, leaking, expired, wrong or missing, tell us through **Help** in the app or at info@jivo.in / +91 8595 349 565 **within 48 hours of delivery**, with a photo if possible. After checking, we will refund the item or send a replacement. Because our products are food items, opened or used items cannot be returned unless they were faulty.

---

## delivery-policy: Delivery policy

**Last updated: 28 November 2026**

### Where we deliver
We deliver only to addresses served by one of our stores. The app checks your address before you order and tells you if we do not deliver there yet.

### How fast
Most orders arrive within 10–30 minutes after the store accepts them. The app shows the expected time before you order and lets you track the rider live. Heavy rain, traffic or very busy hours can make it longer.

### Delivery hours
Each store's opening hours are shown in the app. Outside them, the app shows when ordering opens again.

### Charges
Any delivery, small-order or handling fee is shown in the bill before you place the order. All prices are in Indian Rupees and include GST.

### At delivery
- Share the **delivery code** shown in the app with the rider to receive your order.
- Pay the rider in cash for cash-on-delivery orders.
- If the rider cannot reach you, they will call you and wait about 10 minutes before returning the order to the store.

### Shipping
We deliver only with our own riders inside our delivery areas. We do not ship by courier or outside India.

---

## contact: Contact us

**Jivo Quick Commerce** is run by **Jivo Mart Pvt. Ltd.**
A-35/1, Industrial Area Phase 1, Mayapuri, New Delhi – 110064

- **Orders and support:** +91 8595 349 565
- **Email:** info@jivo.in
- **In the app:** Account → **Help** for any question about an order.

**Grievance contact** (Consumer Protection (E-Commerce) Rules, 2020 and DPDP Act, 2023): Grievance Officer, Jivo Mart Pvt. Ltd., at the address above, info@jivo.in, +91 8595 349 565. We acknowledge complaints within 48 hours and aim to resolve them within one month.

---

## delete-account: Delete your account

**Last updated: 28 November 2026**

This page explains how to delete your account in the **Jivo Quick Commerce** customer app or the **Jivo Rider** app, run by Jivo Mart Pvt. Ltd.

### Delete in the app
1. Open the app and log in.
2. Go to **Account → Delete account**.
3. Confirm. You are logged out and your account is closed.

Your personal data is erased 30 days later. If you log in again within those 30 days, the account is restored and the deletion is cancelled.

### Delete by email
If you cannot use the app, email **info@jivo.in** from the email address registered on your account (or include your registered phone number) with the subject **"Delete my account"**. We check that the request comes from the account holder and delete the account within 30 days.

### Before you delete
Open orders (and, for riders, an active delivery or unsettled cash) must be finished first.

### What is deleted
Your profile (name, email, phone number), saved addresses, push-notification tokens and app login sessions. For riders, also your live-location history and profile.

### What we keep, and for how long
- **Invoices and order records:** kept as tax and accounting laws require (generally 8 years), with your personal details removed where the law allows.
- **Riders:** payout, cash-collection and KYC records are kept as long as the law requires, then deleted.

Questions: info@jivo.in or +91 8595 349 565.
