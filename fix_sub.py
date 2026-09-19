import re

with open("Rclone GUI/Core/SubscriptionStatus.swift", "r") as f:
    content = f.read()

# Make isUnlocked always true
content = re.sub(
    r'public var isUnlocked: Bool \{\n\s*entitlement == \.trial \|\| entitlement == \.active\n\s*\}',
    'public var isUnlocked: Bool { true }',
    content
)

# Make hasLifetimeAccess always true
content = re.sub(
    r'public var hasLifetimeAccess: Bool \{\n\s*isUnlocked && SubscriptionProductID\.isLifetime\(productID\)\n\s*\}',
    'public var hasLifetimeAccess: Bool { true }',
    content
)

with open("Rclone GUI/Core/SubscriptionStatus.swift", "w") as f:
    f.write(content)
