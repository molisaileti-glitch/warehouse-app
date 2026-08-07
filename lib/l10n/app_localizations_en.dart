// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get continueButton => 'Continue';

  @override
  String get saveButton => 'Save';

  @override
  String get onboardingTitle1 => 'Track every item';

  @override
  String get onboardingDesc1 =>
      'Add inventory, see stock levels at a glance, and get low-stock alerts automatically.';

  @override
  String get onboardingTitle2 => 'Works without internet';

  @override
  String get onboardingDesc2 =>
      'Record deliveries, counts, and movements offline. Everything syncs automatically once you\'re back online.';

  @override
  String get onboardingTitle3 => 'Built for your whole team';

  @override
  String get onboardingDesc3 =>
      'Owners manage warehouses and staff. Managers track inventory. Workers record stock movements.';

  @override
  String get skip => 'Skip';

  @override
  String get getStarted => 'Get Started';

  @override
  String get next => 'Next';

  @override
  String get signInTitle => 'Sign in to your account';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get newOwnerPrompt => 'New owner? Create an account';

  @override
  String get accessLevelHint =>
      'Your access level is set by your administrator.';

  @override
  String get validationEmailRequired => 'Enter your email';

  @override
  String get validationEmailInvalid => 'Enter a valid email';

  @override
  String get validationPasswordRequired => 'Enter your password';

  @override
  String get validationPasswordTooShort => 'Password too short';

  @override
  String get createOwnerAccount => 'Create Owner Account';

  @override
  String get registerSubtitle =>
      'Set up your business details to start managing your warehouse and team.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get ok => 'OK';

  @override
  String get loadingTitle => 'Please wait';

  @override
  String get loadingDescription => 'We are processing your request.';

  @override
  String get registrationConfirmTitle => 'Confirm Registration';

  @override
  String get registrationConfirmMessage =>
      'Please review your details. Do you want to submit this registration now?';

  @override
  String get registrationSuccessTitle => 'Registration successful';

  @override
  String get registrationSuccessMessage =>
      'Your account has been created. You can now sign in with your login credentials.';

  @override
  String get registrationErrorTitle => 'Registration failed';

  @override
  String get registrationErrorMessage =>
      'We could not create your account. Please review your details and try again.';

  @override
  String get businessName => 'Business name';

  @override
  String get enterBusinessName => 'Enter your business name';

  @override
  String get businessType => 'Business type';

  @override
  String get region => 'Region';

  @override
  String get selectRegion => 'Select a region';

  @override
  String get address => 'Address';

  @override
  String get enterAddress => 'Enter an address';

  @override
  String get registrationNumber => 'Registration number';

  @override
  String get enterRegistrationNumber => 'Enter a registration number';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get enterPhoneNumber => 'Enter a phone number';

  @override
  String get businessEmail => 'Business email';

  @override
  String get tinNumber => 'TIN number';

  @override
  String get enterTinNumber => 'Enter a TIN number';

  @override
  String get website => 'Website';

  @override
  String get enterWebsiteUrl => 'Enter a website URL';

  @override
  String get contactName => 'Contact name';

  @override
  String get enterContactName => 'Enter a contact name';

  @override
  String get contactPhone => 'Contact phone';

  @override
  String get enterContactPhone => 'Enter a contact phone number';

  @override
  String get contactEmail => 'Contact email';

  @override
  String get enterContactEmail => 'Enter a contact email';

  @override
  String get contactTitle => 'Contact title';

  @override
  String get enterJobTitle => 'Enter a job title';

  @override
  String get createAccount => 'Create Account';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get selectRegionError => 'Please select a region';

  @override
  String get couldNotLoadRegions => 'Could not load regions';

  @override
  String get retry => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get howToUseApp => 'How to use this app';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmMessageOwner =>
      'Pending changes will sync when you next connect.';

  @override
  String get signOutConfirmMessageWorker => 'You will be signed out.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get myTasks => 'My Tasks';

  @override
  String get welcomeBack => 'Welcome back 👋';

  @override
  String get ownerOverview => 'Owner Overview';

  @override
  String get totalWarehouses => 'Total Warehouses';

  @override
  String get activeWarehouses => 'Active Warehouses';

  @override
  String get pendingSync => 'Pending Sync';

  @override
  String get analytics => 'Analytics';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get createWarehouse => 'Create Warehouse';

  @override
  String get addWarehouseSubtitle => 'Add a new warehouse location';

  @override
  String get viewWorkers => 'View Workers';

  @override
  String get seeStaffSubtitle => 'See staff assigned to each warehouse';

  @override
  String get viewAnalytics => 'View Analytics';

  @override
  String get stockTrendsSubtitle => 'Stock trends and movement reports';

  @override
  String get forceSync => 'Force Sync';

  @override
  String get pushPendingSubtitle => 'Push all pending changes now';

  @override
  String get syncing => 'Syncing…';

  @override
  String syncedSummary(String pushed, String pulled) {
    return 'Synced: $pushed pushed, $pulled pulled';
  }

  @override
  String get notAssignedWarehouse => 'Not assigned to a warehouse';

  @override
  String get askAdminAssignment =>
      'Ask your administrator to assign you to a warehouse.';

  @override
  String get assignedWarehouse => 'Assigned Warehouse';

  @override
  String get totalItems => 'Total Items';

  @override
  String get lowStock => 'Low Stock';

  @override
  String get recordAction => 'Record an Action';

  @override
  String get recordDelivery => 'Record Delivery';

  @override
  String get incomingGoodsSubtitle => 'Incoming goods received';

  @override
  String get stockCount => 'Stock Count';

  @override
  String get countItemsSubtitle => 'Count items on the shelf';

  @override
  String get adjustment => 'Adjustment';

  @override
  String get correctDiscrepanciesSubtitle => 'Correct stock discrepancies';

  @override
  String get lowStockAlerts => '⚠️ Low Stock Alerts';

  @override
  String get workerDashboardTitle => 'Worker Dashboard';

  @override
  String get workerProfileNoSync =>
      'Your profile hasn\'t synced yet. Once the backend assigns you to a warehouse, your tasks will appear here.';

  @override
  String get errorInvalidDetails => 'Invalid details — check your information';

  @override
  String get errorIncorrectCredentials => 'Incorrect email or password';

  @override
  String get errorAccountDisabled =>
      'Account disabled — contact your administrator';

  @override
  String get errorEmailExists => 'An account with this email already exists';

  @override
  String get errorTooManyAttempts => 'Too many attempts — try again later';

  @override
  String get errorNetworkError => 'Network error — check your connection';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get noReceiptYet => 'No receipt yet';

  @override
  String get completeReceivingBeforeReceipt =>
      'Complete a receiving session before viewing the receipt.';

  @override
  String get startReceiving => 'Start Receiving';

  @override
  String get warehouseReceipt => 'Warehouse Receipt';

  @override
  String get receiptLanguage => 'Receipt language';

  @override
  String get receiptEnglish => 'English';

  @override
  String get receiptSwahili => 'Swahili';

  @override
  String get receiptFarmer => 'Farmer';

  @override
  String get receiptCrop => 'Crop';

  @override
  String get receiptWarehouse => 'Warehouse';

  @override
  String get receiptBags => 'Bags';

  @override
  String get receiptGross => 'Gross';

  @override
  String get receiptTare => 'Tare';

  @override
  String get receiptNet => 'Net';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptReceivedBy => 'Received by';

  @override
  String get newReceiving => 'New Receiving';

  @override
  String get generateReceipt => 'Generate Receipt';
}
