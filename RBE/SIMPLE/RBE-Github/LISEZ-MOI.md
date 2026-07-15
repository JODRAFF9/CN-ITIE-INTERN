# OpenRBE — Guide de connexion à Google Drive

La plateforme est désormais **un seul fichier autonome** : `index.html`.
Plus aucun script Python, aucun lanceur, aucun panneau administrateur.
Les données sont lues **en direct** depuis votre fichier sur Google Drive, et
le site se met à jour **à chaque ouverture**.

---

## ⚠️ Le point technique important (à lire)

Un site composé d'un simple `index.html` s'exécute dans le navigateur du visiteur.
Pour des raisons de sécurité (CORS), **Google Drive interdit à une page web de
télécharger directement un fichier `.xlsx` brut**. Lire l'Excel binaire tel quel
depuis Drive ne fonctionne donc pas de façon fiable, sans serveur ni clé d'API.

**La solution simple, gratuite, sans serveur et sans clé d'API** consiste à garder
le fichier sur Google Drive **sous forme de Google Sheet**. Le site lit alors les
données via le lien d'export CSV de Google (autorisé par le navigateur).
Vous continuez à modifier une feuille de calcul normale ; le site reflète les
changements automatiquement.

---

## ✅ Ce dont j'ai besoin de votre part (3 choses)

1. **Le fichier en Google Sheet sur le Drive.**
   Sur Google Drive : clic droit sur le `.xlsx` → *Ouvrir avec* → **Google Sheets**
   (ou *Fichier → Enregistrer comme Google Sheets*). Vous l'éditez ensuite normalement.

2. **Le partage public en lecture seule.**
   Bouton **Partager** → *Accès général* → **« Tous les utilisateurs disposant du lien »**
   → rôle **Lecteur**.
   (Sans cela, le navigateur reçoit la page de connexion Google au lieu des données.)

3. **Le lien de partage**, de la forme :
   `https://docs.google.com/spreadsheets/d/XXXXXXXXXXXX/edit?usp=sharing`
   Précisez aussi :
   - le **nom de l'onglet** s'il n'est pas `Feuil1` ;
   - que la **1re ligne contient les en-têtes** et que les **13 colonnes** sont
     dans l'ordre d'origine (Région, Dénomination Sociale, Prénom et Nom Bénéficiaire,
     Date d'acquisition, % Action Direct, % Voix Direct, Nationalité, Pays de résidence,
     Est Une PPE, Fonction PPE, NomPPE, Greffe, Regions).

> Aucune clé d'API, aucun compte de service, aucun serveur n'est nécessaire.
> Les données d'un registre **ouvert** sont publiques en lecture — c'est l'objectif d'OpenRBE.

---

## 🔧 Où coller le lien

Ouvrez `index.html` dans un éditeur de texte, et tout en haut du script repérez la ligne :

```js
const GOOGLE_SHEET_URL = "";
```

Collez votre lien entre les guillemets :

```js
const GOOGLE_SHEET_URL = "https://docs.google.com/spreadsheets/d/XXXXXXXXXXXX/edit?usp=sharing";
```

Enregistrez. C'est tout — à la prochaine ouverture, la pastille en haut à droite
passe de « Instantané » à **« En direct »** et le pied de page indique
« Source de données : Google Drive (en direct) ».

> Vous pouvez aussi me **transmettre le lien** et je l'intègre pour vous.

---

## 🌐 Mise en ligne (pour que les visiteurs aient la mise à jour)

`index.html` fonctionne déjà en double-cliquant dessus (en local).
Pour le rendre public et que **chaque visiteur** profite de la mise à jour automatique,
hébergez le fichier au choix sur : **GitHub Pages**, **Netlify**, **Cloudflare Pages**,
ou le serveur web de l'ITIE. Il suffit d'y déposer ce seul fichier.

---

## 🔁 Comment fonctionne la mise à jour

- Au chargement, le site affiche d'abord l'**instantané intégré** (628 enregistrements)
  pour un démarrage instantané, même hors-ligne.
- En arrière-plan, il récupère la **dernière version** du Google Sheet et remplace
  les données sans recharger la page (filtres, graphiques, carte, réseau, recherche
  et exports se rafraîchissent).
- Un anti-cache garantit que c'est toujours la version la plus récente.
- Le bouton « pastille » en haut à droite force une actualisation à la demande,
  et le site re-synchronise automatiquement toutes les 5 minutes.

Donc : **vous modifiez le Google Sheet sur Drive → la mise à jour est immédiate à l'ouverture du site.**

---

## ℹ️ Notes

- Si le lien est vide ou la feuille non partagée, le site reste sur l'instantané intégré
  (mode hors-ligne) et l'indique clairement.
- Le traitement des données (régions, PPE, pourcentages bornés à 0–100 %,
  nationalités normalisées comme SÉNÉGAL/ÉGYPTE, dates) est **identique** à celui
  de l'instantané, pour une cohérence parfaite entre les deux sources.
