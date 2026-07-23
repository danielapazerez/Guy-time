# Guy Time — Sprint 2 v2.0

אפליקציית SwiftUI למעקב האכלה של גיא, כולל Sprint 1 וכל תשתיות Sprint 2.

## Sprint 2
- CloudKit: גיבוי וסנכרון אוטומטי דרך iCloud
- שיתוף משפחתי דרך `CKShare` ו־`UICloudSharingController`
- קבלת הזמנת שיתוף בין שני חשבונות Apple
- פתרון התנגשויות לפי `updatedAt` וסימון מחיקות (tombstones)
- התראות מקומיות לפי זמן מאז ההאכלה האחרונה
- Widget קטן ובינוני למסך הבית
- גרפים יומיים, שבועיים וחודשיים באמצעות Swift Charts
- נתוני ה־Widget עוברים דרך App Group

## הפעלה ב־Xcode — חובה
1. פתחי `GuyTime.xcodeproj` ב־Xcode 16 ומעלה על Mac.
2. בחרי את Target ‏`GuyTime` → Signing & Capabilities ובחרי Team מחשבון Apple Developer.
3. ודאי שה־Bundle ID ייחודי. ברירת המחדל: `com.pazgroup.GuyTime`.
4. הוסיפי ל־Target הראשי:
   - iCloud → CloudKit
   - App Groups → `group.com.pazgroup.GuyTime`
   - Push Notifications (מומלץ לסנכרון CloudKit ברקע)
   - Background Modes → Remote notifications
5. הוסיפי Target מסוג **Widget Extension** בשם `GuyTimeWidget` אם Xcode אינו מציג אותו, והשתמשי בקבצים שבתיקיית `GuyTimeWidget`.
6. ל־Widget הפעילי את אותו App Group.
7. ב־CloudKit Dashboard צרי/אשרי Container בשם `iCloud.com.pazgroup.GuyTime` ופרסי את ה־Schema ל־Production לפני TestFlight.

## הערת בדיקה
הקוד נבנה כחבילת מקור מלאה, אך לא ניתן לקמפל או לחתום אפליקציית iOS בסביבת Windows. יש לבצע Build ראשון ב־Xcode על Mac ולפתור התאמות חתימה/Container בהתאם ל־Team שלך.
