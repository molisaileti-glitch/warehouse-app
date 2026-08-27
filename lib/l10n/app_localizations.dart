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
  /// **'Enter contact email'**
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

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @useDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Use YYYY-MM-DD'**
  String get useDateFormat;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @workers.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get workers;

  /// No description provided for @warehouses.
  ///
  /// In en, this message translates to:
  /// **'Warehouses'**
  String get warehouses;

  /// No description provided for @farmers.
  ///
  /// In en, this message translates to:
  /// **'Farmers'**
  String get farmers;

  /// No description provided for @harvest.
  ///
  /// In en, this message translates to:
  /// **'Harvest'**
  String get harvest;

  /// No description provided for @harvests.
  ///
  /// In en, this message translates to:
  /// **'Harvests'**
  String get harvests;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// No description provided for @warehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get warehouse;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @grade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get grade;

  /// No description provided for @grossWeight.
  ///
  /// In en, this message translates to:
  /// **'Gross weight'**
  String get grossWeight;

  /// No description provided for @tareWeight.
  ///
  /// In en, this message translates to:
  /// **'Tare weight'**
  String get tareWeight;

  /// No description provided for @netWeight.
  ///
  /// In en, this message translates to:
  /// **'Net weight'**
  String get netWeight;

  /// No description provided for @moisture.
  ///
  /// In en, this message translates to:
  /// **'Moisture'**
  String get moisture;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @worker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get worker;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @father.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get father;

  /// No description provided for @mother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get mother;

  /// No description provided for @spouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get spouse;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @brother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get brother;

  /// No description provided for @sister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get sister;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @errorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithDetails(String error);

  /// No description provided for @welcomeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBackTitle;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @sendingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Sending Instructions'**
  String get sendingInstructions;

  /// No description provided for @checkingEmail.
  ///
  /// In en, this message translates to:
  /// **'Checking this email address.'**
  String get checkingEmail;

  /// No description provided for @sendResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email.'**
  String get sendResetFailed;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check Your Email'**
  String get checkYourEmail;

  /// No description provided for @resetInstructionsSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset instructions have been sent to your email.'**
  String get resetInstructionsSent;

  /// No description provided for @sendInstructions.
  ///
  /// In en, this message translates to:
  /// **'Send Instructions'**
  String get sendInstructions;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @resettingPassword.
  ///
  /// In en, this message translates to:
  /// **'Resetting Password'**
  String get resettingPassword;

  /// No description provided for @savingNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Saving your new password.'**
  String get savingNewPassword;

  /// No description provided for @resetPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset password.'**
  String get resetPasswordFailed;

  /// No description provided for @passwordReset.
  ///
  /// In en, this message translates to:
  /// **'Password Reset'**
  String get passwordReset;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password has been reset successfully.'**
  String get passwordResetSuccess;

  /// No description provided for @resetToken.
  ///
  /// In en, this message translates to:
  /// **'Reset token'**
  String get resetToken;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @changingPassword.
  ///
  /// In en, this message translates to:
  /// **'Changing Password'**
  String get changingPassword;

  /// No description provided for @updatingPasswordSecurely.
  ///
  /// In en, this message translates to:
  /// **'Updating your password securely.'**
  String get updatingPasswordSecurely;

  /// No description provided for @changePasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password.'**
  String get changePasswordFailed;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password Changed'**
  String get passwordChanged;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChangedSuccess;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @selectBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Select business type'**
  String get selectBusinessType;

  /// No description provided for @enterBusinessEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter business email'**
  String get enterBusinessEmail;

  /// No description provided for @preparingRegistrationRegions.
  ///
  /// In en, this message translates to:
  /// **'Preparing registration regions...'**
  String get preparingRegistrationRegions;

  /// No description provided for @preparingDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing Data'**
  String get preparingDataTitle;

  /// No description provided for @preparingDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Downloading crops and location data needed before using the app.'**
  String get preparingDataDescription;

  /// No description provided for @dataReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Ready'**
  String get dataReadyTitle;

  /// No description provided for @dataReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'Required data has been prepared. You can continue to the dashboard.'**
  String get dataReadyDescription;

  /// No description provided for @dataPreparationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparation Failed'**
  String get dataPreparationFailedTitle;

  /// No description provided for @dataPreparationFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Some required data could not be downloaded. Check your internet connection and try again.'**
  String get dataPreparationFailedDescription;

  /// No description provided for @dataPreparationMissingDescription.
  ///
  /// In en, this message translates to:
  /// **'Still missing: {items}. Check your internet connection and tap Retry.'**
  String dataPreparationMissingDescription(String items);

  /// No description provided for @crops.
  ///
  /// In en, this message translates to:
  /// **'Crops'**
  String get crops;

  /// No description provided for @regions.
  ///
  /// In en, this message translates to:
  /// **'Regions'**
  String get regions;

  /// No description provided for @districts.
  ///
  /// In en, this message translates to:
  /// **'Districts'**
  String get districts;

  /// No description provided for @wards.
  ///
  /// In en, this message translates to:
  /// **'Wards'**
  String get wards;

  /// No description provided for @villages.
  ///
  /// In en, this message translates to:
  /// **'Villages'**
  String get villages;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @regional.
  ///
  /// In en, this message translates to:
  /// **'Regional'**
  String get regional;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout from this device?'**
  String get logoutConfirmMessage;

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging Out'**
  String get loggingOut;

  /// No description provided for @clearingLocalSession.
  ///
  /// In en, this message translates to:
  /// **'Clearing your local session.'**
  String get clearingLocalSession;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App ver {version}'**
  String appVersion(String version);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} coming soon'**
  String comingSoon(String feature);

  /// No description provided for @featureWillBeImplementedSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature will be implemented soon.'**
  String get featureWillBeImplementedSoon;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @farmerDetails.
  ///
  /// In en, this message translates to:
  /// **'Farmer Details'**
  String get farmerDetails;

  /// No description provided for @registerFarmer.
  ///
  /// In en, this message translates to:
  /// **'Register Farmer'**
  String get registerFarmer;

  /// No description provided for @addFarmer.
  ///
  /// In en, this message translates to:
  /// **'Add farmer'**
  String get addFarmer;

  /// No description provided for @searchFarmers.
  ///
  /// In en, this message translates to:
  /// **'Search farmers...'**
  String get searchFarmers;

  /// No description provided for @noFarmersYet.
  ///
  /// In en, this message translates to:
  /// **'No farmers yet'**
  String get noFarmersYet;

  /// No description provided for @noFarmersFound.
  ///
  /// In en, this message translates to:
  /// **'No farmers found'**
  String get noFarmersFound;

  /// No description provided for @registerFarmerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register a farmer at point of contact.'**
  String get registerFarmerSubtitle;

  /// No description provided for @workerFarmersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Worker-registered farmers will appear here.'**
  String get workerFarmersSubtitle;

  /// No description provided for @farmerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Farmer not found'**
  String get farmerNotFound;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @middleName.
  ///
  /// In en, this message translates to:
  /// **'Middle name'**
  String get middleName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @idType.
  ///
  /// In en, this message translates to:
  /// **'ID type'**
  String get idType;

  /// No description provided for @idNumber.
  ///
  /// In en, this message translates to:
  /// **'ID number'**
  String get idNumber;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @mainCrop.
  ///
  /// In en, this message translates to:
  /// **'Main crop'**
  String get mainCrop;

  /// No description provided for @secondaryCrop.
  ///
  /// In en, this message translates to:
  /// **'Secondary crop'**
  String get secondaryCrop;

  /// No description provided for @selectMainCrop.
  ///
  /// In en, this message translates to:
  /// **'Select main crop'**
  String get selectMainCrop;

  /// No description provided for @selectSecondaryCrop.
  ///
  /// In en, this message translates to:
  /// **'Select secondary crop'**
  String get selectSecondaryCrop;

  /// No description provided for @amcos.
  ///
  /// In en, this message translates to:
  /// **'AMCOS'**
  String get amcos;

  /// No description provided for @selectAmcos.
  ///
  /// In en, this message translates to:
  /// **'Select AMCOS'**
  String get selectAmcos;

  /// No description provided for @memberType.
  ///
  /// In en, this message translates to:
  /// **'Member type'**
  String get memberType;

  /// No description provided for @maritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Marital status'**
  String get maritalStatus;

  /// No description provided for @amcosMemberId.
  ///
  /// In en, this message translates to:
  /// **'AMCOS member ID'**
  String get amcosMemberId;

  /// No description provided for @tumeNumber.
  ///
  /// In en, this message translates to:
  /// **'TUME number'**
  String get tumeNumber;

  /// No description provided for @ttbNumber.
  ///
  /// In en, this message translates to:
  /// **'TTB number'**
  String get ttbNumber;

  /// No description provided for @voterId.
  ///
  /// In en, this message translates to:
  /// **'Voter ID'**
  String get voterId;

  /// No description provided for @driversLicense.
  ///
  /// In en, this message translates to:
  /// **'Drivers license'**
  String get driversLicense;

  /// No description provided for @numberOfShares.
  ///
  /// In en, this message translates to:
  /// **'Number of shares'**
  String get numberOfShares;

  /// No description provided for @shares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get shares;

  /// No description provided for @dependants.
  ///
  /// In en, this message translates to:
  /// **'Dependants'**
  String get dependants;

  /// No description provided for @dependant.
  ///
  /// In en, this message translates to:
  /// **'Dependant'**
  String get dependant;

  /// No description provided for @addDependant.
  ///
  /// In en, this message translates to:
  /// **'Add Dependant'**
  String get addDependant;

  /// No description provided for @removeDependant.
  ///
  /// In en, this message translates to:
  /// **'Remove dependant'**
  String get removeDependant;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationship;

  /// No description provided for @noDependantsAdded.
  ///
  /// In en, this message translates to:
  /// **'No dependants added'**
  String get noDependantsAdded;

  /// No description provided for @noDependantsForFarmer.
  ///
  /// In en, this message translates to:
  /// **'No dependants have been added for this farmer.'**
  String get noDependantsForFarmer;

  /// No description provided for @dependantsOptional.
  ///
  /// In en, this message translates to:
  /// **'This step is optional. Dependants can also be added later.'**
  String get dependantsOptional;

  /// No description provided for @addDependantConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add this dependant to the farmer record?'**
  String get addDependantConfirm;

  /// No description provided for @addingDependant.
  ///
  /// In en, this message translates to:
  /// **'Adding Dependant'**
  String get addingDependant;

  /// No description provided for @addingDependantProgress.
  ///
  /// In en, this message translates to:
  /// **'Adding dependant...'**
  String get addingDependantProgress;

  /// No description provided for @savingDependantLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving this dependant locally.'**
  String get savingDependantLocally;

  /// No description provided for @dependantAdded.
  ///
  /// In en, this message translates to:
  /// **'Dependant Added'**
  String get dependantAdded;

  /// No description provided for @dependantAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Dependant successfully added.'**
  String get dependantAddedSuccess;

  /// No description provided for @dependantAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add dependant.'**
  String get dependantAddFailed;

  /// No description provided for @createFarmer.
  ///
  /// In en, this message translates to:
  /// **'Create Farmer'**
  String get createFarmer;

  /// No description provided for @captureFarmerDescription.
  ///
  /// In en, this message translates to:
  /// **'Capture the farmer record at point of contact.'**
  String get captureFarmerDescription;

  /// No description provided for @addDependantsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add dependants now, or leave this for later.'**
  String get addDependantsDescription;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewFarmerDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the details before creating the farmer.'**
  String get reviewFarmerDescription;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @loadingCrop.
  ///
  /// In en, this message translates to:
  /// **'Loading crop...'**
  String get loadingCrop;

  /// No description provided for @unknownCrop.
  ///
  /// In en, this message translates to:
  /// **'Unknown crop (ID {id})'**
  String unknownCrop(int id);

  /// No description provided for @connectScale.
  ///
  /// In en, this message translates to:
  /// **'Connect Scale'**
  String get connectScale;

  /// No description provided for @connectTheScale.
  ///
  /// In en, this message translates to:
  /// **'Connect the scale'**
  String get connectTheScale;

  /// No description provided for @connectScaleDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect a Bluetooth scale before measuring crops. Scan nearby devices when the scale is ready.'**
  String get connectScaleDescription;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @scanNearbyScale.
  ///
  /// In en, this message translates to:
  /// **'Scan nearby devices to find your scale.'**
  String get scanNearbyScale;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @scanDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan Devices'**
  String get scanDevices;

  /// No description provided for @availableDevices.
  ///
  /// In en, this message translates to:
  /// **'Available Devices'**
  String get availableDevices;

  /// No description provided for @refreshDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get refreshDevices;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevicesFound;

  /// No description provided for @deviceScanHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn on the scale, Bluetooth, and Location, then refresh.'**
  String get deviceScanHelp;

  /// No description provided for @bluetoothLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth and Location Required'**
  String get bluetoothLocationRequired;

  /// No description provided for @bluetoothLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'Please allow Bluetooth and Location permissions, and keep Bluetooth and Location turned on before scanning devices.'**
  String get bluetoothLocationMessage;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @unknownScale.
  ///
  /// In en, this message translates to:
  /// **'Unknown Scale'**
  String get unknownScale;

  /// No description provided for @likelyScale.
  ///
  /// In en, this message translates to:
  /// **'Likely scale - {rssi} dBm'**
  String likelyScale(int rssi);

  /// No description provided for @collectionCenter.
  ///
  /// In en, this message translates to:
  /// **'Collection center'**
  String get collectionCenter;

  /// No description provided for @warehouseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Warehouse not found'**
  String get warehouseNotFound;

  /// No description provided for @loadingWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Loading warehouse...'**
  String get loadingWarehouse;

  /// No description provided for @noCropsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No crops available'**
  String get noCropsAvailable;

  /// No description provided for @syncCropDataFirst.
  ///
  /// In en, this message translates to:
  /// **'Sync crop reference data first.'**
  String get syncCropDataFirst;

  /// No description provided for @noFarmersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No farmers available'**
  String get noFarmersAvailable;

  /// No description provided for @syncOrRegisterFarmers.
  ///
  /// In en, this message translates to:
  /// **'Sync or register farmers before receiving crops.'**
  String get syncOrRegisterFarmers;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @noMatchingFarmers.
  ///
  /// In en, this message translates to:
  /// **'No matching farmers'**
  String get noMatchingFarmers;

  /// No description provided for @selectFarmer.
  ///
  /// In en, this message translates to:
  /// **'Select a farmer.'**
  String get selectFarmer;

  /// No description provided for @selectCrop.
  ///
  /// In en, this message translates to:
  /// **'Select a crop.'**
  String get selectCrop;

  /// No description provided for @farmerNumber.
  ///
  /// In en, this message translates to:
  /// **'Farmer {id}'**
  String farmerNumber(int id);

  /// No description provided for @scale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale;

  /// No description provided for @loadingScale.
  ///
  /// In en, this message translates to:
  /// **'Loading scale...'**
  String get loadingScale;

  /// No description provided for @bag.
  ///
  /// In en, this message translates to:
  /// **'Bag'**
  String get bag;

  /// No description provided for @bagTag.
  ///
  /// In en, this message translates to:
  /// **'Bag tag'**
  String get bagTag;

  /// No description provided for @generateBagTag.
  ///
  /// In en, this message translates to:
  /// **'Generate bag tag'**
  String get generateBagTag;

  /// No description provided for @packagingWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Packaging weight (kg)'**
  String get packagingWeightKg;

  /// No description provided for @addBag.
  ///
  /// In en, this message translates to:
  /// **'Add Bag'**
  String get addBag;

  /// No description provided for @viewBags.
  ///
  /// In en, this message translates to:
  /// **'View bags'**
  String get viewBags;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get editDetails;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stable;

  /// No description provided for @unstable.
  ///
  /// In en, this message translates to:
  /// **'Unstable'**
  String get unstable;

  /// No description provided for @scaleReading.
  ///
  /// In en, this message translates to:
  /// **'Scale Reading'**
  String get scaleReading;

  /// No description provided for @connectScaleBeforeWeighing.
  ///
  /// In en, this message translates to:
  /// **'Connect scale before weighing'**
  String get connectScaleBeforeWeighing;

  /// No description provided for @selectedFarmer.
  ///
  /// In en, this message translates to:
  /// **'Selected farmer'**
  String get selectedFarmer;

  /// No description provided for @farmerDetailsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Farmer details needed'**
  String get farmerDetailsNeeded;

  /// No description provided for @farmerDetailsNeededMessage.
  ///
  /// In en, this message translates to:
  /// **'Select farmer and crop details before weighing bags.'**
  String get farmerDetailsNeededMessage;

  /// No description provided for @goToDetails.
  ///
  /// In en, this message translates to:
  /// **'Go to Details'**
  String get goToDetails;

  /// No description provided for @moistureReceiptMessage.
  ///
  /// In en, this message translates to:
  /// **'Moisture is set to {percent}%. Net weight will appear on the receipt.'**
  String moistureReceiptMessage(String percent);

  /// No description provided for @connectScaleBeforeBag.
  ///
  /// In en, this message translates to:
  /// **'Connect the scale before adding a bag.'**
  String get connectScaleBeforeBag;

  /// No description provided for @waitForStableScale.
  ///
  /// In en, this message translates to:
  /// **'Please wait until the scale reading is stable.'**
  String get waitForStableScale;

  /// No description provided for @weightGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Weight must be greater than zero.'**
  String get weightGreaterThanZero;

  /// No description provided for @packagingLessThanGross.
  ///
  /// In en, this message translates to:
  /// **'Packaging weight must be less than gross weight.'**
  String get packagingLessThanGross;

  /// No description provided for @noBagsAdded.
  ///
  /// In en, this message translates to:
  /// **'No bags added yet'**
  String get noBagsAdded;

  /// No description provided for @completeHarvest.
  ///
  /// In en, this message translates to:
  /// **'Complete Harvest'**
  String get completeHarvest;

  /// No description provided for @addBagBeforeComplete.
  ///
  /// In en, this message translates to:
  /// **'Add at least one bag before completing harvest.'**
  String get addBagBeforeComplete;

  /// No description provided for @completeHarvestConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save {count} bag(s) and generate one receipt?'**
  String completeHarvestConfirm(int count);

  /// No description provided for @savingHarvest.
  ///
  /// In en, this message translates to:
  /// **'Saving Harvest'**
  String get savingHarvest;

  /// No description provided for @savingHarvestLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving this harvest locally.'**
  String get savingHarvestLocally;

  /// No description provided for @saveHarvestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save harvest.'**
  String get saveHarvestFailed;

  /// No description provided for @harvestSaved.
  ///
  /// In en, this message translates to:
  /// **'Harvest Saved'**
  String get harvestSaved;

  /// No description provided for @harvestSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Harvest successfully saved. Receipt is ready.'**
  String get harvestSavedMessage;

  /// No description provided for @enterValidWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight'**
  String get enterValidWeight;

  /// No description provided for @cannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Cannot be negative'**
  String get cannotBeNegative;

  /// No description provided for @bagWeightSummary.
  ///
  /// In en, this message translates to:
  /// **'Gross {gross} kg - Packaging {packaging} kg'**
  String bagWeightSummary(String gross, String packaging);

  /// No description provided for @removeBag.
  ///
  /// In en, this message translates to:
  /// **'Remove bag'**
  String get removeBag;

  /// No description provided for @newHarvest.
  ///
  /// In en, this message translates to:
  /// **'New harvest'**
  String get newHarvest;

  /// No description provided for @receiveCrop.
  ///
  /// In en, this message translates to:
  /// **'Receive crop'**
  String get receiveCrop;

  /// No description provided for @searchHarvests.
  ///
  /// In en, this message translates to:
  /// **'Search harvests...'**
  String get searchHarvests;

  /// No description provided for @noHarvestsYet.
  ///
  /// In en, this message translates to:
  /// **'No harvests yet'**
  String get noHarvestsYet;

  /// No description provided for @noHarvestsFound.
  ///
  /// In en, this message translates to:
  /// **'No harvests found'**
  String get noHarvestsFound;

  /// No description provided for @newHarvestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to connect a scale and receive crops.'**
  String get newHarvestSubtitle;

  /// No description provided for @workerHarvestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Worker harvest records will appear here.'**
  String get workerHarvestsSubtitle;

  /// No description provided for @harvestDetails.
  ///
  /// In en, this message translates to:
  /// **'Harvest Details'**
  String get harvestDetails;

  /// No description provided for @harvestNotFound.
  ///
  /// In en, this message translates to:
  /// **'Harvest not found'**
  String get harvestNotFound;

  /// No description provided for @harvestRemovedLocally.
  ///
  /// In en, this message translates to:
  /// **'This record may have been removed locally.'**
  String get harvestRemovedLocally;

  /// No description provided for @chooseWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Choose Warehouse'**
  String get chooseWarehouse;

  /// No description provided for @chooseWarehouseMessage.
  ///
  /// In en, this message translates to:
  /// **'Select where this crop receiving session will be recorded.'**
  String get chooseWarehouseMessage;

  /// No description provided for @createWarehouseBeforeReceiving.
  ///
  /// In en, this message translates to:
  /// **'Create an active warehouse before receiving crops.'**
  String get createWarehouseBeforeReceiving;

  /// No description provided for @addWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Add warehouse'**
  String get addWarehouse;

  /// No description provided for @searchWarehouses.
  ///
  /// In en, this message translates to:
  /// **'Search warehouses...'**
  String get searchWarehouses;

  /// No description provided for @allWarehouses.
  ///
  /// In en, this message translates to:
  /// **'All Warehouses'**
  String get allWarehouses;

  /// No description provided for @noWarehousesFound.
  ///
  /// In en, this message translates to:
  /// **'No warehouses found'**
  String get noWarehousesFound;

  /// No description provided for @createFirstWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first warehouse.'**
  String get createFirstWarehouse;

  /// No description provided for @locationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get locationNotSet;

  /// No description provided for @createWarehouseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create {name} as a new warehouse?'**
  String createWarehouseConfirm(String name);

  /// No description provided for @creatingWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Creating Warehouse'**
  String get creatingWarehouse;

  /// No description provided for @savingWarehouseLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving this warehouse locally.'**
  String get savingWarehouseLocally;

  /// No description provided for @warehouseCreated.
  ///
  /// In en, this message translates to:
  /// **'Warehouse Created'**
  String get warehouseCreated;

  /// No description provided for @warehouseCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Warehouse successfully created.'**
  String get warehouseCreatedSuccess;

  /// No description provided for @newWarehouse.
  ///
  /// In en, this message translates to:
  /// **'New Warehouse'**
  String get newWarehouse;

  /// No description provided for @warehouseName.
  ///
  /// In en, this message translates to:
  /// **'Warehouse name'**
  String get warehouseName;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @ward.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get ward;

  /// No description provided for @village.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get village;

  /// No description provided for @gpsLocationAddress.
  ///
  /// In en, this message translates to:
  /// **'GPS location / address'**
  String get gpsLocationAddress;

  /// No description provided for @locationAutoBuilt.
  ///
  /// In en, this message translates to:
  /// **'Auto-built from region, district, ward and village'**
  String get locationAutoBuilt;

  /// No description provided for @warehouseNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Warehouse not found'**
  String get warehouseNotFoundMessage;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @assignedWorkers.
  ///
  /// In en, this message translates to:
  /// **'Assigned Workers'**
  String get assignedWorkers;

  /// No description provided for @noInventoryItems.
  ///
  /// In en, this message translates to:
  /// **'No inventory items yet.'**
  String get noInventoryItems;

  /// No description provided for @noAssignedWorkers.
  ///
  /// In en, this message translates to:
  /// **'No workers assigned to this warehouse yet.'**
  String get noAssignedWorkers;

  /// No description provided for @deleteWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Delete Warehouse'**
  String get deleteWarehouse;

  /// No description provided for @deleteWarehouseConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove {name} locally and sync the change to the server.'**
  String deleteWarehouseConfirm(String name);

  /// No description provided for @editWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Edit Warehouse'**
  String get editWarehouse;

  /// No description provided for @amcosId.
  ///
  /// In en, this message translates to:
  /// **'AMCOS ID'**
  String get amcosId;

  /// No description provided for @amcosName.
  ///
  /// In en, this message translates to:
  /// **'AMCOS name'**
  String get amcosName;

  /// No description provided for @villageId.
  ///
  /// In en, this message translates to:
  /// **'Village ID'**
  String get villageId;

  /// No description provided for @villageName.
  ///
  /// In en, this message translates to:
  /// **'Village name'**
  String get villageName;

  /// No description provided for @addWorker.
  ///
  /// In en, this message translates to:
  /// **'Add Worker'**
  String get addWorker;

  /// No description provided for @addWorkerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add worker'**
  String get addWorkerTooltip;

  /// No description provided for @noWorkersYet.
  ///
  /// In en, this message translates to:
  /// **'No workers yet'**
  String get noWorkersYet;

  /// No description provided for @createFirstWorker.
  ///
  /// In en, this message translates to:
  /// **'Use + to create your first worker account'**
  String get createFirstWorker;

  /// No description provided for @workerDetails.
  ///
  /// In en, this message translates to:
  /// **'Worker Details'**
  String get workerDetails;

  /// No description provided for @workerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Worker not found'**
  String get workerNotFound;

  /// No description provided for @editWorker.
  ///
  /// In en, this message translates to:
  /// **'Edit worker'**
  String get editWorker;

  /// No description provided for @deleteWorker.
  ///
  /// In en, this message translates to:
  /// **'Delete Worker'**
  String get deleteWorker;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @assignToWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Assign to warehouse'**
  String get assignToWarehouse;

  /// No description provided for @selectWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Select warehouse'**
  String get selectWarehouse;

  /// No description provided for @fillWorkerDetails.
  ///
  /// In en, this message translates to:
  /// **'Fill in details and assign a warehouse'**
  String get fillWorkerDetails;

  /// No description provided for @amcosDerivedFromWarehouse.
  ///
  /// In en, this message translates to:
  /// **'AMCOS is derived automatically from this selection'**
  String get amcosDerivedFromWarehouse;

  /// No description provided for @createWorkerAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Worker Account'**
  String get createWorkerAccount;

  /// No description provided for @enterWorkerName.
  ///
  /// In en, this message translates to:
  /// **'Enter worker name'**
  String get enterWorkerName;

  /// No description provided for @enterWorkerEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter worker email'**
  String get enterWorkerEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get enterPassword;

  /// No description provided for @assignWarehouseRequired.
  ///
  /// In en, this message translates to:
  /// **'Please assign a warehouse'**
  String get assignWarehouseRequired;

  /// No description provided for @assignWorkerWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Please assign this worker to a warehouse.'**
  String get assignWorkerWarehouse;

  /// No description provided for @selectedWarehouseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Selected warehouse not found. Please try again.'**
  String get selectedWarehouseNotFound;

  /// No description provided for @warehouseMissingAmcos.
  ///
  /// In en, this message translates to:
  /// **'{warehouse} has no AMCOS assigned. Please select a different warehouse.'**
  String warehouseMissingAmcos(String warehouse);

  /// No description provided for @ownerIdUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not determine owner ID. Please log out and back in.'**
  String get ownerIdUnavailable;

  /// No description provided for @createWorker.
  ///
  /// In en, this message translates to:
  /// **'Create Worker'**
  String get createWorker;

  /// No description provided for @createWorkerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create an account for {name} and assign this worker to {warehouse}?'**
  String createWorkerConfirm(String name, String warehouse);

  /// No description provided for @creatingWorker.
  ///
  /// In en, this message translates to:
  /// **'Creating Worker'**
  String get creatingWorker;

  /// No description provided for @savingWorkerLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving this worker locally.'**
  String get savingWorkerLocally;

  /// No description provided for @workerCreated.
  ///
  /// In en, this message translates to:
  /// **'Worker Created'**
  String get workerCreated;

  /// No description provided for @workerCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Worker successfully created.'**
  String get workerCreatedSuccess;

  /// No description provided for @mcu.
  ///
  /// In en, this message translates to:
  /// **'MCU'**
  String get mcu;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @deleteWorkerConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove {name} locally and queue the change for sync.'**
  String deleteWorkerConfirm(String name);

  /// No description provided for @deletingWorker.
  ///
  /// In en, this message translates to:
  /// **'Deleting Worker'**
  String get deletingWorker;

  /// No description provided for @removingWorkerLocally.
  ///
  /// In en, this message translates to:
  /// **'Removing this worker locally.'**
  String get removingWorkerLocally;

  /// No description provided for @workerDeleted.
  ///
  /// In en, this message translates to:
  /// **'Worker Deleted'**
  String get workerDeleted;

  /// No description provided for @workerDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Worker successfully deleted.'**
  String get workerDeletedSuccess;

  /// No description provided for @saveWorkerChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Worker Changes'**
  String get saveWorkerChanges;

  /// No description provided for @saveWorkerChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save changes for {name}?'**
  String saveWorkerChangesConfirm(String name);

  /// No description provided for @updatingWorker.
  ///
  /// In en, this message translates to:
  /// **'Updating Worker'**
  String get updatingWorker;

  /// No description provided for @savingWorkerChangesLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving worker changes locally.'**
  String get savingWorkerChangesLocally;

  /// No description provided for @workerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Worker Updated'**
  String get workerUpdated;

  /// No description provided for @workerUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Worker successfully updated.'**
  String get workerUpdatedSuccess;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityYet;

  /// No description provided for @activityWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Actions performed in the app will appear here'**
  String get activityWillAppear;

  /// No description provided for @pendingSyncs.
  ///
  /// In en, this message translates to:
  /// **'Pending Syncs'**
  String get pendingSyncs;

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'All synced'**
  String get allSynced;

  /// No description provided for @noPendingOwnerChanges.
  ///
  /// In en, this message translates to:
  /// **'There are no local owner changes waiting to upload.'**
  String get noPendingOwnerChanges;

  /// No description provided for @useDashboardSync.
  ///
  /// In en, this message translates to:
  /// **'Use the sync button on the dashboard to upload these changes.'**
  String get useDashboardSync;

  /// No description provided for @warehouseRecord.
  ///
  /// In en, this message translates to:
  /// **'Warehouse record'**
  String get warehouseRecord;

  /// No description provided for @workerAccount.
  ///
  /// In en, this message translates to:
  /// **'Worker account'**
  String get workerAccount;

  /// No description provided for @operationWarehouse.
  ///
  /// In en, this message translates to:
  /// **'{operation} warehouse'**
  String operationWarehouse(String operation);

  /// No description provided for @operationWorker.
  ///
  /// In en, this message translates to:
  /// **'{operation} worker'**
  String operationWorker(String operation);

  /// No description provided for @operationFarmer.
  ///
  /// In en, this message translates to:
  /// **'{operation} farmer'**
  String operationFarmer(String operation);

  /// No description provided for @operationDependant.
  ///
  /// In en, this message translates to:
  /// **'{operation} dependant'**
  String operationDependant(String operation);

  /// No description provided for @operationRecord.
  ///
  /// In en, this message translates to:
  /// **'{operation} {record}'**
  String operationRecord(String operation, String record);

  /// No description provided for @quickStatsWarehouses.
  ///
  /// In en, this message translates to:
  /// **'{count} warehouses'**
  String quickStatsWarehouses(int count);

  /// No description provided for @quickStatsPeople.
  ///
  /// In en, this message translates to:
  /// **'{workers} workers - {farmers} farmers'**
  String quickStatsPeople(int workers, int farmers);

  /// No description provided for @registeredFarmers.
  ///
  /// In en, this message translates to:
  /// **'Registered farmers'**
  String get registeredFarmers;

  /// No description provided for @recentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivityTitle;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @noOwnerActivity.
  ///
  /// In en, this message translates to:
  /// **'No owner activity yet'**
  String get noOwnerActivity;

  /// No description provided for @createWarehouseWorkerActivity.
  ///
  /// In en, this message translates to:
  /// **'Create a warehouse or worker to see activity here.'**
  String get createWarehouseWorkerActivity;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @noPendingSyncs.
  ///
  /// In en, this message translates to:
  /// **'No pending syncs'**
  String get noPendingSyncs;

  /// No description provided for @allOwnerChangesUploaded.
  ///
  /// In en, this message translates to:
  /// **'All local owner changes are uploaded.'**
  String get allOwnerChangesUploaded;

  /// No description provided for @ownerOperations.
  ///
  /// In en, this message translates to:
  /// **'Owner operations'**
  String get ownerOperations;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @activeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeCount(int count);

  /// No description provided for @pendingSyncCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending sync(s)'**
  String pendingSyncCount(int count);

  /// No description provided for @tapToViewPending.
  ///
  /// In en, this message translates to:
  /// **'Tap to view unsynced records'**
  String get tapToViewPending;

  /// No description provided for @noPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'There are no local changes waiting to upload.'**
  String get noPendingChanges;

  /// No description provided for @operationHarvest.
  ///
  /// In en, this message translates to:
  /// **'{operation} harvest'**
  String operationHarvest(String operation);

  /// No description provided for @harvestRecord.
  ///
  /// In en, this message translates to:
  /// **'Harvest record'**
  String get harvestRecord;

  /// No description provided for @manualSyncNeeded.
  ///
  /// In en, this message translates to:
  /// **'Local warehouse or worker changes need manual sync.'**
  String get manualSyncNeeded;

  /// No description provided for @warehouseCreatedActivity.
  ///
  /// In en, this message translates to:
  /// **'Warehouse created'**
  String get warehouseCreatedActivity;

  /// No description provided for @warehouseUpdatedActivity.
  ///
  /// In en, this message translates to:
  /// **'Warehouse updated'**
  String get warehouseUpdatedActivity;

  /// No description provided for @workerCreatedActivity.
  ///
  /// In en, this message translates to:
  /// **'Worker created'**
  String get workerCreatedActivity;

  /// No description provided for @ownerActivity.
  ///
  /// In en, this message translates to:
  /// **'Owner activity'**
  String get ownerActivity;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(int count);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @inventoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Inventory Management'**
  String get inventoryManagement;

  /// No description provided for @registerFarmerAction.
  ///
  /// In en, this message translates to:
  /// **'Register Farmer'**
  String get registerFarmerAction;

  /// No description provided for @createFarmerAtContact.
  ///
  /// In en, this message translates to:
  /// **'Create farmer records at point of contact'**
  String get createFarmerAtContact;

  /// No description provided for @allItems.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String allItems(int count);

  /// No description provided for @lowStockItems.
  ///
  /// In en, this message translates to:
  /// **'Low Stock ({count})'**
  String lowStockItems(int count);

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @searchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items...'**
  String get searchItems;

  /// No description provided for @noLowStockItems.
  ///
  /// In en, this message translates to:
  /// **'No low-stock items'**
  String get noLowStockItems;

  /// No description provided for @allAboveReorder.
  ///
  /// In en, this message translates to:
  /// **'All items are above reorder level'**
  String get allAboveReorder;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get noItemsYet;

  /// No description provided for @addItemToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap + Add Item to get started'**
  String get addItemToStart;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @addInventoryItem.
  ///
  /// In en, this message translates to:
  /// **'Add Inventory Item'**
  String get addInventoryItem;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name *'**
  String get itemName;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get sku;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @reorderLevel.
  ///
  /// In en, this message translates to:
  /// **'Reorder level'**
  String get reorderLevel;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItem;

  /// No description provided for @deleteItemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String deleteItemConfirm(String name);

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @itemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Item not found'**
  String get itemNotFound;

  /// No description provided for @skuValue.
  ///
  /// In en, this message translates to:
  /// **'SKU: {sku}'**
  String skuValue(String sku);

  /// No description provided for @onHand.
  ///
  /// In en, this message translates to:
  /// **'On Hand'**
  String get onHand;

  /// No description provided for @reorderAt.
  ///
  /// In en, this message translates to:
  /// **'Reorder At'**
  String get reorderAt;

  /// No description provided for @movementHistory.
  ///
  /// In en, this message translates to:
  /// **'Movement History'**
  String get movementHistory;

  /// No description provided for @noMovements.
  ///
  /// In en, this message translates to:
  /// **'No movements recorded yet.'**
  String get noMovements;

  /// No description provided for @previousQuantity.
  ///
  /// In en, this message translates to:
  /// **'was {quantity}'**
  String previousQuantity(String quantity);

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @stockCountShort.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get stockCountShort;

  /// No description provided for @adjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get adjust;

  /// No description provided for @recordMovement.
  ///
  /// In en, this message translates to:
  /// **'Record Movement'**
  String get recordMovement;

  /// No description provided for @actualCount.
  ///
  /// In en, this message translates to:
  /// **'Actual count'**
  String get actualCount;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @recordActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Action'**
  String get recordActionTitle;

  /// No description provided for @enterValidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity'**
  String get enterValidQuantity;

  /// No description provided for @actionRecorded.
  ///
  /// In en, this message translates to:
  /// **'Action recorded successfully!'**
  String get actionRecorded;

  /// No description provided for @actionType.
  ///
  /// In en, this message translates to:
  /// **'Action Type'**
  String get actionType;

  /// No description provided for @selectItem.
  ///
  /// In en, this message translates to:
  /// **'Select item...'**
  String get selectItem;

  /// No description provided for @currentQuantity.
  ///
  /// In en, this message translates to:
  /// **'Current: {quantity} {unit}'**
  String currentQuantity(String quantity, String unit);

  /// No description provided for @failedWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedWithDetails(String error);

  /// No description provided for @allSyncedTooltip.
  ///
  /// In en, this message translates to:
  /// **'All synced'**
  String get allSyncedTooltip;

  /// No description provided for @pendingTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingTooltip(int count);

  /// No description provided for @conflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get conflict;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @noValidRegions.
  ///
  /// In en, this message translates to:
  /// **'No valid regions were returned from the server.'**
  String get noValidRegions;

  /// No description provided for @businessInfo.
  ///
  /// In en, this message translates to:
  /// **'Business Info'**
  String get businessInfo;

  /// No description provided for @businessInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Tell us who the business is and where it operates.'**
  String get businessInfoDescription;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact Person'**
  String get contactPerson;

  /// No description provided for @contactPersonDescription.
  ///
  /// In en, this message translates to:
  /// **'Add the person we should reach for day-to-day communication.'**
  String get contactPersonDescription;

  /// No description provided for @registrationReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Check everything once before we create the account.'**
  String get registrationReviewDescription;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @nonMember.
  ///
  /// In en, this message translates to:
  /// **'Non-member'**
  String get nonMember;

  /// No description provided for @single.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get single;

  /// No description provided for @married.
  ///
  /// In en, this message translates to:
  /// **'Married'**
  String get married;

  /// No description provided for @primaryEducation.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryEducation;

  /// No description provided for @educationLevel.
  ///
  /// In en, this message translates to:
  /// **'Education level'**
  String get educationLevel;

  /// No description provided for @createFarmerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm these details and create this farmer record?'**
  String get createFarmerConfirm;

  /// No description provided for @workerMcuUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not determine MCU for this worker. Please sync your profile or contact the owner.'**
  String get workerMcuUnavailable;

  /// No description provided for @creatingFarmer.
  ///
  /// In en, this message translates to:
  /// **'Creating Farmer'**
  String get creatingFarmer;

  /// No description provided for @savingFarmerLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving this farmer locally.'**
  String get savingFarmerLocally;

  /// No description provided for @createFarmerFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create farmer.'**
  String get createFarmerFailed;

  /// No description provided for @dependantsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} dependant(s) added.'**
  String dependantsAdded(int count);

  /// No description provided for @someDependantsFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} dependant(s) added. Some dependants failed.'**
  String someDependantsFailed(int count);

  /// No description provided for @farmerRegistered.
  ///
  /// In en, this message translates to:
  /// **'Farmer Registered'**
  String get farmerRegistered;

  /// No description provided for @farmerRegisteredMessage.
  ///
  /// In en, this message translates to:
  /// **'Farmer successfully registered. {details}'**
  String farmerRegisteredMessage(String details);

  /// No description provided for @secondaryCropDifferent.
  ///
  /// In en, this message translates to:
  /// **'Secondary crop must be different from main crop'**
  String get secondaryCropDifferent;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @warehouseDeletedActivity.
  ///
  /// In en, this message translates to:
  /// **'Warehouse deleted'**
  String get warehouseDeletedActivity;

  /// No description provided for @farmerRegisteredActivity.
  ///
  /// In en, this message translates to:
  /// **'Farmer registered'**
  String get farmerRegisteredActivity;

  /// No description provided for @harvestRecordedActivity.
  ///
  /// In en, this message translates to:
  /// **'Harvest recorded'**
  String get harvestRecordedActivity;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @stepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepProgress(int current, int total);

  /// No description provided for @transferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer Out'**
  String get transferOut;

  /// No description provided for @transferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer In'**
  String get transferIn;

  /// No description provided for @movement.
  ///
  /// In en, this message translates to:
  /// **'Movement'**
  String get movement;

  /// No description provided for @scaleBluetoothPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission is required to connect the scale.'**
  String get scaleBluetoothPermissionError;

  /// No description provided for @turnOnBluetoothToScan.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth before scanning for scales.'**
  String get turnOnBluetoothToScan;

  /// No description provided for @scaleScanError.
  ///
  /// In en, this message translates to:
  /// **'Could not scan for scales. Please try again.'**
  String get scaleScanError;

  /// No description provided for @scaleConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the scale. Please try again.'**
  String get scaleConnectionError;

  /// No description provided for @noScaleConnected.
  ///
  /// In en, this message translates to:
  /// **'No scale is connected.'**
  String get noScaleConnected;

  /// No description provided for @scaleStreamError.
  ///
  /// In en, this message translates to:
  /// **'Could not receive readings from the scale.'**
  String get scaleStreamError;

  /// No description provided for @scaleReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the scale. Please try again.'**
  String get scaleReadError;

  /// No description provided for @errorInvalidServerResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned an incomplete response. Please try again.'**
  String get errorInvalidServerResponse;

  /// No description provided for @errorMissingMcuAssignment.
  ///
  /// In en, this message translates to:
  /// **'Your account has no MCU assignment. Please contact the administrator.'**
  String get errorMissingMcuAssignment;

  /// No description provided for @amcosManagement.
  ///
  /// In en, this message translates to:
  /// **'AMCOS'**
  String get amcosManagement;

  /// No description provided for @addAmcos.
  ///
  /// In en, this message translates to:
  /// **'Add AMCOS'**
  String get addAmcos;

  /// No description provided for @noAmcosFound.
  ///
  /// In en, this message translates to:
  /// **'No AMCOS found'**
  String get noAmcosFound;

  /// No description provided for @createFirstAmcos.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create the first AMCOS for this MCU.'**
  String get createFirstAmcos;

  /// No description provided for @createAmcos.
  ///
  /// In en, this message translates to:
  /// **'Create AMCOS'**
  String get createAmcos;

  /// No description provided for @createAmcosConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create {name} under your MCU?'**
  String createAmcosConfirm(String name);

  /// No description provided for @creatingAmcos.
  ///
  /// In en, this message translates to:
  /// **'Creating AMCOS'**
  String get creatingAmcos;

  /// No description provided for @savingAmcos.
  ///
  /// In en, this message translates to:
  /// **'Saving the AMCOS details.'**
  String get savingAmcos;

  /// No description provided for @amcosCreated.
  ///
  /// In en, this message translates to:
  /// **'AMCOS Created'**
  String get amcosCreated;

  /// No description provided for @amcosCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'AMCOS successfully created.'**
  String get amcosCreatedSuccess;

  /// No description provided for @memberCategory.
  ///
  /// In en, this message translates to:
  /// **'Member category'**
  String get memberCategory;

  /// No description provided for @selectMemberCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a member category'**
  String get selectMemberCategory;

  /// No description provided for @fisherman.
  ///
  /// In en, this message translates to:
  /// **'Fisherman'**
  String get fisherman;

  /// No description provided for @livestockTraders.
  ///
  /// In en, this message translates to:
  /// **'Livestock traders'**
  String get livestockTraders;

  /// No description provided for @livestockKeepers.
  ///
  /// In en, this message translates to:
  /// **'Livestock keepers'**
  String get livestockKeepers;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;
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
