import os

replacements = {
    '"Téléchargement"': '"Download"',
    '"Envoi"': '"Upload"',
    '"Déplacement"': '"Move"',
    '"Copie"': '"Copy"',
    '"Sync"': '"Sync"',
    '"Suppression"': '"Delete"',
    '"\\(action) en cours…"': '"\\(action) in progress..."',
    '"Dossier \\(entry.name), modifié \\(formatDate(entry.modTime))"': '"Folder \\(entry.name), modified \\(formatDate(entry.modTime))"',
    '"Fichier \\(entry.name), \\(formatBytes(entry.size)), modifié \\(formatDate(entry.modTime))"': '"File \\(entry.name), \\(formatBytes(entry.size)), modified \\(formatDate(entry.modTime))"',
    '"Les fichiers suivants seront écrasés sans possibilité d\'annulation : \\(preview)\\(suffix)."': '"The following files will be overwritten without possibility of undo: \\(preview)\\(suffix)."',
    '"\\(count) éléments"': '"\\(count) items"',
    '"Coller (\\(suffix), copier)"': '"Paste (\\(suffix), copy)"',
    '"Échec du collage : \\(error.localizedDescription)"': '"Paste failed: \\(error.localizedDescription)"',
    '"suppression"': '"delete"',
    '"mise à la corbeille"': '"move to trash"',
    '"\\(trashedCount) élément\\(trashedCount > 1 ? \\"s\\" : \\"\\") déplacé\\(trashedCount > 1 ? \\"s\\" : \\"\\") à la corbeille."': '"\\(trashedCount) item\\(trashedCount > 1 ? \\"s\\" : \\"\\") moved to trash."',
    '"\\(folderCount) dossiers"': '"\\(folderCount) folders"',
    '"\\(fileCount) fichiers"': '"\\(fileCount) files"',
    '"\\(total) élément\\(nounSuffix)"': '"\\(total) item\\(nounSuffix)"',
    '"\\(head) · déchiffrés à la volée"': '"\\(head) · decrypted on the fly"',
    '"Le dossier sera créé dans \\(folderTitle)."': '"The folder will be created in \\(folderTitle)."',
    '"Téléchargement enqueued : "': '"Download enqueued : "',
    '"Échec de mise en file de téléchargement ("': '"Failed to enqueue download ("',
    '"Téléchargement (tap) : "': '"Download (tap) : "',
    '"Échec téléchargement tap ("': '"Failed to download (tap) ("',
    '"Déplacement enqueued : "': '"Move enqueued : "',
    '"Échec déplacement "': '"Move failed "',
    '"\\(entries.count) élément\\(entries.count > 1 ? \\"s\\" : \\"\\")"': '"\\(entries.count) item\\(entries.count > 1 ? \\"s\\" : \\"\\")"',
    '"\\(operationTitle) remote batch ajouté : "': '"\\(operationTitle) remote batch added : "',
    '"Ce domaine est enregistré uniquement sur cet appareil pour le remote « \\(remote) ». Il doit déjà servir publiquement la racine du bucket. Pour Qiniu Kodo ou un autre backend qui renvoie le bucket dans le chemin, saisis ici le préfixe à retirer, par exemple `aab`."': '"This domain is registered only on this device for the remote \'\\(remote)\'. It must already publicly serve the root of the bucket. For Qiniu Kodo or another backend that returns the bucket in the path, enter the prefix to remove here, for example `aab`."',
    '"Le remote « \\(remote.name) » sera retiré de rclone.conf. Tes fichiers distants ne sont pas supprimés."': '"The remote \'\\(remote.name)\' will be removed from rclone.conf. Your remote files will not be deleted."',
    '"1 transfert en cours"': '"1 transfer in progress"',
    '"\\(n) transferts en cours"': '"\\(n) transfers in progress"',
    '"Le fichier n\'a pas pu être préparé."': '"The file could not be prepared."',
    '"Fichier \\(ext)"': '"File \\(ext)"'
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
            content = content.replace('\\(action) batch impossible', '\\(action) batch failed')
            if content != original:
                with open(path, "w") as f:
                    f.write(content)
                count += 1
print(f"Modified {count} files")
