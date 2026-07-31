from pypdf import PdfReader, PdfWriter

# 1. Ouvrir le fichier d'origine
reader = PdfReader(r"C:\Users\Bmd\Documents\ISE\Cours\ISE3\Stage ITIE\rapports\donnée\flux financiers\2024.pdf")
writer = PdfWriter()

# 2. Définir vos intervalles (Format humain : [page_debut, page_fin])
# Exemple : extrait de la page 2 à 5, puis de la page 10 à 15
intervalles = [[110,111]]

# 3. Extraire et fusionner
for debut, fin in intervalles:
    # Python commence à 0, donc on soustrait 1 au début.
    # On ne touche pas à la fin car les slices excluent le dernier élément.
    for page in reader.pages[debut - 1:fin]:
        writer.add_page(page)

# 4. Enregistrer le résultat
with open(r"C:\Users\Bmd\Documents\ISE\Cours\ISE3\Stage ITIE\rapports\donnée\flux financiers\2024.pdf", "wb") as fichier_sortie:
    writer.write(fichier_sortie)
