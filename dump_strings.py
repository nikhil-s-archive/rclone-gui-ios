import json

with open("Rclone GUI/Localizable.xcstrings", "r") as f:
    data = json.load(f)

for key, val in data["strings"].items():
    if "localizations" in val and "fr" in val["localizations"]:
        fr_data = val["localizations"]["fr"]
        if "stringUnit" in fr_data:
            fr = fr_data["stringUnit"]["value"]
            en = key
            print(f"'{fr}' -> '{en}'")
