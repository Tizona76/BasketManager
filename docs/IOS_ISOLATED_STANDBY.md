# iOS Isolated Stand-by — Basket Corp

## DO NOT MODIFY OR RELEASE FROM THIS CHECKPOINT WITHOUT AUDIT

Ce dépôt de travail isolé sert de référence iOS. Ne pas le confondre avec le dépôt de travail Desktop/Steam ou celui du backend Render, même si des fichiers et un historique communs existent dans Git. Tout changement futur commence par un audit Git, Godot, Xcode et du contexte build/release. Aucune reprise ne doit écraser une baseline App Store validée.

**État au 27 septembre 2026 : audit documentaire effectué, freeze distant non finalisé. Le dernier commit Cloud Save est local, non poussé. Aucun tag de stand-by n’a été créé.** Aucun build, export, installation iPhone, publication, commit ou push n’a été lancé pendant cet audit. Les observations de code ne valent pas nouvelle validation runtime.

## OFFICIAL RECOVERY POINT — état vérifié et cible proposée

| Élément | Valeur vérifiée |
|---|---|
| Dépôt local | `/Users/isidroetannebosch/Dev/BasketManager_mobileiOS_ISOLATED` |
| Remote origin fetch/push | `https://github.com/Tizona76/BasketManager.git` |
| Branche | `ios/mobile-isolated` |
| HEAD local / cible code proposée | `2d802d51185311bd267d1ea15504822fb8aa5f32` |
| origin/ios/mobile-isolated après fetch | `30d1c903ec72ba4b27f3e63cf84b7bdaad4e829a` |
| Merge-base | `30d1c903ec72ba4b27f3e63cf84b7bdaad4e829a` |
| Écart local / distant | 1 commit local, 0 commit distant non intégré |
| Commit Cloud Save | `2d802d51185311bd267d1ea15504822fb8aa5f32`, HEAD local uniquement |
| Baseline Git du pipeline release | `30d1c903ec72ba4b27f3e63cf84b7bdaad4e829a`, déjà sur origin |
| Tag officiel de stand-by existant | Aucun constaté |
| Tag code recommandé, non créé | `ios-isolated-standby-20260927` |
| Cible du tag code proposé | `2d802d51185311bd267d1ea15504822fb8aa5f32`, après publication contrôlée et confirmation |
| Tag runbook recommandé, non créé | `ios-isolated-standby-runbook-20260927` |
| Cible du tag runbook | Futur commit documentaire après commit/push ; SHA encore inconnu |
| Date d’audit | 2026-09-27 |

Les deux tags proposés devront être annotés, datés, explicites et immuables. Le tag code figera le commit iOS, pas les modifications locales non committées. Le tag runbook figera code + ce document et sera le point préféré de reprise humaine une fois publié. Ne jamais déplacer l’un pour remplacer l’autre.

Le tag historique `pre-ios-mobile-isolation-20260914` existe et pointe sur `203ae4c3abe652c0bc3c7ca345ffebbdf67e405b` ; c’est un tag léger antérieur aux travaux iOS inspectés, pas un checkpoint App Store ni le stand-by final. Les quatre commits ci-dessous ne sont contenus dans aucun tag local constaté après fetch. Aucun tag baseline App Store supplémentaire n’est recommandé : la publication exacte n’est pas démontrée et deux références code/runbook suffisent.

## Preuves Git et checkpoints

Précontrôle : chemin et branche conformes. Index vide ; git diff --check sans erreur. Le worktree est **DIRTY** : huit suppressions Steam suivies connues et des fichiers non suivis. Aucun autre diff suivi constaté. Le fetch origin --tags a confirmé que l’écart est strictement en avance d’un commit, sans divergence de lignées.

