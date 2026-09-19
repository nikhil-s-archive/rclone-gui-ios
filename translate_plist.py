import json
import os

def process():
    xcstrings_paths = ["Rclone GUI/InfoPlist.xcstrings", "Rclone GUI/AppShortcuts.xcstrings"]
    for path in xcstrings_paths:
        if not os.path.exists(path): continue
        with open(path, "r") as f:
            data = json.load(f)

        mapping = {}
        new_strings = {}
        
        for fr_key, val in data.get("strings", {}).items():
            en_val = None
            if "localizations" in val and "en" in val["localizations"]:
                en_val = val["localizations"]["en"].get("stringUnit", {}).get("value")
            
            if en_val and en_val != fr_key:
                en_key = en_val
                mapping[fr_key] = en_key
                new_entry = {
                    "extractionState": val.get("extractionState", "manual"),
                    "localizations": {
                        "fr": {
                            "stringUnit": {
                                "state": "translated",
                                "value": fr_key
                            }
                        }
                    }
                }
                for lang, lang_val in val.get("localizations", {}).items():
                    if lang not in ["en", "fr"]:
                        new_entry["localizations"][lang] = lang_val
                
                new_strings[en_key] = new_entry
            else:
                new_strings[fr_key] = val

        data["strings"] = new_strings

        with open(path, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"Processed {path}: mapped {len(mapping)} strings.")

if __name__ == "__main__":
    process()
