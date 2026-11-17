#!/usr/bin/env python3
"""Einmaliges Setup für wa:sh – kann gefahrlos mehrfach laufen.

1. Erzeugt das eigene Plugin packages/wash_live (Gerüst per `flutter create
   --template=plugin`) und spielt die Quellen aus tool/wash_live ein:
   Android-Dienst + Live Update, iOS Live Activity.
2. Erzeugt android/ und ios/ der App und trägt Berechtigungen, Receiver,
   Desugaring, App-Name, Live-Activity-Schalter und URL-Schema ein.
3. Legt die Dateien der iOS-Widget-Erweiterung nach ios/WashLiveWidget/.
4. Erzeugt das App-Icon für Android und iOS.

Aufruf aus dem Projektordner:  python3 tool/setup.py
"""
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOL = ROOT / "tool"
PLUGIN = ROOT / "packages" / "wash_live"
APP_NAME = "wa:sh"


def run(cmd, cwd=ROOT):
    print("$", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


def patch(path, fn, label):
    if not path.exists():
        print(f"  – {label}: {path.relative_to(ROOT)} nicht gefunden, übersprungen")
        return
    old = path.read_text(encoding="utf-8")
    new = fn(old)
    if new != old:
        path.write_text(new, encoding="utf-8")
        print(f"  ✓ {label}")
    else:
        print(f"  = {label} (schon erledigt)")


def copy(src, dst, label):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    print(f"  ✓ {label}")


# ── 1. Plugin wash_live ─────────────────────────────────────────────

def setup_plugin():
    print("Plugin wash_live:")
    if not (PLUGIN / "pubspec.yaml").exists():
        PLUGIN.parent.mkdir(parents=True, exist_ok=True)
        run(["flutter", "create", "--template=plugin", "--platforms", "android,ios",
             "-a", "java", "--org", "de.k0rbi02", "--project-name", "wash_live", str(PLUGIN)])

    # Dart-API: nur unsere eine Datei. Alles, was die Vorlage sonst anlegt
    # (Platform-Interface, Pigeon, Beispiel-App, Tests), fliegt raus.
    for f in (PLUGIN / "lib").rglob("*.dart"):
        if f.name != "wash_live.dart":
            f.unlink()
    for d in ("example", "test", "pigeons"):
        shutil.rmtree(PLUGIN / d, ignore_errors=True)
    copy(TOOL / "wash_live/lib/wash_live.dart", PLUGIN / "lib/wash_live.dart", "Dart-API")

    # Android: Java-Quellen, Manifest (Dienst + Rechte), Statusleisten-Symbol.
    main = PLUGIN / "android/src/main"
    shutil.rmtree(main / "kotlin", ignore_errors=True)
    java = main / "java/de/k0rbi02/wash_live"
    if java.exists():
        for f in java.glob("*.java"):
            f.unlink()
    for f in (TOOL / "wash_live/android/java").glob("*.java"):
        copy(f, java / f.name, f"Android: {f.name}")
    copy(TOOL / "wash_live/android/AndroidManifest.xml", main / "AndroidManifest.xml", "Android: Manifest")
    for sub in ("drawable", "raw", "layout", "xml", "values", "values-de"):
        for f in (TOOL / "wash_live/android/res" / sub).glob("*.xml"):
            copy(f, main / "res" / sub / f.name, f"Android: {sub}/{f.name}")

    # iOS: Plugin-Klasse ersetzen, Attribute daneben legen.
    swift = next((p for p in (PLUGIN / "ios").rglob("WashLivePlugin.swift")), None)
    if swift is None:
        print("  ! iOS: WashLivePlugin.swift im Plugin nicht gefunden – iOS-Teil übersprungen")
    else:
        for other in swift.parent.glob("*.swift"):
            if other.name not in ("WashLivePlugin.swift", "WashLiveAttributes.swift"):
                other.unlink()  # z. B. von Pigeon erzeugter Code der Vorlage
        copy(TOOL / "wash_live/ios/WashLivePlugin.swift", swift, "iOS: WashLivePlugin.swift")
        copy(TOOL / "wash_live/ios/WashLiveAttributes.swift", swift.parent / "WashLiveAttributes.swift",
             "iOS: WashLiveAttributes.swift")


# ── 2. App ──────────────────────────────────────────────────────────

PERMISSIONS = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
"""

RECEIVERS = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""


INTENT_FILTERS = """    <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="wash"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="wash"/>
            </intent-filter>
"""


def patch_manifest(text):
    if "POST_NOTIFICATIONS" not in text:
        text = text.replace("    <application", PERMISSIONS + "    <application", 1)
    if "android.permission.INTERNET" not in text:
        # Home Assistant
        text = text.replace("    <application", '    <uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    if "usesCleartextTraffic" not in text:
        # Home Assistant im Heimnetz läuft meist über http://
        text = text.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    if "dataExtractionRules" not in text:
        # Sicherung: Programme ja, verschlüsselte HA-Kopplung nein.
        text = text.replace("<application", '<application\n        android:dataExtractionRules="@xml/data_extraction_rules"\n        android:fullBackupContent="@xml/backup_rules"', 1)
    if "localeConfig" not in text:
        # Eigene App-Sprache wählbar (Android 13+)
        text = text.replace("<application", '<application\n        android:localeConfig="@xml/locales_config"', 1)
    if "enableOnBackInvokedCallback" not in text:
        # Vorschau-Animation beim Zurückwischen (Android 14+)
        text = text.replace("<application", '<application\n        android:enableOnBackInvokedCallback="true"', 1)
    if "android:scheme=\"wash\"" not in text:
        # wash://start?… aus Links und von NFC-Stickern an der Maschine
        text = text.replace("</activity>", INTENT_FILTERS + "        </activity>", 1)
    if "flutter_deeplinking_enabled" not in text:
        # Links verarbeitet die App selbst (Plugin wash_live), nicht der Flutter-Router
        text = text.replace("</activity>", '    <meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>\n        </activity>', 1)
    if "ScheduledNotificationReceiver" not in text:
        text = text.replace("    </application>", RECEIVERS + "    </application>", 1)
    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', text, count=1)
    return text


def patch_gradle_kts(text):
    if "isCoreLibraryDesugaringEnabled" not in text:
        text = text.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
    if "desugar_jdk_libs" not in text:
        text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    return text


SIGNING_HEAD = """import java.io.FileInputStream
import java.util.Properties

"""

SIGNING_LOAD = """// Release-Signatur: android/key.properties (lokal) bzw. aus den CI-Secrets erzeugt.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""

SIGNING_CONFIG = """    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {"""


def patch_signing_kts(text):
    if "keystorePropertiesFile" in text:
        return text
    text = SIGNING_HEAD + text
    text = text.replace("android {", SIGNING_LOAD + "android {", 1)
    text = text.replace("    buildTypes {", SIGNING_CONFIG, 1)
    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release")\n'
        '                else signingConfigs.getByName("debug")',
        1,
    )
    return text