| Commit | Existe localement | Contenu dans branche locale | Contenu dans origin/ios/mobile-isolated | Parent / dépendance historique |
|---|---|---|---|---|
| `42110867d62951b04043306096976ad0061fac98` | YES | YES | YES | `a98617d41d2cfe7aabfe5fdf86cd99a1d0e36ce8` |
| `a7d7bf8b51646ad8ca3490a19193c1d34ac356ea` | YES | YES | YES | `42110867d62951b04043306096976ad0061fac98` |
| `30d1c903ec72ba4b27f3e63cf84b7bdaad4e829a` | YES | YES | YES | `a7d7bf8b51646ad8ca3490a19193c1d34ac356ea` |
| `2d802d51185311bd267d1ea15504822fb8aa5f32` | YES | YES, HEAD | NO | `30d1c903ec72ba4b27f3e63cf84b7bdaad4e829a` |

« Sur origin » signifie atteignable depuis les références distantes observées après fetch, pas preuve de déploiement ni de publication App Store. git branch -a --contains confirme la présence des trois premiers commits sur la branche distante, et uniquement la branche locale pour le quatrième. git tag --contains est vide pour chacun.

Fichiers touchés :

- `4211086` — fix(ios): restore required visual assets : `client/godot/assets/images/backgrounds/match_visiteur.png`, `save.png` et leurs deux `.import` ; 4 fichiers. Ressources incluses dans le code, pas une fonction dormante.
- `a7d7bf8` — fix(ios): harden season flow and complete localization : 22 fichiers. `client/godot/i18n/translations.csv` et les cinq `.en/.es/.fr/.it/.pt.translation` ; scènes `Coachs.gd`, `Coachs.tscn`, `Login.tscn`, `StadiumMinimal.gd`, `bootstrap.gd`, `login.gd`, `menu.gd` ; scripts `MatchSim.gd`, `MenuSaison.gd`, `Mercato.gd`, `MyTeam.gd`, `Selection.gd`, `ShopTokens.gd`, `TournoiA.gd`, `TournoiElite.gd`, `TournoiIntermediaire.gd`. Les scripts/scènes sont sous `client/godot/`. Correctifs actifs selon le parcours/platforme ; aucune activation par feature flag de stand-by.
- `30d1c90` — chore(ios): add reproducible App Store release pipeline : `client/godot/assets/images/BasketCorp_AppIcon_Base_1024.png`, `client/godot/export_presets.cfg`, `tools/ios_prepare_release.py`. Outillage à invocation explicite, sans build/signature/stage implicite.
- `2d802d5` — fix(ios): harden cloud save recovery and conflicts : exactement 7 fichiers détaillés ci-dessous. Ce commit ne change ni export preset ni pipeline release ni projet Godot.

## Baseline App Store — ce qui est prouvé

La baseline Git connue la plus récente du pipeline App Store est `30d1c90`, après restauration des assets et durcissement/localisation. Elle constitue une référence source release identifiable et poussée. **Publication App Store non prouvable par Git seul.** Le titre d’un commit et la présence d’un projet Xcode ne prouvent ni l’archive envoyée, ni sa validation, ni la version actuellement distribuée. La correspondance avec la dernière baseline App Store publiée doit être confirmée par les archives de release/App Store Connect dans un chantier autorisé ultérieur.

| Paramètre | Valeur observée | Nature de la preuve |
|---|---|---|
| MARKETING_VERSION | `1.0.0` | Attente du script versionné ; également dans les configurations Debug/Release du pbxproj local non suivi |
| CURRENT_PROJECT_VERSION | `1.0.0` | Même double observation, pas une preuve du build publié |
| Bundle ID | `com.isibosch.basketcorp` | Presets iOS suivis, script release, pbxproj local |
| iOS minimum | `15.0` | Attente IPHONEOS_DEPLOYMENT_TARGET du script et pbxproj local |
| App/product/display name natif | `BasketCorp` | Script de préparation et pbxproj local |
| Nom Godot | `BasketManager_Web` | `client/godot/project.godot`, ne pas confondre avec le display name natif corrigé |
| Main scene | `res://main.tscn` | project.godot |
| Features Godot | `4.5`, `Forward Plus` | project.godot |
| Toolchain release attendue | Godot `4.5.1`, empreintes templates/librairies figées | tools/ios_prepare_release.py |
| Architectures / familles | arm64 ; `1,2` (iPhone/iPad) | Attentes du pipeline |
| Signing observé | Automatic, équipe `2T3222NW4Y`, Apple Development | Script/pbxproj ; certificats et provisioning réels non validés ici |

