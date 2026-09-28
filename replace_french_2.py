import os

replacements = {
    '"\\(displayedEntries.count) élément\\(displayedEntries.count > 1 ? \\"s\\" : \\"\\")"': '"\\(displayedEntries.count) item\\(displayedEntries.count > 1 ? \\"s\\" : \\"\\")"',
    '"\\(displayedEntries.count) résultat\\(displayedEntries.count > 1 ? \\"s\\" : \\"\\")"': '"\\(displayedEntries.count) result\\(displayedEntries.count > 1 ? \\"s\\" : \\"\\")"',
    '"Échec de la \\(action) : \\(error.localizedDescription)"': '"\\(action) failed: \\(error.localizedDescription)"',
    '"\\(selectedEntries.count) élément(s) \\(verb)(s) — colle-les dans un autre dossier."': '"\\(selectedEntries.count) item(s) \\(verb)(s) — paste them in another folder."',
    '"\\(selectedEntries.count) élément(s) coupé(s) — collez-les dans un autre dossier."': '"\\(selectedEntries.count) item(s) cut — paste them in another folder."',
    '"\\(selectedEntries.count) élément(s) copié(s) — collez-les dans un autre dossier."': '"\\(selectedEntries.count) item(s) copied — paste them in another folder."',
    '"Impossible de créer le dossier : \\(error.localizedDescription)"': '"Failed to create folder: \\(error.localizedDescription)"',
    '"Ajouté aux favoris."': '"Added to favorites."',
    '"Retiré des favoris."': '"Removed from favorites."',
    '"Téléchargement ajouté à la file."': '"Download added to queue."',
    '"Échec de téléchargement : \\(error.localizedDescription)"': '"Download failed: \\(error.localizedDescription)"',
    '"« \\(names[0]) » existe déjà"': '"\'\\(names[0])\' already exists"',
    '"\\(names.count) éléments existent déjà"': '"\\(names.count) items already exist"',
    '"Coller (\\(suffix), déplacer)"': '"Paste (\\(suffix), move)"',
    '"copié"': '"copied"',
    '"coupé"': '"cut"',
    '"Le dossier sera créé dans \\(folderTitle)."': '"The folder will be created in \\(folderTitle)."'
}

count = 0
for root, dirs, files in os.walk("Rclone GUI/Views"):
    for file in files:
        if file.endswith(".swift"):
            path = os.path.join(root, file)
            with open(path, "r") as f:
                content = f.read()
            original = content
            for fr, en in replacements.items():
                content = content.replace(fr, en)
            if content != original:
                with open(path, "w") as f:
                    f.write(content)
                count += 1
print(f"Modified {count} files")
