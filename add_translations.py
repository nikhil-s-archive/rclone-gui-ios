import json

with open("Rclone GUI/Localizable.xcstrings", "r") as f:
    data = json.load(f)

new_strings = {
    "Lecteurs connectés": "Connected Drives",
    "1 lecteur connecté.": "1 connected drive.",
    "%lld lecteurs connectés.": "%lld connected drives."
}

for fr_key, en_val in new_strings.items():
    if fr_key not in data["strings"]:
        data["strings"][fr_key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": en_val
                    }
                }
            }
        }

with open("Rclone GUI/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