Deux presets iOS coexistent :

- `iOS` : export vers `../../build/ios/BasketCorp.ipa`, export_project_only=false.
- `iOS Release` : export_path vide, export_project_only=true, non runnable ; l’opérateur doit donner une destination explicite hors dépôt.

Dans les deux presets, application/short_version et application/version sont des chaînes vides ; `project.godot` ne définit pas config/version. Ne pas déduire une version App Store publiée de ces valeurs vides. Les valeurs 1.0.0 sont vérifiées dans les attentes du pipeline et l’export Xcode local.

Le projet natif inspecté est `build/ios/BasketCorp.xcodeproj/project.pbxproj`, accompagné de `build/ios/BasketCorp/BasketCorp-Info.plist`. Ils sont **non suivis**, ne seront pas dans un tag et ne constituent pas une sortie reproductible fraîche de cet audit. L’Info.plist référence les variables PRODUCT_BUNDLE_IDENTIFIER, PRODUCT_NAME, MARKETING_VERSION et CURRENT_PROJECT_VERSION.

Le pipeline `tools/ios_prepare_release.py` exige un export Godot Release frais hors repo, contrôle les empreintes de templates/moteur/icônes, le PCK, les configurations natives et les orientations. Il prépare une allowlist de cinq fichiers natifs, corrige notamment l’affichage BasketCorp, les orientations iPhone paysage, le scheme et la méthode app-store-connect. Il refuse la dérive de templates/configuration. Il ne build, ne signe et ne stage pas. Ne pas le lancer pendant le freeze.

## Cloud Save — code actif local, non publié sur origin

Commit exact : `2d802d51185311bd267d1ea15504822fb8aa5f32`. Parent : baseline pipeline `30d1c903ec72ba4b27f3e63cf84b7bdaad4e829a`. Diff : 171 insertions, 13 suppressions dans les fichiers texte et cinq traductions binaires modifiées ; 7 fichiers au total :

```text
client/godot/scenes/menu.gd
client/godot/i18n/translations.csv
client/godot/i18n/translations.en.translation
client/godot/i18n/translations.es.translation
client/godot/i18n/translations.fr.translation
client/godot/i18n/translations.it.translation
client/godot/i18n/translations.pt.translation
```

Le diff exact peut être revu sans modification avec `git show 2d802d51185311bd267d1ea15504822fb8aa5f32` (les fichiers de traduction binaires y apparaissent comme tels).

Il durcit le Cloud Save existant ; ce n’est pas un nouveau Cloud moderne dormant. Les branches de récupération/conflit/timeout principales sont conditionnées par OS.has_feature("ios") et sont exécutables dans un build iOS de ce HEAD. Certaines adaptations de callback/signal/session sont communes au fichier partagé : ne pas transférer aveuglément le commit à Android/Desktop.

Comportements constatés par lecture :

- 401 avec detail=INVALID_TOKEN : au plus une récupération auth par tentative via un HTTPRequest séparé, puis retry du corps de sauvegarde original inchangé.
- Refresh via `/v1/auth/refresh` ; validation des tokens reçus, rotation du refresh si renvoyé, persistance locale requise avant retry. Échec de persistance, contexte profil/career changé, refresh changé ou second échec : terminaison et local conservé/dirty.
- 409 avec detail=REV_CONFLICT : message localisé, sauvegarde locale conservée, dirty maintenu, absence de rechargement immédiat du Cloud ; bloque les sauvegardes automatiques du couple profil/carrière en conflit.
- Le blocage est stocké dans les métadonnées SceneTree : survit à la recréation de la scène, pas à un redémarrage complet du processus. Les entrées utilisateur explicites restent distinctes des tentatives automatiques.
- Timeout 15 secondes pour Http/HttpAuth et le refresh dédié ; le callback iOS termine la tentative sans réoccuper immédiatement Http. Cela ne garantit pas qu’un serveur n’a pas committé avant perte de réponse.
- Signal cloud_save_attempt_completed pour le résultat terminal, afin que l’UI ne traite pas le 401 intermédiaire comme une fin définitive. Pas de reconstruction du body/revision/checksum pendant le retry auth.

