# BASKET CORP — WORKFLOW AUTONOME OBLIGATOIRE

## Portée et baseline du projet

Ce fichier régit exclusivement le dépôt iOS ISOLATED et ses sous-répertoires :
/Users/isidroetannebosch/Dev/BasketManager_mobileiOS_ISOLATED

Baseline validée de ce dépôt :
BASELINE_IOS = a9c09fc59d1507e3b11050844743919be40d4c15

Les deux dépôts sont indépendants. Les sections STEAM et iOS ci-dessous
identifient leurs règles respectives ; la référence à l'autre dépôt est un
contexte d'isolation, jamais une autorisation d'y intervenir ou de le synchroniser.
La baseline de l'autre dépôt ne doit jamais être utilisée pour ce dépôt.

Pour toute demande de modification de code :

1. AUDIT INITIAL AUTOMATIQUE

Avant toute modification :
- vérifier pwd ;
- branche active ;
- HEAD ;
- git status ;
- changements suivis préexistants ;
- fichiers non suivis pertinents ;
- baseline validée du projet.

Ne jamais écraser, supprimer, nettoyer ou intégrer implicitement des
modifications préexistantes.


2. IDENTIFICATION DU PÉRIMÈTRE

Identifier précisément :
- comportement demandé ;
- fichiers réellement concernés ;
- chemins d'exécution concernés ;
- systèmes voisins présentant un risque de régression.

Ne pas élargir le périmètre sans nécessité démontrée.


3. PATCH MINIMAL

Appliquer uniquement le changement nécessaire.

Règles :
- réutiliser les fonctions et structures existantes ;
- aucun refactor opportuniste ;
- aucun renommage esthétique ;
- aucune réorganisation sans nécessité ;
- préserver les comportements stables ;
- préserver les différences volontaires Steam / iOS ;
- ne jamais synchroniser automatiquement les deux projets.


4. TESTS TECHNIQUES AUTOMATIQUES

Après le patch, exécuter automatiquement tous les contrôles disponibles et
pertinents qui ne nécessitent pas d'intervention utilisateur :

- git diff ;
- git diff --check ;
- syntaxe / parsing ;
- imports ;
- tests ciblés existants ;
- contrôles statiques ;
- cohérence des appels/signatures ;
- vérifications de sauvegarde/persistance si concernées.

Ne pas prétendre avoir exécuté Godot si Godot n'a pas réellement été lancé.


5. REVIEWER INDÉPENDANT AUTOMATIQUE

À la fin de CHAQUE patch de code, effectuer automatiquement une seconde passe
de review strictement orientée détection de défauts.

Le Reviewer doit :
- partir de la baseline validée correspondante ;
- identifier le diff exact du patch ;
- distinguer le nouveau patch des changements préexistants ;
- rechercher uniquement des régressions démontrables ;
- vérifier les chemins alternatifs concernés ;
- rechercher double exécution, état incohérent, perte de données,
  sauvegarde écrasée, appel manquant, divergence de logique,
  erreur probable à l'exécution et effet de bord ;
- vérifier les systèmes voisins lorsque le patch peut les affecter ;
- ne proposer aucun refactor esthétique.

Chaque finding doit comporter :
- fichier ;
- ligne ;
- gravité : bloquant / important / mineur ;
- scénario reproductible ;
- cause ;
- correction minimale.


6. BOUCLE DE CORRECTION

Si le Reviewer détecte une anomalie démontrable directement causée par le patch :
- appliquer uniquement la correction minimale ;
- relancer les tests concernés ;
- relancer automatiquement le Reviewer.

Ne pas demander à l'utilisateur de piloter cette boucle.

Si une correction nécessiterait un changement fonctionnel non demandé ou une
décision produit, s'arrêter et demander validation.


7. CONTRÔLES SPÉCIFIQUES BASKET CORP

Lorsqu'ils sont concernés, vérifier systématiquement :

- sauvegardes ;
- compatibilité anciennes sauvegardes ;
- progression ;
- saisons ;
- matchs ;
- tournois ;
- mercato ;
- finances ;
- popularité ;
- stade ;
- missions / compteurs ;
- récompenses ;
- chemins normal / accéléré ;
- réexécution / double comptage ;
- navigation ;
- traductions ;
- desktop / mobile lorsque pertinent.

Ne jamais considérer qu'un comportement Steam doit nécessairement être
identique à iOS.


8. PARTICULARITÉ STEAM

Projet :
/Users/isidroetannebosch/Dev/BasketManager_GIT

Baseline initiale validée :
49b1960086445910b234cec38d569a2c23fb6a3d

Les modifications locales déjà présentes au moment de la définition de cette
baseline ne doivent jamais être assimilées automatiquement à un nouveau patch.

Les nombreux fichiers non suivis ne doivent jamais être nettoyés,
ajoutés ou supprimés sans demande explicite.


9. PARTICULARITÉ iOS ISOLATED

Projet :
/Users/isidroetannebosch/Dev/BasketManager_mobileiOS_ISOLATED

Baseline initiale validée :
b250b920ae2bd847db4b17d32c19ab5a97425abf

