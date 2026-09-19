import os
import re

swift_files = []
for root, dirs, files in os.walk("Rclone GUI"):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

for path in swift_files:
    with open(path, "r") as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        # Very simple heuristic: if a line has an odd number of unescaped quotes, it's likely a syntax error.
        # But we must ignore multi-line strings """
        if '"""' in line: continue
        
        # Strip comments
        code = line.split("//")[0]
        
        # Count unescaped quotes
        # A quote is unescaped if it is not preceded by a backslash
        quotes = len(re.findall(r'(?<!\\)"', code))
        
        if quotes % 2 != 0:
            print(f"{path}:{i+1}: {line.strip()}")
