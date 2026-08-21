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
  String get enterContactEmail => 'Enter contact email';

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

  @override
  String get printReceipt => 'Print Receipt';

  @override
  String get selectPrinter => 'Select Printer';

  @override
  String get availablePrinters => 'Available Printers';

  @override
  String get refreshPrinters => 'Refresh printers';

  @override
  String get scanningPrinters => 'Scanning printers...';

  @override
  String get noPrintersFound => 'No printers found';

  @override
  String get turnOnPrinterAndRefresh => 'Turn on the printer, then refresh.';

  @override
  String get noPairedPrinters => 'No paired printers';

  @override
  String get pairPrinterInSettings =>
      'Pair your thermal printer in Android Bluetooth settings first.';

  @override
  String get printingReceipt => 'Printing Receipt';

  @override
  String get printingReceiptDescription =>
      'Sending this receipt to the selected printer.';

  @override
  String get receiptPrinted => 'Receipt Printed';

  @override
  String get receiptPrintedDescription =>
      'The receipt was sent to the printer successfully.';

  @override
  String get printerError => 'Printer Error';

  @override
  String get printerLoadError => 'Could not load paired printers.';

  @override
  String get bluetoothPermissionRequired =>
      'Bluetooth permission is required to print receipts.';

  @override
  String get printOptions => 'Print Options';

  @override
  String get printWithBagDetails => 'With bag details';

  @override
  String get printWithoutBagDetails => 'Without bag details';

  @override
  String get harvestRequestReceipt => 'Harvest Request Receipt';

  @override
  String get receiptPhone => 'Phone';

  @override
  String get receiptCenter => 'Center';

  @override
  String get receiptPackaging => 'Packaging';

  @override
  String get receiptTotalBags => 'Total Bags';

  @override
  String get receiptNoBagsFound => 'No Bags Found';

  @override
  String get receiptBagDetailsNotPrinted => 'Bag Details Not Printed';

  @override
  String get receiptTagNumber => 'Tag Number';

  @override
  String get receiptMoisturePercent => 'Moisture %';

  @override
  String get receiptPackagingWeight => 'Packaging Wt';

  @override
  String get receiptNumber => 'Receipt Number';

  @override
  String get receiptReceivedDate => 'Received Date';

  @override
  String get receiptReceivedTime => 'Received Time';

  @override
  String get receiptPrintDate => 'Print Date';

  @override
  String get receiptPrintTime => 'Print Time';

  @override
  String get receiptEnd => 'Receipt End';

  @override
  String get poweredByShambabora => 'Powered by ShambaBora';

  @override
  String get back => 'Back';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get submit => 'Submit';

  @override
  String get requiredField => 'Required';

  @override
  String get useDateFormat => 'Use YYYY-MM-DD';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get sync => 'Sync';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get total => 'Total';

  @override
  String get workers => 'Workers';

  @override
  String get warehouses => 'Warehouses';

  @override
  String get farmers => 'Farmers';

  @override
  String get harvest => 'Harvest';

  @override
  String get harvests => 'Harvests';

  @override
  String get records => 'Records';

  @override
  String get warehouse => 'Warehouse';

  @override
  String get crop => 'Crop';

  @override
  String get grade => 'Grade';

  @override
  String get grossWeight => 'Gross weight';

  @override
  String get tareWeight => 'Tare weight';

  @override
  String get netWeight => 'Net weight';

  @override
  String get moisture => 'Moisture';

  @override
  String get phone => 'Phone';

  @override
  String get role => 'Role';

  @override
  String get status => 'Status';

  @override
  String get created => 'Created';

  @override
  String get owner => 'Owner';

  @override
  String get worker => 'Worker';

  @override
  String get user => 'User';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get father => 'Father';

  @override
  String get mother => 'Mother';

  @override
  String get spouse => 'Spouse';

  @override
  String get child => 'Child';

  @override
  String get brother => 'Brother';

  @override
  String get sister => 'Sister';

  @override
  String get other => 'Other';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String errorWithDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get welcomeBackTitle => 'Welcome Back';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get sendingInstructions => 'Sending Instructions';

  @override
  String get checkingEmail => 'Checking this email address.';

  @override
  String get sendResetFailed => 'Failed to send reset email.';

  @override
  String get checkYourEmail => 'Check Your Email';

  @override
  String get resetInstructionsSent =>
      'Password reset instructions have been sent to your email.';

  @override
  String get sendInstructions => 'Send Instructions';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get resettingPassword => 'Resetting Password';

  @override
  String get savingNewPassword => 'Saving your new password.';

  @override
  String get resetPasswordFailed => 'Failed to reset password.';

  @override
  String get passwordReset => 'Password Reset';

  @override
  String get passwordResetSuccess => 'Password has been reset successfully.';

  @override
  String get resetToken => 'Reset token';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get currentPassword => 'Current password';

  @override
  String get changingPassword => 'Changing Password';

  @override
  String get updatingPasswordSecurely => 'Updating your password securely.';

  @override
  String get changePasswordFailed => 'Failed to change password.';

  @override
  String get passwordChanged => 'Password Changed';

  @override
  String get passwordChangedSuccess => 'Password changed successfully.';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get selectBusinessType => 'Select business type';

  @override
  String get enterBusinessEmail => 'Enter business email';

  @override
  String get preparingRegistrationRegions =>
      'Preparing registration regions...';

  @override
  String get profile => 'Profile';

  @override
  String get regional => 'Regional';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get changePassword => 'Change Password';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmMessage =>
      'Are you sure you want to logout from this device?';

  @override
  String get loggingOut => 'Logging Out';

  @override
  String get clearingLocalSession => 'Clearing your local session.';

  @override
  String appVersion(String version) {
    return 'App ver $version';
  }

  @override
  String comingSoon(String feature) {
    return '$feature coming soon';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get farmerDetails => 'Farmer Details';

  @override
  String get registerFarmer => 'Register Farmer';

  @override
  String get addFarmer => 'Add farmer';

  @override
  String get searchFarmers => 'Search farmers...';

  @override
  String get noFarmersYet => 'No farmers yet';

  @override
  String get noFarmersFound => 'No farmers found';

  @override
  String get registerFarmerSubtitle => 'Register a farmer at point of contact.';

  @override
  String get workerFarmersSubtitle =>
      'Worker-registered farmers will appear here.';

  @override
  String get farmerNotFound => 'Farmer not found';

  @override
  String get firstName => 'First name';

  @override
  String get middleName => 'Middle name';

  @override
  String get lastName => 'Last name';

  @override
  String get sex => 'Sex';

  @override
  String get gender => 'Gender';

  @override
  String get idType => 'ID type';

  @override
  String get idNumber => 'ID number';

  @override
  String get dateOfBirth => 'Date of birth';

  @override
  String get mainCrop => 'Main crop';

  @override
  String get secondaryCrop => 'Secondary crop';

  @override
  String get selectMainCrop => 'Select main crop';

  @override
  String get selectSecondaryCrop => 'Select secondary crop';

  @override
  String get amcos => 'AMCOS';

  @override
  String get selectAmcos => 'Select AMCOS';

  @override
  String get memberType => 'Member type';

  @override
  String get maritalStatus => 'Marital status';

  @override
  String get amcosMemberId => 'AMCOS member ID';

  @override
  String get tumeNumber => 'TUME number';

  @override
  String get ttbNumber => 'TTB number';

  @override
  String get voterId => 'Voter ID';

  @override
  String get driversLicense => 'Drivers license';

  @override
  String get numberOfShares => 'Number of shares';

  @override
  String get shares => 'Shares';

  @override
  String get dependants => 'Dependants';

  @override
  String get dependant => 'Dependant';

  @override
  String get addDependant => 'Add Dependant';

  @override
  String get removeDependant => 'Remove dependant';

  @override
  String get relationship => 'Relationship';

  @override
  String get noDependantsAdded => 'No dependants added';

  @override
  String get noDependantsForFarmer =>
      'No dependants have been added for this farmer.';

  @override
  String get dependantsOptional =>
      'This step is optional. Dependants can also be added later.';

  @override
  String get addDependantConfirm => 'Add this dependant to the farmer record?';

  @override
  String get addingDependant => 'Adding Dependant';

  @override
  String get addingDependantProgress => 'Adding dependant...';

  @override
  String get savingDependantLocally => 'Saving this dependant locally.';

  @override
  String get dependantAdded => 'Dependant Added';

  @override
  String get dependantAddedSuccess => 'Dependant successfully added.';

  @override
  String get dependantAddFailed => 'Failed to add dependant.';

  @override
  String get createFarmer => 'Create Farmer';

  @override
  String get captureFarmerDescription =>
      'Capture the farmer record at point of contact.';

  @override
  String get addDependantsDescription =>
      'Add dependants now, or leave this for later.';

  @override
  String get review => 'Review';

  @override
  String get reviewFarmerDescription =>
      'Confirm the details before creating the farmer.';

  @override
  String get name => 'Name';

  @override
  String get loadingCrop => 'Loading crop...';

  @override
  String unknownCrop(int id) {
    return 'Unknown crop (ID $id)';
  }

  @override
  String get connectScale => 'Connect Scale';

  @override
  String get connectTheScale => 'Connect the scale';

  @override
  String get connectScaleDescription =>
      'Connect a Bluetooth scale before measuring crops. Scan nearby devices when the scale is ready.';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not connected';

  @override
  String get scanNearbyScale => 'Scan nearby devices to find your scale.';

  @override
  String get scanning => 'Scanning...';

  @override
  String get scanDevices => 'Scan Devices';

  @override
  String get availableDevices => 'Available Devices';

  @override
  String get refreshDevices => 'Refresh devices';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get deviceScanHelp =>
      'Turn on the scale, Bluetooth, and Location, then refresh.';

  @override
  String get bluetoothLocationRequired => 'Bluetooth and Location Required';

  @override
  String get bluetoothLocationMessage =>
      'Please allow Bluetooth and Location permissions, and keep Bluetooth and Location turned on before scanning devices.';

  @override
  String get connect => 'Connect';

  @override
  String get unknownScale => 'Unknown Scale';

  @override
  String likelyScale(int rssi) {
    return 'Likely scale - $rssi dBm';
  }

  @override
  String get collectionCenter => 'Collection center';

  @override
  String get warehouseNotFound => 'Warehouse not found';

  @override
  String get loadingWarehouse => 'Loading warehouse...';

  @override
  String get noCropsAvailable => 'No crops available';

  @override
  String get syncCropDataFirst => 'Sync crop reference data first.';

  @override
  String get noFarmersAvailable => 'No farmers available';

  @override
  String get syncOrRegisterFarmers =>
      'Sync or register farmers before receiving crops.';

  @override
  String get search => 'Search';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noMatchingFarmers => 'No matching farmers';

  @override
  String get selectFarmer => 'Select a farmer.';

  @override
  String get selectCrop => 'Select a crop.';

  @override
  String farmerNumber(int id) {
    return 'Farmer $id';
  }

  @override
  String get scale => 'Scale';

  @override
  String get loadingScale => 'Loading scale...';

  @override
  String get bag => 'Bag';

  @override
  String get bagTag => 'Bag tag';

  @override
  String get generateBagTag => 'Generate bag tag';

  @override
  String get packagingWeightKg => 'Packaging weight (kg)';

  @override
  String get addBag => 'Add Bag';

  @override
  String get viewBags => 'View bags';

  @override
  String get editDetails => 'Edit details';

  @override
  String get stable => 'Stable';

  @override
  String get unstable => 'Unstable';

  @override
  String get scaleReading => 'Scale Reading';

  @override
  String get connectScaleBeforeWeighing => 'Connect scale before weighing';

  @override
  String get selectedFarmer => 'Selected farmer';

  @override
  String get farmerDetailsNeeded => 'Farmer details needed';

  @override
  String get farmerDetailsNeededMessage =>
      'Select farmer and crop details before weighing bags.';

  @override
  String get goToDetails => 'Go to Details';

  @override
  String moistureReceiptMessage(String percent) {
    return 'Moisture is set to $percent%. Net weight will appear on the receipt.';
  }

  @override
  String get connectScaleBeforeBag => 'Connect the scale before adding a bag.';

  @override
  String get waitForStableScale =>
      'Please wait until the scale reading is stable.';

  @override
  String get weightGreaterThanZero => 'Weight must be greater than zero.';

  @override
  String get packagingLessThanGross =>
      'Packaging weight must be less than gross weight.';

  @override
  String get noBagsAdded => 'No bags added yet';

  @override
  String get completeHarvest => 'Complete Harvest';

  @override
  String get addBagBeforeComplete =>
      'Add at least one bag before completing harvest.';

  @override
  String completeHarvestConfirm(int count) {
    return 'Save $count bag(s) and generate one receipt?';
  }

  @override
  String get savingHarvest => 'Saving Harvest';

  @override
  String get savingHarvestLocally => 'Saving this harvest locally.';

  @override
  String get saveHarvestFailed => 'Failed to save harvest.';

  @override
  String get harvestSaved => 'Harvest Saved';

  @override
  String get harvestSavedMessage =>
      'Harvest successfully saved. Receipt is ready.';

  @override
  String get enterValidWeight => 'Enter a valid weight';

  @override
  String get cannotBeNegative => 'Cannot be negative';

  @override
  String bagWeightSummary(String gross, String packaging) {
    return 'Gross $gross kg - Packaging $packaging kg';
  }

  @override
  String get removeBag => 'Remove bag';

  @override
  String get newHarvest => 'New harvest';

  @override
  String get receiveCrop => 'Receive crop';

  @override
  String get searchHarvests => 'Search harvests...';

  @override
  String get noHarvestsYet => 'No harvests yet';

  @override
  String get noHarvestsFound => 'No harvests found';

  @override
  String get newHarvestSubtitle =>
      'Tap + to connect a scale and receive crops.';

  @override
  String get workerHarvestsSubtitle =>
      'Worker harvest records will appear here.';

  @override
  String get harvestDetails => 'Harvest Details';

  @override
  String get harvestNotFound => 'Harvest not found';

  @override
  String get harvestRemovedLocally =>
      'This record may have been removed locally.';

  @override
  String get chooseWarehouse => 'Choose Warehouse';

  @override
  String get chooseWarehouseMessage =>
      'Select where this crop receiving session will be recorded.';

  @override
  String get createWarehouseBeforeReceiving =>
      'Create an active warehouse before receiving crops.';

  @override
  String get addWarehouse => 'Add warehouse';

  @override
  String get searchWarehouses => 'Search warehouses...';

  @override
  String get allWarehouses => 'All Warehouses';

  @override
  String get noWarehousesFound => 'No warehouses found';

  @override
  String get createFirstWarehouse => 'Tap + to create your first warehouse.';

  @override
  String get locationNotSet => 'Location not set';

  @override
  String createWarehouseConfirm(String name) {
    return 'Create $name as a new warehouse?';
  }

  @override
  String get creatingWarehouse => 'Creating Warehouse';

  @override
  String get savingWarehouseLocally => 'Saving this warehouse locally.';

  @override
  String get warehouseCreated => 'Warehouse Created';

  @override
  String get warehouseCreatedSuccess => 'Warehouse successfully created.';

  @override
  String get newWarehouse => 'New Warehouse';

  @override
  String get warehouseName => 'Warehouse name';

  @override
  String get district => 'District';

  @override
  String get ward => 'Ward';

  @override
  String get village => 'Village';

  @override
  String get gpsLocationAddress => 'GPS location / address';

  @override
  String get locationAutoBuilt =>
      'Auto-built from region, district, ward and village';

  @override
  String get warehouseNotFoundMessage => 'Warehouse not found';

  @override
  String get inventory => 'Inventory';

  @override
  String get assignedWorkers => 'Assigned Workers';

  @override
  String get noInventoryItems => 'No inventory items yet.';

  @override
  String get noAssignedWorkers => 'No workers assigned to this warehouse yet.';

  @override
  String get deleteWarehouse => 'Delete Warehouse';

  @override
  String deleteWarehouseConfirm(String name) {
    return 'This will remove $name locally and sync the change to the server.';
  }

  @override
  String get editWarehouse => 'Edit Warehouse';

  @override
  String get amcosId => 'AMCOS ID';

  @override
  String get amcosName => 'AMCOS name';

  @override
  String get villageId => 'Village ID';

  @override
  String get villageName => 'Village name';

  @override
  String get addWorker => 'Add Worker';

  @override
  String get addWorkerTooltip => 'Add worker';

  @override
  String get noWorkersYet => 'No workers yet';

  @override
  String get createFirstWorker => 'Use + to create your first worker account';

  @override
  String get workerDetails => 'Worker Details';

  @override
  String get workerNotFound => 'Worker not found';

  @override
  String get editWorker => 'Edit worker';

  @override
  String get deleteWorker => 'Delete Worker';

  @override
  String get fullName => 'Full name';

  @override
  String get assignToWarehouse => 'Assign to warehouse';

  @override
  String get selectWarehouse => 'Select warehouse';

  @override
  String get fillWorkerDetails => 'Fill in details and assign a warehouse';

  @override
  String get amcosDerivedFromWarehouse =>
      'AMCOS is derived automatically from this selection';

  @override
  String get createWorkerAccount => 'Create Worker Account';

  @override
  String get enterWorkerName => 'Enter worker name';

  @override
  String get enterWorkerEmail => 'Enter worker email';

  @override
  String get enterPassword => 'Enter a password';

  @override
  String get assignWarehouseRequired => 'Please assign a warehouse';

  @override
  String get assignWorkerWarehouse =>
      'Please assign this worker to a warehouse.';

  @override
  String get selectedWarehouseNotFound =>
      'Selected warehouse not found. Please try again.';

  @override
  String warehouseMissingAmcos(String warehouse) {
    return '$warehouse has no AMCOS assigned. Please select a different warehouse.';
  }

  @override
  String get ownerIdUnavailable =>
      'Could not determine owner ID. Please log out and back in.';

  @override
  String get createWorker => 'Create Worker';

  @override
  String createWorkerConfirm(String name, String warehouse) {
    return 'Create an account for $name and assign this worker to $warehouse?';
  }

  @override
  String get creatingWorker => 'Creating Worker';

  @override
  String get savingWorkerLocally => 'Saving this worker locally.';

  @override
  String get workerCreated => 'Worker Created';

  @override
  String get workerCreatedSuccess => 'Worker successfully created.';

  @override
  String get mcu => 'MCU';

  @override
  String get loading => 'Loading...';

  @override
  String deleteWorkerConfirm(String name) {
    return 'This will remove $name locally and queue the change for sync.';
  }

  @override
  String get deletingWorker => 'Deleting Worker';

  @override
  String get removingWorkerLocally => 'Removing this worker locally.';

  @override
  String get workerDeleted => 'Worker Deleted';

  @override
  String get workerDeletedSuccess => 'Worker successfully deleted.';

  @override
  String get saveWorkerChanges => 'Save Worker Changes';

  @override
  String saveWorkerChangesConfirm(String name) {
    return 'Save changes for $name?';
  }

  @override
  String get updatingWorker => 'Updating Worker';

  @override
  String get savingWorkerChangesLocally => 'Saving worker changes locally.';

  @override
  String get workerUpdated => 'Worker Updated';

  @override
  String get workerUpdatedSuccess => 'Worker successfully updated.';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noActivityYet => 'No activity yet';

  @override
  String get activityWillAppear =>
      'Actions performed in the app will appear here';

  @override
  String get pendingSyncs => 'Pending Syncs';

  @override
  String get allSynced => 'All synced';

  @override
  String get noPendingOwnerChanges =>
      'There are no local owner changes waiting to upload.';

  @override
  String get useDashboardSync =>
      'Use the sync button on the dashboard to upload these changes.';

  @override
  String get warehouseRecord => 'Warehouse record';

  @override
  String get workerAccount => 'Worker account';

  @override
  String operationWarehouse(String operation) {
    return '$operation warehouse';
  }

  @override
  String operationWorker(String operation) {
    return '$operation worker';
  }

  @override
  String operationFarmer(String operation) {
    return '$operation farmer';
  }

  @override
  String operationDependant(String operation) {
    return '$operation dependant';
  }

  @override
  String operationRecord(String operation, String record) {
    return '$operation $record';
  }

  @override
  String quickStatsWarehouses(int count) {
    return '$count warehouses';
  }

  @override
  String quickStatsPeople(int workers, int farmers) {
    return '$workers workers - $farmers farmers';
  }

  @override
  String get registeredFarmers => 'Registered farmers';

  @override
  String get recentActivityTitle => 'Recent Activity';

  @override
  String get seeAll => 'See all';

  @override
  String get noOwnerActivity => 'No owner activity yet';

  @override
  String get createWarehouseWorkerActivity =>
      'Create a warehouse or worker to see activity here.';

  @override
  String get alerts => 'Alerts';

  @override
  String get noPendingSyncs => 'No pending syncs';

  @override
  String get allOwnerChangesUploaded => 'All local owner changes are uploaded.';

  @override
  String get ownerOperations => 'Owner operations';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String activeCount(int count) {
    return '$count active';
  }

  @override
  String pendingSyncCount(int count) {
    return '$count pending sync(s)';
  }

  @override
  String get tapToViewPending => 'Tap to view unsynced records';

  @override
  String get noPendingChanges =>
      'There are no local changes waiting to upload.';

  @override
  String operationHarvest(String operation) {
    return '$operation harvest';
  }

  @override
  String get harvestRecord => 'Harvest record';

  @override
  String get manualSyncNeeded =>
      'Local warehouse or worker changes need manual sync.';

  @override
  String get warehouseCreatedActivity => 'Warehouse created';

  @override
  String get warehouseUpdatedActivity => 'Warehouse updated';

  @override
  String get workerCreatedActivity => 'Worker created';

  @override
  String get ownerActivity => 'Owner activity';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get home => 'Home';

  @override
  String get inventoryManagement => 'Inventory Management';

  @override
  String get registerFarmerAction => 'Register Farmer';

  @override
  String get createFarmerAtContact =>
      'Create farmer records at point of contact';

  @override
  String allItems(int count) {
    return 'All ($count)';
  }

  @override
  String lowStockItems(int count) {
    return 'Low Stock ($count)';
  }

  @override
  String get addItem => 'Add Item';

  @override
  String get searchItems => 'Search items...';

  @override
  String get noLowStockItems => 'No low-stock items';

  @override
  String get allAboveReorder => 'All items are above reorder level';

  @override
  String get noItemsYet => 'No items yet';

  @override
  String get addItemToStart => 'Tap + Add Item to get started';

  @override
  String get reorder => 'Reorder';

  @override
  String get addInventoryItem => 'Add Inventory Item';

  @override
  String get itemName => 'Item name *';

  @override
  String get sku => 'SKU';

  @override
  String get category => 'Category';

  @override
  String get unit => 'Unit';

  @override
  String get reorderLevel => 'Reorder level';

  @override
  String get item => 'Item';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String deleteItemConfirm(String name) {
    return 'Remove $name?';
  }

  @override
  String get record => 'Record';

  @override
  String get itemNotFound => 'Item not found';

  @override
  String skuValue(String sku) {
    return 'SKU: $sku';
  }

  @override
  String get onHand => 'On Hand';

  @override
  String get reorderAt => 'Reorder At';

  @override
  String get movementHistory => 'Movement History';

  @override
  String get noMovements => 'No movements recorded yet.';

  @override
  String previousQuantity(String quantity) {
    return 'was $quantity';
  }

  @override
  String get delivery => 'Delivery';

  @override
  String get stockCountShort => 'Count';

  @override
  String get adjust => 'Adjust';

  @override
  String get recordMovement => 'Record Movement';

  @override
  String get actualCount => 'Actual count';

  @override
  String get quantity => 'Quantity';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get recordActionTitle => 'Record Action';

  @override
  String get enterValidQuantity => 'Enter a valid quantity';

  @override
  String get actionRecorded => 'Action recorded successfully!';

  @override
  String get actionType => 'Action Type';

  @override
  String get selectItem => 'Select item...';

  @override
  String currentQuantity(String quantity, String unit) {
    return 'Current: $quantity $unit';
  }

  @override
  String failedWithDetails(String error) {
    return 'Failed: $error';
  }

  @override
  String get allSyncedTooltip => 'All synced';

  @override
  String pendingTooltip(int count) {
    return '$count pending';
  }

  @override
  String get conflict => 'Conflict';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get register => 'Register';

  @override
  String get noValidRegions =>
      'No valid regions were returned from the server.';

  @override
  String get businessInfo => 'Business Info';

  @override
  String get businessInfoDescription =>
      'Tell us who the business is and where it operates.';

  @override
  String get contactPerson => 'Contact Person';

  @override
  String get contactPersonDescription =>
      'Add the person we should reach for day-to-day communication.';

  @override
  String get registrationReviewDescription =>
      'Check everything once before we create the account.';

  @override
  String get member => 'Member';

  @override
  String get nonMember => 'Non-member';

  @override
  String get single => 'Single';

  @override
  String get married => 'Married';

  @override
  String get primaryEducation => 'Primary';

  @override
  String get educationLevel => 'Education level';

  @override
  String get createFarmerConfirm =>
      'Confirm these details and create this farmer record?';

  @override
  String get workerMcuUnavailable =>
      'Could not determine MCU for this worker. Please sync your profile or contact the owner.';

  @override
  String get creatingFarmer => 'Creating Farmer';

  @override
  String get savingFarmerLocally => 'Saving this farmer locally.';

  @override
  String get createFarmerFailed => 'Failed to create farmer.';

  @override
  String dependantsAdded(int count) {
    return '$count dependant(s) added.';
  }

  @override
  String someDependantsFailed(int count) {
    return '$count dependant(s) added. Some dependants failed.';
  }

  @override
  String get farmerRegistered => 'Farmer Registered';

  @override
  String farmerRegisteredMessage(String details) {
    return 'Farmer successfully registered. $details';
  }

  @override
  String get secondaryCropDifferent =>
      'Secondary crop must be different from main crop';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get warehouseDeletedActivity => 'Warehouse deleted';

  @override
  String get farmerRegisteredActivity => 'Farmer registered';

  @override
  String get harvestRecordedActivity => 'Harvest recorded';

  @override
  String get update => 'Update';

  @override
  String stepProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get transferOut => 'Transfer Out';

  @override
  String get transferIn => 'Transfer In';

  @override
  String get movement => 'Movement';

  @override
  String get scaleBluetoothPermissionError =>
      'Bluetooth permission is required to connect the scale.';

  @override
  String get turnOnBluetoothToScan =>
      'Turn on Bluetooth before scanning for scales.';

  @override
  String get scaleScanError => 'Could not scan for scales. Please try again.';

  @override
  String get scaleConnectionError =>
      'Could not connect to the scale. Please try again.';

  @override
  String get noScaleConnected => 'No scale is connected.';

  @override
  String get scaleStreamError => 'Could not receive readings from the scale.';

  @override
  String get scaleReadError => 'Could not read the scale. Please try again.';

  @override
  String get errorInvalidServerResponse =>
      'The server returned an incomplete response. Please try again.';

  @override
  String get errorMissingMcuAssignment =>
      'Your account has no MCU assignment. Please contact the administrator.';

  @override
  String get amcosManagement => 'AMCOS';

  @override
  String get addAmcos => 'Add AMCOS';

  @override
  String get noAmcosFound => 'No AMCOS found';

  @override
  String get createFirstAmcos =>
      'Tap + to create the first AMCOS for this MCU.';

  @override
  String get createAmcos => 'Create AMCOS';

  @override
  String createAmcosConfirm(String name) {
    return 'Create $name under your MCU?';
  }

  @override
  String get creatingAmcos => 'Creating AMCOS';

  @override
  String get savingAmcos => 'Saving the AMCOS details.';

  @override
  String get amcosCreated => 'AMCOS Created';

  @override
  String get amcosCreatedSuccess => 'AMCOS successfully created.';

  @override
  String get memberCategory => 'Member category';

  @override
  String get selectMemberCategory => 'Select a member category';

  @override
  String get fisherman => 'Fisherman';

  @override
  String get livestockTraders => 'Livestock traders';

  @override
  String get livestockKeepers => 'Livestock keepers';

  @override
  String get suppliers => 'Suppliers';
}
