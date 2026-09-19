import re
with open("RcloneFileProvider/AppGroupBridge.swift", "r") as f:
    content = f.read()

content = re.sub(
    r'public var isUnlocked: Bool \{\n\s*snapshot\?\.isUnlocked == true\n\s*\}',
    'public var isUnlocked: Bool { true }',
    content
)

with open("RcloneFileProvider/AppGroupBridge.swift", "w") as f:
    f.write(content)
