# SB Warehouse Play Store Release Notes

## Android Package

Package name: `com.climbup.warehousing`

## App Icon

`assets/logo/warehouse_logo.png`

Android launcher icons are present under:

`android/app/src/main/res/mipmap-*/ic_launcher.png`

## Test Sign-In Credentials

Role:Owner
email:money@gmail.com
password:molisa
notes:Should access dashboard, warehouses, workers, harvests, sync.

Role:worker
email:hello@gmail.com
password:molisa
notes:Should be assigned to a warehouse,receive harvest,register farmers,perform sync

## Account Deletion

Account deletion request form:

`https://forms.gle/w4AaDT2U3qriBeP76`

The login screen now includes a link to open this form.

## Short Description

Offline warehouse stock, harvest, and team management for crop stores.

## Full Description

SB Warehouse helps warehouse teams receive crops, manage crop stock, track bag weights, and synchronize records with the central ShambaBora backend.

Owners and managers can create warehouses, manage workers, view warehouse stock, and sync operational data. Workers can record harvest receiving, manage assigned warehouse inventory, capture stock movements, connect weighing devices, print receipts, and continue working offline when internet is unavailable.

The app is designed for crop traceability and accountability from receiving to warehouse stock records, with offline-first storage and later synchronization when the device is back online.

## Data Collected In The App

The app may collect:

- User account details: name, email, phone number, role, login credentials, user ID.
- Business and warehouse details: business name, business type, registration number, TIN, address, region, warehouse name, warehouse location,AMCOS references.
- Worker records: worker name, email, phone number, role, status, assigned warehouse.
- Farmer and dependant records where enabled: names, phone numbers, addresses, gender, date of birth, relationship, ID type/number, member details.
- Harvest and stock records: crop, grade, bag tag numbers, gross weight, packaging weight, net weight, moisture content, receipt number, receiving user, timestamps.
- Warehouse operation records: dispatches, stock counts, stock adjustments, selected stock bag UUIDs, measured weights, recipient details, operation timestamps.
- Device connection data needed for app functionality: Bluetooth scale/printer connection state and USB moisture meter readings.

The app does not collect advertising data, contact lists, photos, videos, SMS, call logs, calendar data, payment card details, or web browsing history.

## Privacy Policy Hosting

Use `playstore/privacy_policy.html` as the privacy policy page content.