
# Activity 09 - Local Storage Part II

Name: Abubeker Mohammed  
Course: Mobile Application Development 4360  
Pathway: Undergraduate

## Project

For this activity, I continued my Activity 08 Flutter app. I used SQLite to add folders and cards. Each card belongs to one folder. I can add, edit, and delete folders and cards.

I kept my old Fall Festival Roster screen because I needed to make sure my Activity 08 data did not get deleted.

## Development Environment

- Flutter: 3.47.3 Stable
- Dart: 3.13.3
- Android emulator: Android 17, API 37
- Editor: Visual Studio Code
- Database: SQLite using sqflite 2.4.1 or compatible version
- Database file: MyDatabase.db
- Database version: 2

## Database Migration

My Activity 08 database was version 1 and had a table named my_table.

For Activity 09, I changed the database version to 2. I added folders and cards tables and an index named idx_cards_folder_id.

I used onUpgrade to create the new tables without deleting my old table.

Before upgrading, I had these records:

| ID | Name | Age |
|---|---|---|
| 1 | River | 35 |
| 2 | Acorn | 0 |
| 3 | Oak | 130 |

After upgrading, I opened the app and all three records were still there. The record count stayed at 3.

## Folder and Card Relationship

The folders table has the folder ID, name, and creation date.

The cards table has the card ID, title, suit, notes, image reference, and folder ID.

The folder_id connects each card to its folder. I enabled foreign keys and used ON DELETE CASCADE.

I used the database ID for editing and deleting records instead of using the name.

## Image Handling

I stored the image reference as text instead of putting image bytes inside SQLite.

When the image reference is empty or the image cannot load, the app shows the card suit symbol.

For example, a Spades card shows the spade symbol when its image is missing.

## Testing

### T1 - Upgrade Preservation

Expected: The old Activity 08 records should remain after upgrading.

Observed: River, Acorn, and Oak were still there. The record count stayed at 3.

Result: Pass.

Evidence: evidence/T1_before.png

### T2 - Parent and Child Relationship

Expected: Cards should appear only in their selected folders.

Observed: I created Favorite Cards and Other Cards.

| Folder ID | Folder | Card Count |
|---|---|---|
| 1 | Favorite Cards | 2 |
| 2 | Other Cards | 1 |

Favorite Cards had Ace of Hearts and King of Spades. Other Cards had Queen of Diamonds.

Result: Pass.

Evidence: evidence/T2_cards.png

### T3 - Edit and Cancel

Expected: Saving an edit should update the card. Cancel should not save the changes.

Observed: I edited the Ace of Hearts card. The new notes were saved. I also tried changing King of Spades, but pressed Cancel. Its original information stayed the same.

The folder counts stayed at 2 and 1.

Result: Pass.

### T4 - Restart Persistence

Expected: The database records should remain after restarting the app.

Observed: I closed and reopened the Android app. My original Activity 08 records were still there. The two folders and three cards were also there.

The card IDs stayed the same. The saved notes on Ace of Hearts were still there.

Result: Pass.

Evidence: evidence/T4_after.png

### T5 - Delete Behavior

Expected: Cancel should keep the folder. Confirming Delete should remove the folder and its cards.

Observed: I created a temporary folder called Delete Test and added one card.

I pressed Cancel first, and the folder stayed there. After confirming Delete, the folder disappeared.

Favorite Cards still had 2 cards and Other Cards still had 1 card.

Result: Pass.

### T6 - Invalid Input and Image Fallback

Expected: Empty card titles should be rejected. Missing images should show a fallback.

Observed: The app rejected an empty title and a title with only spaces.

I tested a missing image using assets/missing_image.png. The King of Spades card showed the spade symbol instead of crashing.

The folder still had 2 cards.

Result: Pass.

## Analyzer

I ran flutter analyze after completing the code.

Result: No issues found.

Evidence: evidence/analysis_output.txt

## How to Run

Open the project in Visual Studio Code.

Install dependencies:

```bash
flutter pub get
```

Check the code:

```bash
flutter analyze
```

Start the Android emulator and run:

```bash
flutter run -d emulator-5554
```

Build the Android release APK:

```bash
flutter build apk --release
```

## Project Files

- lib/main.dart - Original guest screen and folder navigation
- lib/database_helper.dart - SQLite database and CRUD methods
- lib/models/folder.dart - Folder model
- lib/models/card_item.dart - Card model
- lib/screens/folders_screen.dart - Folder screen
- lib/screens/cards_screen.dart - Card list screen
- lib/screens/card_form_screen.dart - Add and edit card form
- evidence/ - Screenshots and analyzer output

## Known Limitations

I did not add an image picker. The app uses an image reference and shows a suit symbol if the image is missing.

I tested my app using an Android emulator.
