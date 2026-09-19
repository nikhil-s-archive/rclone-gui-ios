with open("Rclone GUI/Views/Home/HomeView.swift", "r") as f:
    content = f.read()

start_delete = content.find("    private var firstRemoteDestination: NavigationDestination?")
end_delete = content.find("    private func load() async {")

if start_delete != -1 and end_delete != -1:
    content = content[:start_delete] + content[end_delete:]

with open("Rclone GUI/Views/Home/HomeView.swift", "w") as f:
    f.write(content)
