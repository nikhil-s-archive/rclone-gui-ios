import json
import os
import re

def process():
    xcstrings_path = "Rclone GUI/Localizable.xcstrings"
    with open(xcstrings_path, "r") as f:
        data = json.load(f)

    # Build mapping: fr_string -> en_string
    mapping = {}
    new_strings = {}
    
    for fr_key, val in data.get("strings", {}).items():
        en_val = None
        if "localizations" in val and "en" in val["localizations"]:
            en_val = val["localizations"]["en"].get("stringUnit", {}).get("value")
        
        # If we have an english translation, we'll swap it.
        # Otherwise, we keep the original key.
        if en_val and en_val != fr_key:
            en_key = en_val
            mapping[fr_key] = en_key
            
            # Create new entry where key is English, and add French localization
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
            # Copy other localizations if they exist
            for lang, lang_val in val.get("localizations", {}).items():
                if lang not in ["en", "fr"]:
                    new_entry["localizations"][lang] = lang_val
            
            new_strings[en_key] = new_entry
        else:
            new_strings[fr_key] = val

    data["strings"] = new_strings

    # Save new xcstrings
    with open(xcstrings_path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"Built mapping for {len(mapping)} strings.")

    # Now replace in Swift files
    swift_files = []
    for root, dirs, files in os.walk("Rclone GUI"):
        for file in files:
            if file.endswith(".swift"):
                swift_files.append(os.path.join(root, file))

    count_replacements = 0
    for swift_file in swift_files:
        with open(swift_file, "r") as f:
            content = f.read()
        
        original_content = content
        
        # Sort keys by length descending to avoid partial matches
        for fr_key in sorted(mapping.keys(), key=len, reverse=True):
            en_key = mapping[fr_key]
            
            # We want to replace "fr_key" with "en_key"
            # But only inside strings. This is a bit tricky with regex,
            # but since they are literal strings in SwiftUI, we can just replace the exact literal.
            # We escape the quotes
            fr_literal = f'"{fr_key}"'
            en_literal = f'"{en_key}"'
            
            content = content.replace(fr_literal, en_literal)
            
            # Also replace in String(localized: "fr_key")
            # SwiftUI Text("fr_key") is already covered by the literal replacement
            
        if content != original_content:
            with open(swift_file, "w") as f:
                f.write(content)
            count_replacements += 1

    print(f"Modified {count_replacements} Swift files.")

if __name__ == "__main__":
    process()