Préserver strictement l'isolation iOS.

Ne jamais importer automatiquement une adaptation Steam.

Les modifications locales et suppressions préexistantes relevées lors de la
création de la baseline doivent être distinguées de tout nouveau patch.


10. TESTS UTILISATEUR

À la fin, ne demander à l'utilisateur que les tests impossibles à réaliser
automatiquement.

Ils doivent être :
- courts ;
- ciblés ;
- numérotés ;
- avec résultat attendu explicite.

Éviter de demander des tests sans rapport direct avec le patch.


11. GIT — INTERDICTIONS

Sauf demande explicite de l'utilisateur :

- aucun git add ;
- aucun commit ;
- aucun push ;
- aucun reset ;
- aucun checkout destructif ;
- aucun clean ;
- aucun stash ;
- aucun tag ;
- aucune suppression de fichier non suivi.


12. BASELINES

Une baseline ne doit JAMAIS avancer automatiquement.

Cycle :

BASELINE VALIDÉE
→ patch
→ tests automatiques
→ Reviewer
→ éventuelle correction
→ nouvelle review
→ tests utilisateur si nécessaires
→ validation utilisateur
→ commit uniquement si demandé
→ proposition du nouveau HEAD comme nouvelle baseline.

Le nouveau HEAD ne devient baseline qu'après validation explicite de
l'utilisateur.


13. COMPTE RENDU AUTOMATIQUE

À la fin de chaque intervention de code, fournir automatiquement :

PATCH
- fichiers modifiés ;
- nombre approximatif de lignes ajoutées/supprimées ;
- comportement modifié.

TESTS AUTOMATIQUES
- tests exécutés ;
- résultat.

REVIEWER
- PASS ou findings ;
- corrections éventuellement réalisées.

RISQUES RÉSIDUELS
- uniquement les risques réels restant à tester.

TESTS UTILISATEUR
- uniquement ceux réellement nécessaires.

GIT
- branche ;
- HEAD ;
- status ;
- confirmation explicite qu'aucun commit/push n'a été effectué.

BASELINE
- baseline utilisée ;
- ne jamais annoncer une nouvelle baseline comme validée sans accord.


14. PRINCIPE D'AUTONOMIE

L'utilisateur exprime le résultat fonctionnel recherché.

Il ne doit pas avoir à demander séparément :
"audite",
"teste",
"fais une review",
"vérifie les régressions",
"compare avec la baseline".

Ces opérations font désormais partie du travail normal de l'agent.


## État local préexistant à l'installation du workflow

État relevé le 29 septembre 2026 pour iOS ISOLATED :
10 fichiers suivis modifiés, 8 suppressions non indexées et 24 entrées non suivies (répertoires regroupés par git status). Les fichiers modifiés sont client/godot/export_presets.cfg, client/godot/i18n/translations.csv, les cinq client/godot/i18n/translations.{en,es,fr,it,pt}.translation, client/godot/project.godot, client/godot/scenes/menu.gd et client/godot/scripts/MatchSim.gd. Les suppressions concernent Steam/capsule_basket-corp_920x430.png et les sept captures ecran_{bus,finance,menu,myteam,sponsors,stade,tournois}_1920x1080.png dans Steam/screenshots_1920x1080/.

Tous ces changements sont antérieurs à l'installation de ce workflow. Ils ne
font pas partie du patch AGENTS.md et ne doivent être ni modifiés, restaurés,
nettoyés, ajoutés, ni assimilés implicitement à un nouveau patch.
Les nombres ci-dessus sont un relevé initial, pas une liste figée : refaire
l'audit à chaque intervention. Le HEAD de baseline ne capture pas l'état local.
Avant chaque patch, relever le diff local préexistant pour pouvoir isoler
exactement les changements de l'intervention sans écrire de fichier supplémentaire
non demandé. Ne jamais attribuer une différence à un patch sur la seule base du HEAD.

## Modalités de la review automatique

La passe Reviewer est strictement en lecture seule, distincte de la phase de
développement. Les corrections sont appliquées uniquement dans la phase de
développement, puis suivies des contrôles concernés et d'une nouvelle review.
Ne jamais choisir automatiquement le dernier commit : retrouver le diff exact
et son historique à partir de la baseline validée du dépôt.
Si le patch ne peut pas être identifié avec certitude, arrêter son audit et
indiquer précisément la référence manquante.
Distinguer anomalie démontrée, risque résiduel et simple hypothèse. Une possibilité
théorique ne doit pas être présentée comme une anomalie.
Si aucun défaut démontrable n'est trouvé, indiquer :
« Aucune régression démontrable trouvée dans le diff audité. »
Lors d'une intervention exclusivement Reviewer, confirmer : « Aucun fichier modifié. »

Toute demande fonctionnelle déclenche automatiquement : audit initial → périmètre
→ patch minimal → tests techniques disponibles → Reviewer indépendant → correction
minimale si nécessaire → nouvelle review → compte rendu → tests utilisateur
uniquement si nécessaires. Aucun rappel séparé de l'utilisateur n'est requis.
Aucune baseline ne peut être avancée sans instruction explicite de l'utilisateur.