Dépendances réseau déclarées dans menu.gd : `https://api.basketmanager-game.com`, `/v1/cloud/save`, `/v1/cloud/load`, `/v1/auth/refresh`. Le contrat exige des erreurs et payloads compatibles (INVALID_TOKEN, REV_CONFLICT, access_token, refresh_token éventuel, ok/rev), une auth correcte et des révisions serveur cohérentes. Ces endpoints n’ont pas été contactés. Ni état DB ni backend effectivement déployé ne sont prouvés par le tag iOS.

Risques de reprise : dérive du contrat API, session/token rotation, changement de carrière pendant une requête, conflit après redémarrage, commit serveur suivi d’un timeout et compatibilité des traductions importées. Refaire les tests ciblés iPhone ; aucune preuve de publication de ce commit ou de nouveau test runtime n’est fournie par cet audit.

## Cartographie des travaux présents

| Chantier | Checkpoint / origin | Actif ou dormant | Risque / tag dédié |
|---|---|---|---|
| Baseline source App Store | 30d1c90, poussé | Source release, publication non prouvée | Retenir le SHA ; pas de tag « publié » sans preuve |
| Pipeline reproductible | 30d1c90, poussé | Outil explicite | Dérive Godot/Xcode/signing ; inclus dans le freeze code |
| Assets requis | 4211086, poussé | Ressources du jeu | Imports/cache ne remplacent pas les sources ; pas de tag séparé |
| Localisation | a7d7bf8, poussé ; complément 2d802d5 local | CSV et cinq langues utilisées | Revalider import et UI ; pas de tag séparé |
| Season flow | a7d7bf8, poussé | Flux exécuté ; corrections overlay/récompenses/fond division | Test nouvelle saison et popups ; inclus dans freeze |
| Cloud recovery/conflicts | 2d802d5, non poussé | Durcissement actif sur parcours iOS | Publication contrôlée préalable obligatoire |
| UI iOS antérieure | Ancêtres poussés : a98617d, 58ec5e5, c076c3a, 3a0d9eb, da8ef58 notamment | Popup mercato, carte joueur, OTP/clavier, attente Cloud | Déjà dans la lignée baseline, pas de multiplication de tags |

La présence Git et la lecture des changements sont vérifiées ; « validé » historiquement ne signifie pas testé de nouveau ici. Aucun changement fonctionnel n’est proposé.

## Isolation et dépendances externes

Le projet Godot, les assets suivis et le pipeline source sont dans ce repo. Le pipeline résout ses ressources depuis ce repo et impose un export release externe ; il ne requiert pas de lecture du checkout Desktop ni du checkout Render. La recherche ciblée dans scènes/scripts Godot, project.godot et pipeline n’a trouvé aucune référence aux deux checkouts externes, aux fichiers Steam supprimés ou aux routes modernes /v2 lifecycle/économie.

Le freeze iOS ne nécessite aucune modification Android, Desktop ou backend. Des presets Web/Windows et du code partagé existent néanmoins : le repo n’est pas constitué exclusivement de fichiers iOS. Un tag Git capture l’arbre committé complet, y compris les fichiers Steam déjà suivis ; **il ne capture pas les huit suppressions locales non stagées**. Ces suppressions ne doivent pas entrer dans un commit de freeze. Aucun nettoyage/restauration n’est requis pour pousser un commit existant.

Dépendances externes : backend Cloud API, auth et contrats `/v1`, toolchain Godot/Xcode, signing et appareil. Le backend moderne dormant éventuel constitue un chantier séparé, non activé par ce tag. Le tag iOS ne garantit pas DB, secrets, configuration Render, backend déployé, certificats/provisioning ou état App Store Connect. Les autres dépôts ne sont pas figés par le tag iOS.

