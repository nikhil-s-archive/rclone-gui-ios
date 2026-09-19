import re

with open("Rclone GUI/Views/Home/HomeView.swift", "r") as f:
    content = f.read()

start_delete = content.find("    private func refreshPhotoSyncSnapshot() async {")
end_delete = content.find("    private var firstRemoteDestination: NavigationDestination?")

if start_delete != -1 and end_delete != -1:
    new_func = """    private func refreshPhotoSyncSnapshot() async {
        photoSyncIsRunning = PhotoSyncService.shared.isSyncingPublic
        photoSyncSummary = await PhotoSyncService.shared.currentSummary()
    }

"""
    content = content[:start_delete] + new_func + content[end_delete:]

with open("Rclone GUI/Views/Home/HomeView.swift", "w") as f:
    f.write(content)
