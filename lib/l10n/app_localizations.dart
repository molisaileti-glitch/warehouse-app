import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw')
  ];

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Track every item'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Add inventory, see stock levels at a glance, and get low-stock alerts automatically.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Works without internet'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Record deliveries, counts, and movements offline. Everything syncs automatically once you\'re back online.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Built for your whole team'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Owners manage warehouses and staff. Managers track inventory. Workers record stock movements.'**
  String get onboardingDesc3;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInTitle;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @newOwnerPrompt.
  ///
  /// In en, this message translates to:
  /// **'New owner? Create an account'**
  String get newOwnerPrompt;

  /// No description provided for @accessLevelHint.
  ///
  /// In en, this message translates to:
  /// **'Your access level is set by your administrator.'**
  String get accessLevelHint;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get validationPasswordTooShort;

  /// No description provided for @createOwnerAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Owner Account'**
  String get createOwnerAccount;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your business details to start managing your warehouse and team.'**
  String get registerSubtitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @loadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get loadingTitle;

  /// No description provided for @loadingDescription.
  ///
  /// In en, this message translates to:
  /// **'We are processing your request.'**
  String get loadingDescription;

  /// No description provided for @registrationConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Registration'**
  String get registrationConfirmTitle;

  /// No description provided for @registrationConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Please review your details. Do you want to submit this registration now?'**
  String get registrationConfirmMessage;

  /// No description provided for @registrationSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registrationSuccessTitle;

  /// No description provided for @registrationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created. You can now sign in with your login credentials.'**
  String get registrationSuccessMessage;

  /// No description provided for @registrationErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationErrorTitle;

  /// No description provided for @registrationErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not create your account. Please review your details and try again.'**
  String get registrationErrorMessage;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @enterBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Enter your business name'**
  String get enterBusinessName;

  /// No description provided for @businessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get businessType;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @selectRegion.
  ///
  /// In en, this message translates to:
  /// **'Select a region'**
  String get selectRegion;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @enterAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter an address'**
  String get enterAddress;

  /// No description provided for @registrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get registrationNumber;

  /// No description provided for @enterRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a registration number'**
  String get enterRegistrationNumber;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get enterPhoneNumber;

  /// No description provided for @businessEmail.
  ///
  /// In en, this message translates to:
  /// **'Business email'**
  String get businessEmail;

  /// No description provided for @tinNumber.
  ///
  /// In en, this message translates to:
  /// **'TIN number'**
  String get tinNumber;

  /// No description provided for @enterTinNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a TIN number'**
  String get enterTinNumber;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @enterWebsiteUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a website URL'**
  String get enterWebsiteUrl;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get contactName;

  /// No description provided for @enterContactName.
  ///
  /// In en, this message translates to:
  /// **'Enter a contact name'**
  String get enterContactName;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhone;

  /// No description provided for @enterContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a contact phone number'**
  String get enterContactPhone;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact email'**
  String get contactEmail;

  /// No description provided for @enterContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a contact email'**
  String get enterContactEmail;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact title'**
  String get contactTitle;

  /// No description provided for @enterJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a job title'**
  String get enterJobTitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @selectRegionError.
  ///
  /// In en, this message translates to:
  /// **'Please select a region'**
  String get selectRegionError;

  /// No description provided for @couldNotLoadRegions.
  ///
  /// In en, this message translates to:
  /// **'Could not load regions'**
  String get couldNotLoadRegions;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @howToUseApp.
  ///
  /// In en, this message translates to:
  /// **'How to use this app'**
  String get howToUseApp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessageOwner.
  ///
  /// In en, this message translates to:
  /// **'Pending changes will sync when you next connect.'**
  String get signOutConfirmMessageOwner;

  /// No description provided for @signOutConfirmMessageWorker.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out.'**
  String get signOutConfirmMessageWorker;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @myTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get myTasks;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back 👋'**
  String get welcomeBack;

  /// No description provided for @ownerOverview.
  ///
  /// In en, this message translates to:
  /// **'Owner Overview'**
  String get ownerOverview;

  /// No description provided for @totalWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Total Warehouses'**
  String get totalWarehouses;

  /// No description provided for @activeWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Active Warehouses'**
  String get activeWarehouses;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending Sync'**
  String get pendingSync;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @createWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Create Warehouse'**
  String get createWarehouse;

  /// No description provided for @addWarehouseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a new warehouse location'**
  String get addWarehouseSubtitle;

  /// No description provided for @viewWorkers.
  ///
  /// In en, this message translates to:
  /// **'View Workers'**
  String get viewWorkers;

  /// No description provided for @seeStaffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See staff assigned to each warehouse'**
  String get seeStaffSubtitle;

  /// No description provided for @viewAnalytics.
  ///
  /// In en, this message translates to:
  /// **'View Analytics'**
  String get viewAnalytics;

  /// No description provided for @stockTrendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stock trends and movement reports'**
  String get stockTrendsSubtitle;

  /// No description provided for @forceSync.
  ///
  /// In en, this message translates to:
  /// **'Force Sync'**
  String get forceSync;

  /// No description provided for @pushPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push all pending changes now'**
  String get pushPendingSubtitle;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// Summary of sync operation showing pushed and pulled records count
  ///
  /// In en, this message translates to:
  /// **'Synced: {pushed} pushed, {pulled} pulled'**
  String syncedSummary(String pushed, String pulled);

  /// No description provided for @notAssignedWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Not assigned to a warehouse'**
  String get notAssignedWarehouse;

  /// No description provided for @askAdminAssignment.
  ///
  /// In en, this message translates to:
  /// **'Ask your administrator to assign you to a warehouse.'**
  String get askAdminAssignment;

  /// No description provided for @assignedWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Assigned Warehouse'**
  String get assignedWarehouse;

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'Total Items'**
  String get totalItems;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// No description provided for @recordAction.
  ///
  /// In en, this message translates to:
  /// **'Record an Action'**
  String get recordAction;

  /// No description provided for @recordDelivery.
  ///
  /// In en, this message translates to:
  /// **'Record Delivery'**
  String get recordDelivery;

  /// No description provided for @incomingGoodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming goods received'**
  String get incomingGoodsSubtitle;

  /// No description provided for @stockCount.
  ///
  /// In en, this message translates to:
  /// **'Stock Count'**
  String get stockCount;

  /// No description provided for @countItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Count items on the shelf'**
  String get countItemsSubtitle;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @correctDiscrepanciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Correct stock discrepancies'**
  String get correctDiscrepanciesSubtitle;

  /// No description provided for @lowStockAlerts.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Low Stock Alerts'**
  String get lowStockAlerts;

  /// No description provided for @workerDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Worker Dashboard'**
  String get workerDashboardTitle;

  /// No description provided for @workerProfileNoSync.
  ///
  /// In en, this message translates to:
  /// **'Your profile hasn\'t synced yet. Once the backend assigns you to a warehouse, your tasks will appear here.'**
  String get workerProfileNoSync;

  /// No description provided for @errorInvalidDetails.
  ///
  /// In en, this message translates to:
  /// **'Invalid details — check your information'**
  String get errorInvalidDetails;

  /// No description provided for @errorIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get errorIncorrectCredentials;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Account disabled — contact your administrator'**
  String get errorAccountDisabled;

  /// No description provided for @errorEmailExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get errorEmailExists;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — try again later'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error — check your connection'**
  String get errorNetworkError;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @noReceiptYet.
  ///
  /// In en, this message translates to:
  /// **'No receipt yet'**
  String get noReceiptYet;

  /// No description provided for @completeReceivingBeforeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Complete a receiving session before viewing the receipt.'**
  String get completeReceivingBeforeReceipt;

  /// No description provided for @startReceiving.
  ///
  /// In en, this message translates to:
  /// **'Start Receiving'**
  String get startReceiving;

  /// No description provided for @warehouseReceipt.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Receipt'**
  String get warehouseReceipt;

  /// No description provided for @receiptLanguage.
  ///
  /// In en, this message translates to:
  /// **'Receipt language'**
  String get receiptLanguage;

  /// No description provided for @receiptEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get receiptEnglish;

  /// No description provided for @receiptSwahili.
  ///
  /// In en, this message translates to:
  /// **'Swahili'**
  String get receiptSwahili;

  /// No description provided for @receiptFarmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get receiptFarmer;

  /// No description provided for @receiptCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get receiptCrop;

  /// No description provided for @receiptWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get receiptWarehouse;

  /// No description provided for @receiptBags.
  ///
  /// In en, this message translates to:
  /// **'Bags'**
  String get receiptBags;

  /// No description provided for @receiptGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get receiptGross;

  /// No description provided for @receiptTare.
  ///
  /// In en, this message translates to:
  /// **'Tare'**
  String get receiptTare;

  /// No description provided for @receiptNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get receiptNet;

  /// No description provided for @receiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get receiptDate;

  /// No description provided for @receiptReceivedBy.
  ///
  /// In en, this message translates to:
  /// **'Received by'**
  String get receiptReceivedBy;

  /// No description provided for @newReceiving.
  ///
  /// In en, this message translates to:
  /// **'New Receiving'**
  String get newReceiving;

  /// No description provided for @generateReceipt.
  ///
  /// In en, this message translates to:
  /// **'Generate Receipt'**
  String get generateReceipt;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @selectPrinter.
  ///
  /// In en, this message translates to:
  /// **'Select Printer'**
  String get selectPrinter;

  /// No description provided for @availablePrinters.
  ///
  /// In en, this message translates to:
  /// **'Available Printers'**
  String get availablePrinters;

  /// No description provided for @refreshPrinters.
  ///
  /// In en, this message translates to:
  /// **'Refresh printers'**
  String get refreshPrinters;

  /// No description provided for @scanningPrinters.
  ///
  /// In en, this message translates to:
  /// **'Scanning printers...'**
  String get scanningPrinters;

  /// No description provided for @noPrintersFound.
  ///
  /// In en, this message translates to:
  /// **'No printers found'**
  String get noPrintersFound;

  /// No description provided for @turnOnPrinterAndRefresh.
  ///
  /// In en, this message translates to:
  /// **'Turn on the printer, then refresh.'**
  String get turnOnPrinterAndRefresh;

  /// No description provided for @noPairedPrinters.
  ///
  /// In en, this message translates to:
  /// **'No paired printers'**
  String get noPairedPrinters;

  /// No description provided for @pairPrinterInSettings.
  ///
  /// In en, this message translates to:
  /// **'Pair your thermal printer in Android Bluetooth settings first.'**
  String get pairPrinterInSettings;

  /// No description provided for @printingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Printing Receipt'**
  String get printingReceipt;

  /// No description provided for @printingReceiptDescription.
  ///
  /// In en, this message translates to:
  /// **'Sending this receipt to the selected printer.'**
  String get printingReceiptDescription;

  /// No description provided for @receiptPrinted.
  ///
  /// In en, this message translates to:
  /// **'Receipt Printed'**
  String get receiptPrinted;

  /// No description provided for @receiptPrintedDescription.
  ///
  /// In en, this message translates to:
  /// **'The receipt was sent to the printer successfully.'**
  String get receiptPrintedDescription;

  /// No description provided for @printerError.
  ///
  /// In en, this message translates to:
  /// **'Printer Error'**
  String get printerError;

  /// No description provided for @printerLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load paired printers.'**
  String get printerLoadError;

  /// No description provided for @bluetoothPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission is required to print receipts.'**
  String get bluetoothPermissionRequired;

  /// No description provided for @printOptions.
  ///
  /// In en, this message translates to:
  /// **'Print Options'**
  String get printOptions;

  /// No description provided for @printWithBagDetails.
  ///
  /// In en, this message translates to:
  /// **'With bag details'**
  String get printWithBagDetails;

  /// No description provided for @printWithoutBagDetails.
  ///
  /// In en, this message translates to:
  /// **'Without bag details'**
  String get printWithoutBagDetails;

  /// No description provided for @harvestRequestReceipt.
  ///
  /// In en, this message translates to:
  /// **'Harvest Request Receipt'**
  String get harvestRequestReceipt;

  /// No description provided for @receiptPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get receiptPhone;

  /// No description provided for @receiptCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get receiptCenter;

  /// No description provided for @receiptPackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get receiptPackaging;

  /// No description provided for @receiptTotalBags.
  ///
  /// In en, this message translates to:
  /// **'Total Bags'**
  String get receiptTotalBags;

  /// No description provided for @receiptNoBagsFound.
  ///
  /// In en, this message translates to:
  /// **'No Bags Found'**
  String get receiptNoBagsFound;

  /// No description provided for @receiptBagDetailsNotPrinted.
  ///
  /// In en, this message translates to:
  /// **'Bag Details Not Printed'**
  String get receiptBagDetailsNotPrinted;

  /// No description provided for @receiptTagNumber.
  ///
  /// In en, this message translates to:
  /// **'Tag Number'**
  String get receiptTagNumber;

  /// No description provided for @receiptMoisturePercent.
  ///
  /// In en, this message translates to:
  /// **'Moisture %'**
  String get receiptMoisturePercent;

  /// No description provided for @receiptPackagingWeight.
  ///
  /// In en, this message translates to:
  /// **'Packaging Wt'**
  String get receiptPackagingWeight;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt Number'**
  String get receiptNumber;

  /// No description provided for @receiptReceivedDate.
  ///
  /// In en, this message translates to:
  /// **'Received Date'**
  String get receiptReceivedDate;

  /// No description provided for @receiptReceivedTime.
  ///
  /// In en, this message translates to:
  /// **'Received Time'**
  String get receiptReceivedTime;

  /// No description provided for @receiptPrintDate.
  ///
  /// In en, this message translates to:
  /// **'Print Date'**
  String get receiptPrintDate;

  /// No description provided for @receiptPrintTime.
  ///
  /// In en, this message translates to:
  /// **'Print Time'**
  String get receiptPrintTime;

  /// No description provided for @receiptEnd.
  ///
  /// In en, this message translates to:
  /// **'Receipt End'**
  String get receiptEnd;

  /// No description provided for @poweredByShambabora.
  ///
  /// In en, this message translates to:
  /// **'Powered by ShambaBora'**
  String get poweredByShambabora;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
