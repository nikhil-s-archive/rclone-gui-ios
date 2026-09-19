import re

with open("Rclone GUI/Views/Settings/SettingsView.swift", "r") as f:
    content = f.read()

# We need to remove the section header and the view builder for subscriptionSection.
# Let's check how it's defined.
