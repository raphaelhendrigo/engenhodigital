# Buildozer configuration for Engenho Digital Kivy app

[app]
# (str) Title of your application
title = Engenho Digital

# (str) Package name
package.name = app

# (str) Package domain (needed for android/ios packaging)
package.domain = com.engenhodigital

# (str) Source code where the main.py live
source.dir = .

# (list) Source files to include (comma separated)
source.include_exts = py,png,kv,atlas,md,txt

# (str) Application versioning (method 1)
version = 1.0.0

# (str) The main .py file to use as the main entry point for your app
main = main.py

# (list) Application requirements
requirements = python3,kivy,plyer

# (str) Presplash of the application (optional). Provide a real image when available.
presplash.filename = %(source.dir)s/assets/images/presplash.png

# (str) Icon of the application (optional).
icon.filename = %(source.dir)s/assets/images/icon.png

# (list) Permissions
android.permissions = INTERNET

# (str) Supported orientation (portrait, landscape or all)
orientation = portrait

# (list) Supported architectures
android.archs = arm64-v8a, armeabi-v7a

# (str) Release artifact format for Android (apk or aab). Use aab for Play Store.
android.release_artifact = aab

# (int) Target Android API (ensure it matches your SDK)
android.api = 35

# (int) Minimum API your APK will support
android.minapi = 21

# (bool) Indicate if the application should be fullscreen or not
fullscreen = 0

# (str) Custom source folders for requirements
# (list) Garden requirements

[buildozer]
log_level = 2
warn_on_root = 0

# Basic build steps (run inside Linux/WSL):
# 1) buildozer -v android debug      # generates a debug APK
# 2) buildozer android release       # signed Play-ready AAB (signing required)