## Fichiers locaux hors scope

Conserver exactement les suppressions suivies non stagées :

```text
Steam/capsule_basket-corp_920x430.png
Steam/screenshots_1920x1080/ecran_bus_1920x1080.png
Steam/screenshots_1920x1080/ecran_finance_1920x1080.png
Steam/screenshots_1920x1080/ecran_menu_1920x1080.png
Steam/screenshots_1920x1080/ecran_myteam_1920x1080.png
Steam/screenshots_1920x1080/ecran_sponsors_1920x1080.png
Steam/screenshots_1920x1080/ecran_stade_1920x1080.png
Steam/screenshots_1920x1080/ecran_tournois_1920x1080.png
```

Ne pas les restaurer, supprimer davantage, stager ou committer. Les .DS_Store, build/, client/godot/godot/, imports PNG et anciens .uid constatés restent hors freeze. Les fichiers non suivis, caches, exports et backups ne sont pas inclus dans les tags ; ne pas les normaliser automatiquement. Le worktree DIRTY connu doit être distingué d’un changement fonctionnel inattendu, qui impose STOP.

## Publication contrôlée proposée — NE PAS EXÉCUTER sans validation humaine

Le seul commit à pousser actuellement est 2d802d5 ; origin est son parent exact. La publication fast-forward est possible dans l’état observé, mais cet audit **ne l’autorise ni ne l’exécute**.

Procédure séparée après validation :

1. Refaire le précontrôle repo/branche/HEAD/index, fetch origin --tags, revérifier l’écart 1/0 et le diff exact ; confirmer que les seuls écarts suivis du worktree restent les huit suppressions Steam connues.
2. Pousser uniquement la branche `ios/mobile-isolated`, sans force, si origin est toujours ancêtre. Aucun stage n’est nécessaire pour pousser ce commit déjà créé. Si origin a évolué, STOP et réauditer.
3. Fetch puis vérifier que origin/ios/mobile-isolated pointe exactement sur 2d802d51185311bd267d1ea15504822fb8aa5f32.
4. Après confirmation humaine, créer le tag code annoté `ios-isolated-standby-20260927` sur ce SHA exact, puis pousser uniquement ce tag et vérifier sa cible distante. Aucun tag existant ne doit être remplacé.
5. Valider ce runbook, committer uniquement `docs/IOS_ISOLATED_STANDBY.md` avec contrôle explicite du contenu de l’index, puis pousser la branche sans force. Ne jamais inclure les suppressions Steam ni les fichiers non suivis préexistants.
6. Après confirmation du commit documentaire sur origin, créer le tag annoté `ios-isolated-standby-runbook-20260927` sur son SHA alors connu ; pousser uniquement ce tag et vérifier son contenu code + document.

Le document décrit l’audit à date ; les références distantes et tags devront être recontrôlés à chaque reprise. Aucun SHA documentaire futur n’est inventé.

## Procédure future de reprise

1. `git fetch origin --tags` dans le dépôt iOS vérifié.
2. Vérifier git rev-parse --show-toplevel et remote ; ne pas opérer dans Desktop/Render.
3. Vérifier la branche ios/mobile-isolated et comprendre l’état du worktree/index.
4. Vérifier le tag de reprise publié, son annotation, sa cible et la présence du runbook. S’il manque, résoudre la publication, sans le recréer aveuglément.
5. Comparer la branche active au tag ; le repo iOS utilise ios/mobile-isolated, pas nécessairement main.
6. Ne jamais reset automatiquement ni déplacer un tag.
7. Créer une branche/worktree de reprise depuis le tag retenu ; garder intact le checkout actif et ses fichiers hors scope.
8. Auditer backend/API attendu et compatibilité `/v1`, sans supposer qu’il correspond à la date du tag.
9. Auditer project.godot, presets, assets, autoloads, imports et version Godot.
10. Auditer l’export Xcode frais, signing, bundle, versions/build, minimum iOS et PCK.
11. Effectuer un build ciblé explicitement autorisé.
12. Tester sur iPhone avec la chaîne complète ci-dessous.
13. Seulement après ces gates, envisager un nouveau release build dans un chantier dédié.