def patch_gradle_groovy(text):
    if "coreLibraryDesugaringEnabled" not in text:
        text = text.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
    if "desugar_jdk_libs" not in text:
        text += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    return text


PLIST_LIVE = """	<key>NSSupportsLiveActivities</key>
	<true/>
"""

PLIST_URL = """	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>de.k0rbi02.wash</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>wash</string>
			</array>
		</dict>
	</array>
"""

# Home Assistant im Heimnetz (http, lokale Adressen)
PLIST_LANG = """	<key>CFBundleLocalizations</key>
	<array>
		<string>de</string>
		<string>en</string>
	</array>
"""

PLIST_NET = """	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
	<key>NSLocalNetworkUsageDescription</key>
	<string>wa:sh sends the status of washer and dryer to your Home Assistant. · wa:sh meldet den Stand von Waschmaschine und Trockner an dein Home Assistant.</string>
"""


def patch_plist(text):
    def name(key, t):
        return re.sub(rf"(<key>{key}</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{APP_NAME}\g<2>", t)
    text = name("CFBundleName", name("CFBundleDisplayName", text))
    for key, block in (("NSSupportsLiveActivities", PLIST_LIVE),
                       ("CFBundleURLTypes", PLIST_URL),
                       ("NSAppTransportSecurity", PLIST_NET),
                       ("CFBundleLocalizations", PLIST_LANG)):
        if key not in text:
            i = text.rfind("</dict>")
            text = text[:i] + block + text[i:]
    return text


def setup_app():
    run(["flutter", "create", "--org", "de.k0rbi02", "--project-name", "wash",
         "--platforms", "android,ios", "."])

    sample_test = ROOT / "test" / "widget_test.dart"
    if sample_test.exists() and "MyApp" in sample_test.read_text(encoding="utf-8"):
        sample_test.unlink()
        print("  ✓ Beispieltest der Vorlage entfernt")

    print("Android:")
    patch(ROOT / "android/app/src/main/AndroidManifest.xml", patch_manifest, "Manifest")
    kts = ROOT / "android/app/build.gradle.kts"
    if kts.exists():
        patch(kts, patch_gradle_kts, "Desugaring (build.gradle.kts)")
        patch(kts, patch_signing_kts, "Release-Signatur (build.gradle.kts)")
    else:
        patch(ROOT / "android/app/build.gradle", patch_gradle_groovy, "Desugaring (build.gradle)")

    for f in (TOOL / "android_res").rglob("*.xml"):
        rel = f.relative_to(TOOL / "android_res")
        copy(f, ROOT / "android/app/src/main/res" / rel, f"Ressource: {rel}")

    print("iOS:")
    patch(ROOT / "ios/Runner/Info.plist", patch_plist, "Info.plist (Name, Live Activities, URL-Schema)")
    assets = ROOT / "ios/Runner/Assets.xcassets"
    for d in (TOOL / "ios_shortcuts").glob("*.imageset"):
        shutil.copytree(d, assets / d.name, dirs_exist_ok=True)
        print(f"  ✓ Schnellstart-Icon: {d.stem}")
    for f in (TOOL / "ios_widget").glob("*.swift"):
        copy(f, ROOT / "ios/WashLiveWidget" / f.name, f"Widget-Erweiterung: {f.name}")


def main():
    if shutil.which("flutter") is None:
        sys.exit("flutter nicht gefunden – bitte zuerst das Flutter SDK installieren.")
    setup_plugin()
    setup_app()
    run(["flutter", "pub", "get"])
    print("App-Icon:")
    run(["dart", "run", "flutter_launcher_icons"])
    print("Startbildschirm:")
    run(["dart", "run", "flutter_native_splash:create"])
    print("\nFertig. Starten mit:  flutter run")
    print("iOS: Widget-Erweiterung einmalig in Xcode anlegen – siehe README.")


if __name__ == "__main__":
    main()
