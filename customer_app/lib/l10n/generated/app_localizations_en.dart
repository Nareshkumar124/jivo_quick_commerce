// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jivo';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get splashChecking => 'Getting things ready…';

  @override
  String get splashFailedTitle => 'Can\'t reach Jivo';

  @override
  String get offlineBanner => 'No internet connection';

  @override
  String get onboardingTitle1 => 'Wellness, delivered fast';

  @override
  String get onboardingBody1 =>
      'Jivo oils, foods and essentials at your door in minutes.';

  @override
  String get onboardingTitle2 => 'Straight from Jivo';

  @override
  String get onboardingBody2 => 'Genuine products, fresh stock, fair prices.';

  @override
  String get onboardingTitle3 => 'Track every order';

  @override
  String get onboardingBody3 =>
      'Follow your rider live until your order arrives.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of Jivo is no longer supported. Please update the app to continue.';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateAvailable => 'A new version of Jivo is available.';

  @override
  String get later => 'Later';

  @override
  String get maintenanceTitle => 'We\'ll be back soon';

  @override
  String get maintenanceDefaultBody =>
      'Jivo is down for maintenance. Please try again in a little while.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get linkOpenFailed => 'Couldn\'t open the link.';

  @override
  String get loginTitle => 'Log in or sign up';

  @override
  String get loginSubtitle => 'Enter your mobile number to get an OTP.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phonePrefix => '+91';

  @override
  String get phoneInvalid => 'Enter a valid 10-digit mobile number.';

  @override
  String get getOtp => 'Get OTP';

  @override
  String get consentPrefix => 'By continuing, you agree to our';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get refundPolicy => 'Refund Policy';

  @override
  String get sessionExpired => 'Your session has expired. Please log in again.';

  @override
  String get otpTitle => 'Verify your number';

  @override
  String otpSentTo(int length, String phone) {
    return 'Enter the $length-digit OTP sent to $phone';
  }

  @override
  String get otpLabel => 'OTP';

  @override
  String otpIncomplete(int length) {
    return 'Enter the $length-digit OTP.';
  }

  @override
  String get verify => 'Verify';

  @override
  String resendIn(int seconds) {
    return 'Resend OTP in ${seconds}s';
  }

  @override
  String get resendOtp => 'Resend OTP';

  @override
  String get otpResent => 'A new OTP has been sent.';

  @override
  String get changeNumber => 'Change number';

  @override
  String get accountDeactivated =>
      'This account is deactivated. Please contact support.';

  @override
  String get deletionCancelledNotice =>
      'Welcome back! Your account deletion request has been cancelled.';

  @override
  String get completeProfileTitle => 'Tell us about you';

  @override
  String get completeProfileSubtitle => 'We\'ll use your name for deliveries.';

  @override
  String get nameLabel => 'Full name';

  @override
  String get nameRequired => 'Please enter your name.';

  @override
  String get emailLabel => 'Email (optional)';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get emailCantBeUsed => 'This email can\'t be used.';

  @override
  String get accountTitle => 'Account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get addresses => 'Saved addresses';

  @override
  String get legal => 'Legal';

  @override
  String appVersion(String version) {
    return 'App version $version';
  }

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Log out of Jivo on this device?';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get phoneNotEditable => 'Your mobile number can\'t be changed.';

  @override
  String get profileSaved => 'Profile updated.';

  @override
  String get addressesEmpty => 'No saved addresses yet.';

  @override
  String get addAddress => 'Add address';

  @override
  String get editAddress => 'Edit address';

  @override
  String get newAddress => 'New address';

  @override
  String get defaultAddress => 'Default';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get deleteAddressConfirm => 'Delete this address?';

  @override
  String get labelHome => 'Home';

  @override
  String get labelWork => 'Work';

  @override
  String get labelOther => 'Other';

  @override
  String get customLabel => 'Name this address (e.g. Mom\'s place)';

  @override
  String get houseLabel => 'House / flat / floor';

  @override
  String get buildingStreetLabel => 'Building / street';

  @override
  String get landmarkLabel => 'Landmark (optional)';

  @override
  String get areaLabel => 'Area (optional)';

  @override
  String get cityLabel => 'City';

  @override
  String get stateLabel => 'State';

  @override
  String get pincodeLabel => 'PIN code';

  @override
  String get pincodeInvalid => 'Enter a valid 6-digit PIN code.';

  @override
  String get receiverNameLabel => 'Receiver\'s name';

  @override
  String get receiverPhoneLabel => 'Receiver\'s mobile number';

  @override
  String get fieldRequired => 'This field is required.';

  @override
  String get locationTitle => 'Delivery location';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get locationCaptured => 'Location captured';

  @override
  String get locationNeeded =>
      'We need your location to deliver to this address. Stand at the address and tap \"Use my current location\".';

  @override
  String get locationDenied =>
      'Location permission is off. Allow location access so we can find your address.';

  @override
  String get locationDeniedForever =>
      'Location access is blocked for Jivo. Turn it on in Settings.';

  @override
  String get locationServicesOff =>
      'Your phone\'s location is turned off. Turn it on and try again.';

  @override
  String get locationFailed =>
      'We couldn\'t get your location. Please try again.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get addressSaved => 'Address saved.';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountExplainer =>
      'Deleting your account signs you out on all devices. You have 30 days to change your mind: log in again within 30 days to restore it. After that, your personal data is permanently anonymised. Order and invoice records are kept without your personal details, as required by law.';

  @override
  String get deleteReasonLabel => 'Why are you leaving? (optional)';

  @override
  String get sendOtpToConfirm => 'Send OTP to confirm';

  @override
  String deleteOtpSentTo(String phone) {
    return 'Enter the OTP sent to $phone to confirm.';
  }

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get accountDeletedTitle => 'Account deleted';

  @override
  String accountDeletedBody(String date) {
    return 'Your account is scheduled for deletion. Log in again before $date to restore it.';
  }

  @override
  String get staffCannotDelete =>
      'This account can\'t be deleted from the app. Please contact support.';

  @override
  String get tabHome => 'Home';

  @override
  String get tabCategories => 'Categories';

  @override
  String get tabOrderAgain => 'Order again';

  @override
  String get tabAccount => 'Account';

  @override
  String get addToCart => 'ADD';

  @override
  String addToCartSemantics(String name) {
    return 'Add $name to cart';
  }

  @override
  String stepperDecrease(String name) {
    return 'Remove one $name';
  }

  @override
  String stepperIncrease(String name) {
    return 'Add one more $name';
  }

  @override
  String stepperQuantity(int count) {
    return '$count in cart';
  }

  @override
  String maxQtyReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can add up to $count of this item',
      one: 'You can add only 1 of this item',
    );
    return '$_temp0';
  }

  @override
  String get outOfStock => 'Out of stock';

  @override
  String onlyLeft(int count) {
    return 'Only $count left';
  }

  @override
  String discountOff(int percent) {
    return '$percent% OFF';
  }

  @override
  String mrpSemantics(String price) {
    return 'MRP $price';
  }

  @override
  String priceSemantics(String price) {
    return 'Price $price';
  }

  @override
  String get vegMark => 'Vegetarian';

  @override
  String get nonVegMark => 'Non-vegetarian';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get viewCart => 'View cart';

  @override
  String deliveryIn(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Delivery in $minutes mins',
      one: 'Delivery in 1 min',
    );
    return '$_temp0';
  }

  @override
  String get selectLocation => 'Select delivery location';

  @override
  String get checkingDelivery => 'Checking delivery…';

  @override
  String get notDeliveringHere => 'Not delivering here';

  @override
  String get changeLocationSemantics => 'Change delivery location';

  @override
  String get searchHint => 'Search for oils, ghee and more';

  @override
  String get shopByCategory => 'Shop by category';

  @override
  String get previouslyBought => 'Previously bought';

  @override
  String get seeAll => 'See all';

  @override
  String get homeEmpty => 'Nothing to show here yet. Pull down to refresh.';

  @override
  String get homeNeedsLocation =>
      'Choose a delivery location to see what\'s in stock near you.';

  @override
  String get notServiceableInline => 'We don\'t deliver to this location yet.';

  @override
  String get changeLocation => 'Change location';

  @override
  String storeClosedOpensAt(String time) {
    return 'Store closed. Opens at $time. You can browse; checkout opens then.';
  }

  @override
  String get storeClosed => 'Store closed right now. You can still browse.';

  @override
  String bannerSemantics(String title) {
    return 'Offer: $title';
  }

  @override
  String get allInCategory => 'All';

  @override
  String get categoriesEmpty => 'No categories yet.';

  @override
  String get sortBy => 'Sort by';

  @override
  String sortButton(String option) {
    return 'Sort: $option';
  }

  @override
  String get sortRelevance => 'Relevance';

  @override
  String get sortPriceLowHigh => 'Price: low to high';

  @override
  String get sortPriceHighLow => 'Price: high to low';

  @override
  String get sortDiscount => 'Discount';

  @override
  String get productsEmpty => 'No products here yet.';

  @override
  String get loadMoreFailed => 'Couldn\'t load more products.';

  @override
  String get collectionEmpty => 'No products in this collection yet.';

  @override
  String get orderAgainEmpty =>
      'Items you order will show up here so you can buy them again quickly.';

  @override
  String get productNotFound => 'This product isn\'t available.';

  @override
  String get packSize => 'Pack size';

  @override
  String youSave(String amount) {
    return 'You save $amount';
  }

  @override
  String get highlights => 'Highlights';

  @override
  String get description => 'Description';

  @override
  String get productInfo => 'Product information';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get nutritionInfo => 'Nutrition information';

  @override
  String get shelfLife => 'Shelf life';

  @override
  String get storageInfo => 'Storage';

  @override
  String get countryOfOrigin => 'Country of origin';

  @override
  String get manufacturedBy => 'Manufactured by';

  @override
  String get marketedBy => 'Marketed by';

  @override
  String get fssaiLicence => 'FSSAI licence no.';

  @override
  String get similarProducts => 'Similar products';

  @override
  String galleryImage(int index, int count) {
    return 'Image $index of $count. Double tap to zoom.';
  }

  @override
  String get searchFieldHint => 'Search products';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearRecentSearches => 'Clear';

  @override
  String get trendingSearches => 'Trending';

  @override
  String get suggestionsFailed => 'Couldn\'t load suggestions.';

  @override
  String noResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noResultsTry => 'Try one of these:';

  @override
  String get locationPrompt => 'Where should we deliver?';

  @override
  String get detectLocation => 'Use current location';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get currentLocationTitle => 'Current location';

  @override
  String get pinnedLocationTitle => 'Pinned location';

  @override
  String get storeChangeTitle => 'Change delivery location?';

  @override
  String get storeChangeBody =>
      'A different store delivers to this location, so your cart will be cleared.';

  @override
  String get storeChangeConfirm => 'Change and clear cart';

  @override
  String get mapPickerTitle => 'Pick location on map';

  @override
  String get mapPickerHint => 'Move the map to place the pin on your door.';

  @override
  String pinCoordinates(String lat, String lng) {
    return 'Pin at $lat, $lng';
  }

  @override
  String get findingAddress => 'Finding the address…';

  @override
  String get confirmLocation => 'Confirm location';

  @override
  String get locateMe => 'Go to my location';

  @override
  String get mapUnavailableTitle => 'Map isn\'t available';

  @override
  String get mapUnavailableBody =>
      'Use your current location, or enter the address by hand.';

  @override
  String get enterAddressManually => 'Enter address manually';

  @override
  String get notServiceableTitle => 'We\'re not in your area yet';

  @override
  String get notServiceableBody =>
      'Jivo is growing fast. Tap Notify me and we\'ll tell you when we deliver here.';

  @override
  String get notifyMe => 'Notify me';

  @override
  String get notifyMeDone =>
      'Thanks! We\'ll let you know when we start delivering here.';

  @override
  String get tryAnotherAddress => 'Try another address';

  @override
  String variantOptions(String variant, int count) {
    return '$variant · $count options';
  }

  @override
  String unitPrice(String amount, String per) {
    return '$amount/$per';
  }

  @override
  String get storeClosedHeadline => 'Store closed';

  @override
  String storeClosedOpensTomorrow(String time) {
    return 'Store closed. Opens tomorrow at $time. You can browse; checkout opens then.';
  }

  @override
  String get importedBy => 'Imported by';

  @override
  String get consumerCare => 'Consumer care';

  @override
  String get cartComingSoonLabel => 'Cart coming soon';

  @override
  String get addressNotServiceable => 'Not serviceable';

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartEmpty =>
      'Your cart is empty. Add a few Jivo favourites to get started.';

  @override
  String get startShopping => 'Start shopping';

  @override
  String get deliverTo => 'Deliver to';

  @override
  String get changeAddress => 'Change';

  @override
  String get chooseSavedAddress => 'Choose a saved address to place the order.';

  @override
  String get selectAddress => 'Select address';

  @override
  String removeItem(String name) {
    return 'Remove $name';
  }

  @override
  String onlyAvailable(int count) {
    return 'Only $count available';
  }

  @override
  String updateQuantityTo(int count) {
    return 'Update to $count';
  }

  @override
  String get removeAction => 'Remove';

  @override
  String get cartProblemsBanner =>
      'Some items changed since you added them. Fix them to continue.';

  @override
  String freeDeliveryNudge(String amount) {
    return 'Add $amount more for FREE delivery';
  }

  @override
  String get applyCoupon => 'Apply coupon';

  @override
  String couponApplied(String code) {
    return '$code applied';
  }

  @override
  String couponSaves(String amount) {
    return 'You save $amount';
  }

  @override
  String couponNoLongerApplies(String code) {
    return '$code no longer applies to this cart';
  }

  @override
  String get couponsTitle => 'Coupons';

  @override
  String get couponCodeLabel => 'Coupon code';

  @override
  String get couponApply => 'Apply';

  @override
  String couponApplySemantics(String code) {
    return 'Apply coupon $code';
  }

  @override
  String get couponsEmpty => 'No coupons available right now.';

  @override
  String couponSavesOnCart(String amount) {
    return 'Save $amount on this order';
  }

  @override
  String couponAddMore(String amount) {
    return 'Add $amount more to use this coupon';
  }

  @override
  String get couponBelowMinimum =>
      'Your cart is below this coupon\'s minimum order';

  @override
  String get couponExpired => 'This coupon has expired';

  @override
  String get couponUsed => 'You\'ve already used this coupon';

  @override
  String get couponNotApplicable => 'Not applicable on this cart';

  @override
  String couponAppliedMessage(String code, String amount) {
    return '$code applied. You save $amount.';
  }

  @override
  String get couponCodeRequired => 'Enter a coupon code';

  @override
  String get tipTitle => 'Tip your delivery partner';

  @override
  String get tipBody =>
      'Say thanks with a tip. It goes to your delivery partner.';

  @override
  String get tipCustom => 'Custom';

  @override
  String get tipCustomTitle => 'Enter a tip';

  @override
  String get tipCustomLabel => 'Tip in ₹';

  @override
  String tipCustomInvalid(int max) {
    return 'Enter a whole amount from ₹1 to ₹$max';
  }

  @override
  String tipChipSemantics(String amount) {
    return 'Tip $amount';
  }

  @override
  String get instructionsTitle => 'Delivery instructions';

  @override
  String get instructionDontRingBell => 'Don\'t ring the bell';

  @override
  String get instructionLeaveAtDoor => 'Leave at the door';

  @override
  String get instructionAvoidCalling => 'Avoid calling';

  @override
  String get instructionsNoteLabel => 'Note for the delivery partner';

  @override
  String get instructionsSaved => 'Instructions saved';

  @override
  String get billTitle => 'Bill details';

  @override
  String get billItemTotal => 'Item total (MRP)';

  @override
  String get billProductDiscount => 'Product discount';

  @override
  String get billCouponDiscount => 'Coupon discount';

  @override
  String billCouponDiscountCode(String code) {
    return 'Coupon ($code)';
  }

  @override
  String get billDeliveryFee => 'Delivery fee';

  @override
  String get billFree => 'FREE';

  @override
  String get billSmallCartFee => 'Small cart fee';

  @override
  String get billHandlingFee => 'Handling fee';

  @override
  String get billTip => 'Delivery partner tip';

  @override
  String get billToPay => 'To pay';

  @override
  String billSavings(String amount) {
    return 'You save $amount on this order';
  }

  @override
  String minusAmount(String amount) {
    return '−$amount';
  }

  @override
  String minimumOrderShortfall(String amount, String shortfall) {
    return 'Minimum order is $amount. Add $shortfall more to check out.';
  }

  @override
  String minimumOrderNotMet(String amount) {
    return 'Minimum order is $amount.';
  }

  @override
  String get cartStoreClosed =>
      'The store is closed right now. You can check out when it opens.';

  @override
  String get proceedToCheckout => 'Proceed to checkout';

  @override
  String get cartReviewChanges =>
      'Some items in your cart changed. Please review them.';

  @override
  String get checkoutTitle => 'Payment';

  @override
  String get payWith => 'Pay with';

  @override
  String get payOnline => 'Pay online';

  @override
  String get payOnlineSubtitle => 'UPI, cards, net banking and wallets';

  @override
  String get payCod => 'Cash on delivery';

  @override
  String get payCodSubtitle => 'Pay by cash or UPI when your order arrives';

  @override
  String get placeOrder => 'Place order';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get checkoutPlacing => 'Placing your order…';

  @override
  String get checkoutPaying => 'Waiting for your payment…';

  @override
  String get checkoutVerifying => 'Confirming your payment…';

  @override
  String get orderPlacedTitle => 'Order placed!';

  @override
  String orderNumber(String number) {
    return 'Order $number';
  }

  @override
  String orderEta(int minutes) {
    return 'Arriving in about $minutes min';
  }

  @override
  String paidOnlineAmount(String amount) {
    return 'Paid $amount online';
  }

  @override
  String payOnDeliveryAmount(String amount) {
    return 'Pay $amount on delivery';
  }

  @override
  String get trackOrder => 'Track order';

  @override
  String get continueShopping => 'Continue shopping';

  @override
  String get trackingComingSoon => 'Order tracking arrives in a later update.';

  @override
  String get paymentFailedTitle => 'Payment failed';

  @override
  String paymentNotCompleted(String number) {
    return 'The payment for order $number wasn\'t completed.';
  }

  @override
  String get paymentCancelled => 'You closed the payment before it finished.';

  @override
  String paymentPayBy(String time) {
    return 'Pay by $time to keep this order.';
  }

  @override
  String get retryPayment => 'Retry payment';

  @override
  String get changePaymentMethod => 'Change payment method';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get cancelOrderConfirm => 'Cancel this order?';

  @override
  String get keepOrder => 'Keep order';

  @override
  String get orderCancelled => 'Order cancelled';

  @override
  String paymentWindowOver(String number) {
    return 'The time to pay for order $number has run out, so it wasn\'t placed. Your items are still in your cart.';
  }

  @override
  String paymentOrderCancelled(String number) {
    return 'Order $number was cancelled.';
  }

  @override
  String get backToCart => 'Back to cart';

  @override
  String get fakePaymentTitle => 'Test payment (dev build)';

  @override
  String fakePaymentBody(String amount) {
    return 'No real money moves. Choose how paying $amount ends.';
  }

  @override
  String get fakePaymentSucceed => 'Payment succeeds';

  @override
  String get fakePaymentBadSignature => 'Succeeds with a bad signature';

  @override
  String get fakePaymentFail => 'Payment fails';

  @override
  String get fakePaymentWallet => 'External wallet (result by webhook)';

  @override
  String get fakePaymentCancel => 'Close checkout';
}