## Procédure iPhone — chaîne complète obligatoire

Références historiques fournies : appareil `00008110-000C5D323E7A201E`, bundle `com.isibosch.basketcorp`, DerivedData `/tmp/BasketCorpDerived`. L’appareil connecté et son état ne sont pas vérifiés pendant ce freeze ; le bundle est corroboré par les sources inspectées.

Chaîne future : **PCK → Xcode build → comparaison hash PCK → install → launch**.

Produire le PCK depuis le checkout approuvé ; builder le projet Xcode correspondant ; comparer SHA-256 du PCK source et du PCK effectivement embarqué dans le .app qui sera installé ; installer exactement cet artefact puis lancer et tester. Ne pas utiliser un ancien .app/DerivedData comme preuve du code courant. Vérifier l’identité et la disponibilité du device au moment du test. Ne pas effacer aveuglément /tmp/BasketCorpDerived ni les données utilisateur.

Tests ciblés : menu et orientation, nouvelle saison/popups, assets, cinq langues, Cloud Save nominal, 401 refresh/retry, 409 conflit, timeout, changement de profil/carrière, conservation locale. Cette chaîne n’a pas été exécutée pendant l’audit documentaire.

## Gardes release

- Ne pas changer MARKETING_VERSION ou CURRENT_PROJECT_VERSION sans chantier release.
- Ne pas republier depuis un vieux tag sans audit du client et du backend.
- Ne pas réutiliser un ancien DerivedData/ancien build Xcode aveuglément.
- Vérifier le PCK embarqué, signing, provisioning, bundle ID, version et build de l’artefact exact.
- Vérifier un checkout de build propre et contrôlé, idéalement un worktree dédié ; ne pas « nettoyer » le checkout actuel en restaurant/stageant les suppressions Steam.
- Vérifier la correspondance avec les archives de release/App Store Connect avant de désigner une baseline « publiée ».
- Aucun commit/push implicite par la procédure release.

## Rollback

Revenir à un tag iOS connu via une branche/worktree de reprise. Ne pas reset --hard la branche active ni écraser des évolutions légitimes. Un rollback client n’entraîne jamais automatiquement un rollback backend. Conserver les données utilisateur et vérifier leur compatibilité avec le client retenu avant installation/release ; ne pas écraser les sauvegardes pour forcer la correspondance à un ancien tag.

## NEVER DO THIS

- Ne pas travailler directement depuis un vieux tag détaché ; créer une branche/worktree de reprise.
- Ne pas force-push, reset --hard ou déplacer les tags.
- Ne pas stager les suppressions Steam.
- Ne pas utiliser git add . ni git add -A.
- Ne pas modifier iOS et Android ensemble sans besoin prouvé.
- Ne pas publier un build sans vérifier le PCK embarqué.
- Ne pas réutiliser un ancien build Xcode comme preuve du HEAD courant.
- Ne pas supposer qu’un commit Git signifie une version App Store publiée.
- Ne pas supposer que le backend actuel est celui du tag.
- Ne pas supprimer/normaliser les fichiers non suivis, imports, caches, exports ou backups pendant le freeze.

## État de clôture de cet audit

Seul ce document est ajouté. Aucun fichier fonctionnel, configuration, Xcode, migration, asset ou fichier Steam n’est modifié. Les suppressions et fichiers non suivis préexistants restent intacts ; index vide. Aucun commit, push, tag, build, export, installation ou accès aux services applicatifs n’a été exécuté. Seul le fetch Git explicitement demandé a accédé au remote.

Prochaine action : validation humaine d’une publication fast-forward contrôlée du commit Cloud Save local ; ne pas créer les tags avant confirmation de sa présence sur origin.
