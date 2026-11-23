// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jivo Quick Commerce';

  @override
  String get brandName => 'Jivo';

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
  String get offlineBannerHint =>
      'We\'ll update as soon as you\'re back online.';

  @override
  String get refreshFailed => 'Couldn\'t refresh. Check your connection.';

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
  String referAndEarn(String amount) {
    return 'Refer & earn $amount';
  }

  @override
  String get referAFriend => 'Refer a friend';

  @override
  String get referralStripGeneric => 'Invite friends and earn rewards';

  @override
  String get referralEntryHaveCode => 'Got a friend\'s code? Enter it here';

  @override
  String get referralTitle => 'Refer & earn';

  @override
  String referralHeadline(String amount) {
    return 'Invite a friend, you both get $amount off';
  }

  @override
  String get referralYourCode => 'Your referral code';

  @override
  String referralCodeSemantics(String code) {
    return 'Your referral code: $code';
  }

  @override
  String get referralCopy => 'Copy';

  @override
  String get referralCopyCodeSemantics => 'Copy your referral code';

  @override
  String referralCodeCopied(String code) {
    return 'Code $code copied';
  }

  @override
  String get referralShare => 'Share invite';

  @override
  String get referralShareCopied =>
      'Invite message copied. Paste it in WhatsApp or SMS to send it.';

  @override
  String get referralHowItWorks => 'How it works';

  @override
  String get referralStep1 =>
      'Share your code with a friend who is new to Jivo.';

  @override
  String get referralStep2 => 'They enter it before their first order.';

  @override
  String referralStep3(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'When their first order is delivered, you both get $amount off. Use it within $days days.',
      one:
          'When their first order is delivered, you both get $amount off. Use it within 1 day.',
    );
    return '$_temp0';
  }

  @override
  String referralMinOrder(String amount) {
    return 'Valid on orders of $amount or more.';
  }

  @override
  String get referralFriendsJoined => 'Friends joined';

  @override
  String get referralRewardsEarned => 'Rewards earned';

  @override
  String get referralNoFriendsYet =>
      'No friends have joined yet. Share your code to get started.';

  @override
  String get referralPaused =>
      'Refer & earn is paused right now. Please check back later.';

  @override
  String get referralHaveCode => 'Have a referral code?';

  @override
  String get referralHaveCodeHint =>
      'Enter a friend\'s code before your first order.';

  @override
  String get referralCodeLabel => 'Friend\'s code';

  @override
  String get referralApply => 'Apply';

  @override
  String get referralCodeRequired => 'Enter your friend\'s code';

  @override
  String referralApplied(String amount) {
    return 'Code applied. You and your friend will each get $amount off after your first delivery.';
  }

  @override
  String referralJoinedWith(String code) {
    return 'You joined with code $code';
  }

  @override
  String referralStatusPending(String amount) {
    return 'You and your friend will each get $amount off after your first delivery.';
  }

  @override
  String referralStatusRewarded(String amount) {
    return 'Your $amount reward is in your coupons. Pick it under Apply coupon in your cart.';
  }

  @override
  String get referralStatusNoReward =>
      'No reward for this code: Refer & earn was paused when your first order was delivered.';

  @override
  String referralPromptBody(String amount) {
    return 'Enter it before you place this order. You and your friend each get $amount off after it\'s delivered.';
  }

  @override
  String get referralPromptAction => 'Enter code';

  @override
  String get referralPromptDismiss => 'Close';

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
  String get setLocationOnMap => 'Set location on map';

  @override
  String get mapBackToForm => 'Back to the form';

  @override
  String get addressServiceableYes => 'We deliver here.';

  @override
  String get addressServiceableNo =>
      'We don\'t deliver to this pin yet. You can still save the address.';

  @override
  String get addressServiceableChecking => 'Checking delivery for this pin…';

  @override
  String addressServiceableClosed(String when) {
    return 'We deliver here. $when';
  }

  @override
  String get addressPrefillNote =>
      'Filled from the map. Check them before saving.';

  @override
  String get addressDiscardTitle => 'Discard this address?';

  @override
  String get addressDiscardBody => 'What you typed will be lost.';

  @override
  String get addressKeepEditing => 'Keep editing';

  @override
  String get addressDiscard => 'Discard';

  @override
  String get adjustPin => 'Adjust pin';

  @override
  String get gpsOnlyAtAddress =>
      'Use this only when you are at this address now.';

  @override
  String get pinNeededMap => 'Set the delivery location on the map first.';

  @override
  String get pinNeededNoMap => 'Set the delivery location first.';

  @override
  String get saveThisLocation => 'Save this location as an address';

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
  String quantityBoxLabel(int count) {
    return 'Quantity $count, tap to change';
  }

  @override
  String get updatingQuantity => 'Updating quantity';

  @override
  String addToCartSemantics(String name) {
    return 'Add $name to cart';
  }

  @override
  String get typeQuantityTitle => 'Enter quantity';

  @override
  String get typeQuantityField => 'Quantity';

  @override
  String get typeQuantityHint => '0 removes it from the cart';

  @override
  String get typeQuantityEmpty => 'Enter a quantity';

  @override
  String get typeQuantityUpdate => 'Update';

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
  String minQtyShort(int count) {
    return 'Min $count';
  }

  @override
  String minQtyPerOrder(int count) {
    return 'Minimum $count per order';
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
  String get searchHint => 'Search products';

  @override
  String get homeSearchHint => 'Search water, oils and more';

  @override
  String get homeCategories => 'Shop by category';

  @override
  String decreaseQuantitySemantics(String name) {
    return 'Decrease $name';
  }

  @override
  String increaseQuantitySemantics(String name) {
    return 'Increase $name';
  }

  @override
  String get allProducts => 'All products';

  @override
  String get shopNow => 'Shop now';

  @override
  String get referNow => 'Refer now';

  @override
  String get closeBanner => 'Close';

  @override
  String get perCarton => '/carton';

  @override
  String bulkPriceFrom(String price, int count) {
    return '$price at $count+ cartons';
  }

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
  String get wholesaleRatesTitle => 'Wholesale rates (per carton)';

  @override
  String priceTierRange(int from, int to) {
    return '$from–$to cartons';
  }

  @override
  String priceTierExactly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartons',
      one: '1 carton',
    );
    return '$_temp0';
  }

  @override
  String priceTierFrom(int from) {
    return '$from+ cartons';
  }

  @override
  String priceTierRangeShort(int from, int to) {
    return '$from–$to';
  }

  @override
  String priceTierFromShort(int from) {
    return '$from+';
  }

  @override
  String priceTierChip(String range, String price) {
    return '$range: $price';
  }

  @override
  String priceTierRowSemantics(String range, String price) {
    return '$range: $price per carton';
  }

  @override
  String get priceTierNote =>
      'Price depends on total cartons in your order (all sizes)';

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
  String get chooseSavedAddress =>
      'Save this location as an address, or choose a saved one, to place the order.';

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
  String minQtyLineIssue(int count) {
    return 'Order at least $count';
  }

  @override
  String get removeAction => 'Remove';

  @override
  String get cartProblemsBanner =>
      'Some items changed since you added them. Fix them to continue.';

  @override
  String cartLinePriceChanged(String before, String now) {
    return 'Price changed: was $before, now $now';
  }

  @override
  String cartPricesChangedSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Prices of $count items have changed since you last saw them. The bill uses today\'s prices.',
      one: 'The price of 1 item has changed since you last saw it. The bill uses today\'s prices.',
    );
    return '$_temp0';
  }

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
  String minimumUnitsShortfall(int count, int minimum, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Add $count more $label to place your order (minimum $minimum $label)',
      one: 'Add 1 more to place your order (minimum $minimum $label)',
    );
    return '$_temp0';
  }

  @override
  String minimumUnitsNotMet(int minimum, String label) {
    return 'Minimum order is $minimum $label.';
  }

  @override
  String get orderUnitsDefault => 'items';

  @override
  String pricePerBox(String price) {
    return '$price/carton';
  }

  @override
  String get wholesaleRateTag => 'Wholesale rate';

  @override
  String priceTierHeadline(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count more $label',
      one: 'Add 1 more',
    );
    return '$_temp0';
  }

  @override
  String priceTierDetailLine(String price, String variant) {
    return 'and pay $price/carton on $variant';
  }

  @override
  String get priceTierDetailMany => 'and pay less per carton';

  @override
  String get priceTierAddMore => 'Add more';

  @override
  String get myCoupons => 'My coupons';

  @override
  String get couponForYou => 'For you';

  @override
  String couponMinOrder(String amount) {
    return 'Min order $amount';
  }

  @override
  String couponCodeCopied(String code) {
    return 'Code $code copied';
  }

  @override
  String couponCopySemantics(String code) {
    return 'Copy code $code';
  }

  @override
  String get couponsNeedLocation =>
      'Choose your delivery location to see coupons';

  @override
  String get couponsChooseLocation => 'Choose location';

  @override
  String get myCouponsEmpty => 'No coupons right now';

  @override
  String priceTierNudgeLine(
    int count,
    String label,
    String price,
    String variant,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count more $label to get $price/carton on $variant',
      one: 'Add 1 more to get $price/carton on $variant',
    );
    return '$_temp0';
  }

  @override
  String priceTierNudge(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count more $label for lower prices',
      one: 'Add 1 more for lower prices',
    );
    return '$_temp0';
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
  String get codUnavailableFallback =>
      'Cash on delivery isn\'t available for this order';

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

  @override
  String get blockerNotServiceable =>
      'We don\'t deliver to this address from this store. Choose another address.';

  @override
  String get blockerMinQtyRequired =>
      'Some items are below their minimum quantity. Fix them to continue.';

  @override
  String get blockerCouponNotEligible =>
      'Your coupon no longer applies. Remove it or add items to continue.';

  @override
  String get blockerCouponExpired =>
      'Your coupon has expired. Remove it to continue.';

  @override
  String get blockerCouponInvalid =>
      'Your coupon isn\'t valid any more. Remove it to continue.';

  @override
  String get blockerCouponUsed =>
      'You\'ve already used this coupon. Remove it to continue.';

  @override
  String get couponFirstOrderOnly => 'Only for your first order';

  @override
  String get couponNoEligibleItems =>
      'No items in your cart qualify for this coupon';

  @override
  String get couponWrongStore => 'Not valid at this store';

  @override
  String get couponAppliedBadge => 'Applied';

  @override
  String couponExpiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String priceChangedDetail(String before, String after) {
    return 'Your total changed from $before to $after. Please check the updated bill.';
  }

  @override
  String stockOutDetail(String name) {
    return '$name is now out of stock.';
  }

  @override
  String stockOnlyDetail(int count, String name) {
    return 'Only $count of $name can be ordered now.';
  }

  @override
  String minQtyRequiredFor(int count, String name) {
    return 'You need to order at least $count of $name.';
  }

  @override
  String get pendingOrderTitle => 'An order is waiting for payment';

  @override
  String get pendingOrderBody =>
      'Finish or cancel the payment for that order before placing a new one.';

  @override
  String get pendingOrderAction => 'Go to that order';

  @override
  String pendingPaymentBanner(String number) {
    return 'Order $number is waiting for payment';
  }

  @override
  String get pendingPaymentAction => 'Pay now';

  @override
  String arrivingBy(String time) {
    return 'Arriving by $time';
  }

  @override
  String get paymentStatusUnchecked =>
      'We couldn\'t check this order\'s payment status, so payment can\'t be retried yet.';

  @override
  String get checkAgain => 'Check again';

  @override
  String get checkingPayment => 'Checking the payment status…';

  @override
  String get myOrders => 'My orders';

  @override
  String get ordersActive => 'Active orders';

  @override
  String get ordersPast => 'Past orders';

  @override
  String get ordersEmpty =>
      'You haven\'t placed an order yet. Your orders will show up here.';

  @override
  String get ordersLoadMoreFailed => 'Couldn\'t load more orders.';

  @override
  String orderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String orderMoreProductsTile(int count) {
    return '+$count';
  }

  @override
  String orderMoreProductsSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more products',
      one: 'and 1 more product',
    );
    return '$_temp0';
  }

  @override
  String orderPlacedOn(String date) {
    return 'Placed on $date';
  }

  @override
  String get orderStatusPaymentPending => 'Completing payment…';

  @override
  String get orderStatusPlaced => 'Order placed';

  @override
  String get orderStatusAccepted => 'Order confirmed';

  @override
  String get orderStatusPacking => 'Packing your order';

  @override
  String get orderStatusPacked => 'Packed, rider on the way to store';

  @override
  String get orderStatusOutForDelivery => 'On the way';

  @override
  String get orderStatusDelivered => 'Delivered';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get orderStatusPaymentFailed => 'Payment failed';

  @override
  String get orderStatusDeliveryFailed => 'Delivery unsuccessful';

  @override
  String get orderStatusUnknown => 'Status unavailable';

  @override
  String orderTitle(String number) {
    return 'Order $number';
  }

  @override
  String get orderStageConfirmed => 'Confirmed';

  @override
  String get orderStagePacking => 'Packing';

  @override
  String get orderStageOnTheWay => 'On the way';

  @override
  String get orderStagePlaced => 'Placed';

  @override
  String get orderStageDelivered => 'Delivered';

  @override
  String get orderTimelineTitle => 'Order status';

  @override
  String get orderStepDone => 'done';

  @override
  String get orderStepCurrent => 'current';

  @override
  String get orderStepUpcoming => 'upcoming';

  @override
  String get orderItemsTitle => 'Items';

  @override
  String orderLineQuantity(int quantity, String price) {
    return '$quantity × $price';
  }

  @override
  String get orderPaymentTitle => 'Payment';

  @override
  String get paymentMethodOnline => 'Paid online';

  @override
  String get paymentMethodCod => 'Cash on delivery';

  @override
  String get paymentStatusPending => 'Payment not completed';

  @override
  String get paymentStatusPaid => 'Paid';

  @override
  String get paymentStatusFailed => 'Payment failed';

  @override
  String get paymentStatusRefundPending => 'Refund initiated';

  @override
  String get paymentStatusRefunded => 'Refunded';

  @override
  String get paymentStatusPartiallyRefunded => 'Partly refunded';

  @override
  String get paymentStatusCodPending => 'Pay on delivery';

  @override
  String get paymentStatusCodCollected => 'Paid on delivery';

  @override
  String get noPaymentTaken => 'No payment was taken for this order.';

  @override
  String get nothingToPay => 'Nothing to pay for this order.';

  @override
  String refundInProgress(String amount) {
    return 'Refund of $amount initiated. It reaches your original payment method in 5–7 working days.';
  }

  @override
  String refundCompleted(String amount) {
    return '$amount refunded to your original payment method.';
  }

  @override
  String refundFailedNote(String amount) {
    return 'Your refund of $amount is delayed. Our team is on it; contact support if you need help.';
  }

  @override
  String refundedOn(String date) {
    return 'Refunded on $date';
  }

  @override
  String get orderDeliveryTo => 'Delivery address';

  @override
  String orderArrivingBy(String time) {
    return 'Arriving by $time';
  }

  @override
  String get activeOrderTrack => 'Track';

  @override
  String get activeOrderDetails => 'Details';

  @override
  String get activeOrderOtpReady => 'Delivery OTP ready';

  @override
  String get activeOrderDeliveryFailedBody =>
      'We couldn\'t deliver it. See what happens next.';

  @override
  String activeOrderMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more orders in progress',
      one: '+1 more order in progress',
    );
    return '$_temp0';
  }

  @override
  String get activeOrderSeeAll => 'See all';

  @override
  String activeOrderSemantics(String summary, String destination) {
    return '$summary. Opens $destination.';
  }

  @override
  String get activeOrderOpensTracking => 'tracking';

  @override
  String get activeOrderOpensDetails => 'the order details';

  @override
  String get orderAwaitingPayment => 'This order is waiting for payment.';

  @override
  String get completePayment => 'Complete payment';

  @override
  String get downloadInvoice => 'Download invoice';

  @override
  String get invoiceOpenFailed =>
      'Couldn\'t open the invoice. Install a PDF viewer or browser and try again.';

  @override
  String get reorder => 'Order again';

  @override
  String get reorderAllAdded => 'Items added to your cart.';

  @override
  String get reorderNothingAdded =>
      'None of these items can be ordered right now.';

  @override
  String get reorderSomeUnavailableTitle => 'Some items were not added';

  @override
  String reorderOutOfStock(String name) {
    return '$name is out of stock';
  }

  @override
  String reorderDiscontinued(String name) {
    return '$name is no longer sold';
  }

  @override
  String reorderBelowMinimum(String name) {
    return '$name wasn\'t added: it now has a higher minimum order quantity';
  }

  @override
  String reorderReduced(int count, String name) {
    return 'Only $count of $name added';
  }

  @override
  String get cannotCancelTitle => 'Need to cancel?';

  @override
  String get cannotCancelBody =>
      'Your order is already being packed, so it can no longer be cancelled in the app. Contact support for help.';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get cancelSheetTitle => 'Why are you cancelling?';

  @override
  String get cancelReasonOrderedByMistake => 'Ordered by mistake';

  @override
  String get cancelReasonChangedMind => 'Changed my mind';

  @override
  String get cancelReasonDeliveryTooSlow => 'Delivery is taking too long';

  @override
  String get cancelReasonChangePaymentMethod =>
      'Want to change the payment method';

  @override
  String get cancelReasonPaymentProblem => 'Problem with the payment';

  @override
  String get cancelReasonOther => 'Other';

  @override
  String cancelRefundOnline(String amount) {
    return 'You will get a full refund of $amount to your original payment method in 5–7 working days.';
  }

  @override
  String get cancelRefundCod => 'Nothing is due for a cash-on-delivery order.';

  @override
  String get cancelRefundUnpaid =>
      'No payment was taken for this order, so there is nothing to refund.';

  @override
  String get cancelConfirmAction => 'Cancel order';

  @override
  String get cancelChooseReason => 'Choose a reason to continue.';

  @override
  String orderStoreName(String store) {
    return 'From $store';
  }

  @override
  String couponUsed(String code) {
    return 'Coupon $code';
  }

  @override
  String trackingEtaMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Arriving in $minutes mins',
      one: 'Arriving in 1 min',
    );
    return '$_temp0';
  }

  @override
  String get trackingArrivingNow => 'Arriving any moment';

  @override
  String get trackingLive => 'Live';

  @override
  String trackingUpdatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String trackingStale(String time) {
    return 'Can’t update right now. Last update $time. Pull down to try again.';
  }

  @override
  String get trackingLateOnTheWay =>
      'Running a little late. Your rider is on the way.';

  @override
  String get trackingLatePreparing =>
      'Taking a little longer than planned. Your order is being prepared.';

  @override
  String get trackingGetHelp => 'Get help';

  @override
  String get trackingOtpAtDoorTitle =>
      'Your rider is at the door. Delivery OTP';

  @override
  String trackingRiderUpdated(String when) {
    return 'Location updated $when';
  }

  @override
  String get trackingJustNow => 'just now';

  @override
  String trackingMinutesAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String trackingAtTime(String time) {
    return 'at $time';
  }

  @override
  String trackingDeliveredAt(String time) {
    return 'Delivered at $time';
  }

  @override
  String get trackingCancelledBody =>
      'This order was cancelled. See the order details for any refund.';

  @override
  String get trackingRateOrder => 'Rate your order';

  @override
  String get trackingRiderAssigning => 'Assigning a delivery partner…';

  @override
  String get trackingRiderLabel => 'Your delivery partner';

  @override
  String trackingCallRider(String name) {
    return 'Call $name';
  }

  @override
  String get trackingOtpTitle => 'Delivery OTP';

  @override
  String get trackingOtpHint =>
      'Share this with your rider at the door, only when you receive your order.';

  @override
  String get trackingMapStore => 'Store';

  @override
  String get trackingMapHome => 'You';

  @override
  String trackingMapSemantics(int percent) {
    return 'The rider is $percent percent of the way to you.';
  }

  @override
  String get trackingViewDetails => 'Order details';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty =>
      'No notifications yet. Order updates and offers will show up here.';

  @override
  String get notificationUnread => 'Unread';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String notificationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String get notificationsLoadMoreFailed =>
      'Couldn\'t load more notifications.';

  @override
  String orderLineUnavailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units were unavailable and are not charged',
      one: '1 unit was unavailable and is not charged',
    );
    return '$_temp0';
  }

  @override
  String get orderCancelledTitle => 'Why this order was cancelled';

  @override
  String trackingOtpSemantics(String digits) {
    return 'Delivery OTP $digits';
  }

  @override
  String get rateOrderTitle => 'Rate your order';

  @override
  String get rateOrderQuestion => 'How was your order?';

  @override
  String get rateTagsPositive => 'What went well?';

  @override
  String get rateTagsNegative => 'What went wrong?';

  @override
  String get rateRiderQuestion => 'Rate your delivery partner';

  @override
  String get rateRiderOptional => 'Optional';

  @override
  String get rateCommentLabel => 'Tell us more';

  @override
  String get rateCommentHint => 'Anything we should know? (optional)';

  @override
  String get rateChooseStars => 'Pick a star rating to submit.';

  @override
  String get rateSubmit => 'Submit';

  @override
  String rateStars(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: '$stars stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get rateTagOnTime => 'On time';

  @override
  String get rateTagWellPacked => 'Well packed';

  @override
  String get rateTagFresh => 'Fresh products';

  @override
  String get rateTagPoliteRider => 'Polite delivery partner';

  @override
  String get rateTagLate => 'Late delivery';

  @override
  String get rateTagDamaged => 'Damaged items';

  @override
  String get rateTagMissing => 'Missing items';

  @override
  String get rateTagRudeRider => 'Rude delivery partner';

  @override
  String get ratingThanks => 'Thanks for your feedback!';

  @override
  String ratedOrder(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: 'You rated this order $stars stars',
      one: 'You rated this order 1 star',
    );
    return '$_temp0';
  }

  @override
  String ratedRider(int stars) {
    String _temp0 = intl.Intl.pluralLogic(
      stars,
      locale: localeName,
      other: 'You rated the delivery partner $stars stars',
      one: 'You rated the delivery partner 1 star',
    );
    return '$_temp0';
  }

  @override
  String get helpTitle => 'Help & support';

  @override
  String get helpWithOrder => 'Get help with an order';

  @override
  String get helpWithOrderSubtitle =>
      'Missing, damaged or wrong items, refunds and more';

  @override
  String get helpWithThisOrder => 'Get help with this order';

  @override
  String get myTickets => 'My tickets';

  @override
  String get callSupport => 'Call support';

  @override
  String get helpComingSoon => 'Support is coming soon to the app.';

  @override
  String get faqTitle => 'Frequently asked questions';

  @override
  String get faqEmpty => 'No FAQs yet.';

  @override
  String get newTicket => 'New ticket';

  @override
  String get ticketsEmpty => 'You have no support tickets.';

  @override
  String get ticketCreated => 'Ticket created. We\'ll reply here soon.';

  @override
  String get ticketOrderLabel => 'Order';

  @override
  String get ticketChooseOrder => 'Choose an order (optional)';

  @override
  String get ticketRemoveOrder => 'Remove order';

  @override
  String get ticketIssueLabel => 'What\'s the issue?';

  @override
  String get ticketChooseIssue => 'Choose an issue type.';

  @override
  String get ticketMessageLabel => 'Describe the issue';

  @override
  String get ticketMessageHint => 'Tell us what happened';

  @override
  String ticketMessageTooShort(int min) {
    return 'Please write at least $min characters.';
  }

  @override
  String get ticketSubmit => 'Create ticket';

  @override
  String get ticketClosedNote =>
      'This ticket is closed. Create a new ticket if you still need help.';

  @override
  String get ticketYou => 'You';

  @override
  String get ticketSupport => 'Jivo support';

  @override
  String get ticketReplyHint => 'Write a reply';

  @override
  String get ticketSend => 'Send';

  @override
  String get ticketAddPhoto => 'Add photo';

  @override
  String ticketPhotosHint(int max) {
    return 'Photos (optional, up to $max)';
  }

  @override
  String get ticketPhotoCamera => 'Take a photo';

  @override
  String get ticketPhotoGallery => 'Choose from gallery';

  @override
  String ticketPhotoRemove(int number) {
    return 'Remove photo $number';
  }

  @override
  String ticketPhotoOpen(int number) {
    return 'Photo $number';
  }

  @override
  String get ticketPhotoUnavailable =>
      'Photo unavailable. Pull down to refresh.';

  @override
  String get ticketPhotoUnsupported =>
      'This file type isn\'t supported. Choose a JPEG, PNG or WebP photo.';

  @override
  String ticketPhotoTooLarge(int mb) {
    return 'This photo is larger than $mb MB. Choose a smaller one.';
  }

  @override
  String ticketPhotoTooMany(int max) {
    return 'You can add up to $max photos to a message.';
  }

  @override
  String get ticketPhotoRejectedSize =>
      'This photo is too large to upload. Try a smaller photo or a screenshot of it.';

  @override
  String get ticketPhotoPickFailed =>
      'Couldn\'t open the camera or gallery. Check the app\'s permissions and try again.';

  @override
  String get ticketPhotosMessage => 'Photos of the issue';

  @override
  String ticketPhotosNotAdded(String reason) {
    return 'Ticket created, but the photos weren\'t added. $reason You can add them from the ticket.';
  }

  @override
  String get ticketMissingItems => 'Missing items';

  @override
  String get ticketDamagedItems => 'Damaged items';

  @override
  String get ticketWrongItems => 'Wrong items';

  @override
  String get ticketLateDelivery => 'Late delivery';

  @override
  String get ticketPaymentRefund => 'Payment or refund';

  @override
  String get ticketAccount => 'My account';

  @override
  String get ticketOther => 'Something else';

  @override
  String get ticketStatusOpen => 'Open';

  @override
  String get ticketStatusInProgress => 'In progress';

  @override
  String get ticketStatusResolved => 'Resolved';

  @override
  String get ticketStatusClosed => 'Closed';

  @override
  String get aboutJivo => 'About Jivo';

  @override
  String get cmsPageEmpty => 'This page has no content yet.';

  @override
  String cmsUpdatedOn(String date) {
    return 'Last updated $date';
  }

  @override
  String get cmsPageUnavailable =>
      'This page isn\'t available in the app right now. You can read it in your browser.';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get onlinePaymentUnavailable =>
      'Payment service is unavailable right now. Try again, or choose Cash on Delivery.';

  @override
  String get deliveryStagePickedUpTitle => 'Order picked up';

  @override
  String get deliveryStagePickedUpBody =>
      'Your rider has your order and is on the way.';

  @override
  String get deliveryStageArrivingTitle => 'Rider is arriving';

  @override
  String get deliveryStageArrivingBody =>
      'Your rider has reached your location. Keep your delivery OTP ready.';

  @override
  String get deliveryStageFailedTitle => 'Delivery failed';

  @override
  String get deliveryStageFailedBody =>
      'We couldn\'t deliver your order. The items are going back to the store.';

  @override
  String get deliveryStageReturnedTitle => 'Order returned';

  @override
  String get deliveryStageReturnedBody => 'Your items are back at the store.';

  @override
  String get refundNoteStarted =>
      'Your refund has started. It goes back to your original payment method.';

  @override
  String refundNoteDone(String amount) {
    return '$amount refunded to your original payment method.';
  }

  @override
  String codPayRiderTitle(String amount) {
    return 'Pay $amount to the rider';
  }

  @override
  String get codPayRiderHint =>
      'Cash on delivery. Pay by cash or UPI when your order arrives.';

  @override
  String addressMoreOptions(String label) {
    return 'More options for $label';
  }

  @override
  String get vegShort => 'Veg';

  @override
  String get nonVegShort => 'Non-veg';

  @override
  String get cartUpdating => 'Updating…';

  @override
  String get priceChangedNoticeTitle => 'Your total changed';

  @override
  String priceChangedNoticeBody(String before, String after) {
    return 'from $before to $after. Check the bill below, then pay.';
  }

  @override
  String removedFromCart(String name) {
    return 'Removed $name';
  }

  @override
  String get undo => 'Undo';

  @override
  String unsuppliedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items couldn\'t be supplied',
      one: '1 item couldn\'t be supplied',
    );
    return '$_temp0';
  }

  @override
  String unsuppliedLine(String name, int missing, int ordered) {
    return '$name: $missing of $ordered';
  }

  @override
  String unsuppliedMore(int count) {
    return 'and $count more';
  }

  @override
  String unsuppliedRefundPending(String amount) {
    return '$amount is being refunded to your original payment method.';
  }

  @override
  String refundUnsuppliedCompleted(String amount) {
    return '$amount refunded for items the store couldn\'t supply.';
  }

  @override
  String refundUnsuppliedInProgress(String amount) {
    return 'Refund of $amount for items the store couldn\'t supply has started. It reaches your original payment method in 5–7 working days.';
  }

  @override
  String get ticketNewReply => 'New reply';

  @override
  String charactersUsed(int used, int max) {
    return '$used of $max characters used';
  }

  @override
  String ratedOutOfFive(int stars) {
    return 'Rated $stars out of 5';
  }

  @override
  String get detectingLocation =>
      'Finding your location… This can take a few seconds.';

  @override
  String bannerSemanticsOf(String title, int index, int count) {
    return 'Offer: $title, banner $index of $count';
  }

  @override
  String get pushChannelOrdersName => 'Order updates';

  @override
  String get pushChannelOrdersDescription =>
      'Order status, delivery and support replies';

  @override
  String get pushChannelGeneralName => 'Offers and news';

  @override
  String get pushChannelGeneralDescription =>
      'Offers, new products and other messages from Jivo';

  @override
  String trackingUpdatedAgo(String ago) {
    return 'Updated $ago';
  }

  @override
  String trackingLiveUpdatedAgo(String ago) {
    return 'Updated $ago';
  }

  @override
  String trackingSecondsAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sec ago',
      one: '1 sec ago',
    );
    return '$_temp0';
  }

  @override
  String trackingRiderStale(String ago) {
    return 'Rider\'s location last updated $ago';
  }

  @override
  String get trackingRiderNoFix => 'Waiting for the rider\'s location';

  @override
  String trackingStaleAgo(String ago) {
    return 'Can’t update right now. Last update $ago. Pull down to try again.';
  }

  @override
  String trackingDistanceKm(String km) {
    return '$km km away';
  }

  @override
  String trackingDistanceM(int m) {
    return '$m m away';
  }

  @override
  String get trackingVehicleBicycle => 'Bicycle';

  @override
  String get trackingVehicleEBike => 'E-bike';

  @override
  String get trackingVehicleMotorbike => 'Motorbike';

  @override
  String get trackingVehicleScooter => 'Scooter';

  @override
  String get trackingProgressTitle => 'Order progress';

  @override
  String get trackStepConfirmed => 'Order confirmed';

  @override
  String get trackStepPreparing => 'Preparing your order';

  @override
  String get trackStepPacked => 'Packed';

  @override
  String get trackStepRiderAssigned => 'Rider assigned';

  @override
  String get trackStepPickedUp => 'Picked up';

  @override
  String get trackStepOnTheWay => 'On the way';

  @override
  String get trackStepArriving => 'Arriving';

  @override
  String get trackStepDelivered => 'Delivered';

  @override
  String trackStepDoneSemantics(String step) {
    return '$step, done';
  }

  @override
  String trackStepCurrentSemantics(String step) {
    return '$step, current step';
  }

  @override
  String trackStepPendingSemantics(String step) {
    return '$step, not yet';
  }

  @override
  String get trackingRecenter => 'Show the whole route';

  @override
  String get trackingMapNotLive => 'Location not live';

  @override
  String get trackingHelp => 'Need help with this order?';

  @override
  String trackingRiderWithVehicle(String vehicle) {
    return 'Your delivery partner · $vehicle';
  }
}
