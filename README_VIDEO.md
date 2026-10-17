# Téléconsultations ZEGOCLOUD

## Démarrer sur Android (développement)

Les identifiants fournis ont été enregistrés dans `sante_clair/config/zego.local.json`, ignoré par Git. Ne pas ajouter ce fichier au dépôt. L'AppSign est embarqué dans le binaire de développement et ne remplace pas une authentification serveur en production.

Dans `SanteClair` :

```sh
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver 0.0.0.0:8000
```

Dans `sante_clair` :

```sh
flutter pub get
flutter run --dart-define-from-file=config/zego.local.json --dart-define=API_BASE_URL=http://192.168.1.36:8000/api
```

Choisir un appareil Android connecté. Cette adresse doit correspondre à l'adresse actuelle du PC, et les appareils doivent pouvoir accéder à Internet et au backend. Les builds debug/profile autorisent l'API HTTP du réseau local. Un build release utilise une API HTTPS.

Lors d'un premier appel, autoriser caméra et microphone. L'application arrête les flux et libère les ressources au raccrochage. Lors du passage en arrière-plan, elle coupe la caméra et le microphone, puis restaure les choix de l'utilisateur au retour.

## Parcours patient et médecin

- Le rendez-vous doit être confirmé et son mode doit être `video`.
- À l'heure prévue, « Rejoindre » ouvre l'accès vidéo habituel. La fenêtre d'accès dure 120 minutes, réglable avec `VIDEO_CALL_WINDOW_MINUTES` dans les settings Django.
- Avant l'heure, la fiche affiche « Rejoindre urgent (10 000 FBU) » sous les coordonnées du cabinet. Le patient accepte explicitement le supplément à régler au cabinet. Aucun paiement électronique ni prélèvement n'est effectué.
- Le backend enregistre un seul supplément par rendez-vous. Rejoindre à nouveau la même téléconsultation ne crée pas une deuxième dette. Le prix du rendez-vous et son reçu initial sont conservés.
- Dans l'espace médecin ouvert, un bandeau actualisé toutes les 5 secondes affiche le patient en attente et permet de rejoindre la même salle, même pour un rendez-vous prévu un autre jour. Le planning du jour contient aussi un bouton « Rejoindre » sur les téléconsultations confirmées.
- Chaque appel maintient une présence toutes les 15 secondes. Une présence sans nouvelles disparaît après 45 secondes. Le médecin doit être disponible et rejoindre la salle pour établir la conversation.
- Dans le backoffice : **Téléconsultations → Suppléments urgents à encaisser**, sélectionner le supplément puis **Marquer les suppléments sélectionnés comme encaissés au cabinet**. La date et l'utilisateur ayant encaissé sont conservés.
- Les demandes sont visibles quand l'espace médecin est ouvert. La réception d'appels quand l'application est fermée et les notifications push ne sont pas configurées : elles nécessitent une intégration de notification et les clés des plateformes correspondantes.

## Jetons serveur : web et production

L'AppSign fourni n'est **pas** le ServerSecret. Récupérer le **ServerSecret (32 octets)** du même projet dans la console ZEGOCLOUD, puis le fournir uniquement à Django :

```sh
export ZEGO_APP_ID=2075413653
export ZEGO_SERVER_SECRET='REMPLACER_PAR_LE_SERVER_SECRET_DE_LA_CONSOLE'
export ZEGO_ALLOW_APP_SIGN=false
.venv/bin/python manage.py runserver 0.0.0.0:8000
```

Ne pas mettre le ServerSecret dans Flutter, un `--dart-define` ou un dépôt Git. Les variables doivent être exportées dans le terminal qui lance Django ; les fichiers `.env` ne sont pas lus automatiquement par ce projet.

Django émet des Token04 limités à l'utilisateur, à la salle et au flux du rendez-vous, avec une durée limitée ; Flutter renouvelle les jetons avant expiration. Dans ZEGOCLOUD, faire activer la validation des privilèges de connexion à la salle et de publication des flux, conformément à leur documentation. Cette validation est nécessaire pour faire appliquer ces restrictions par le service vidéo. L'authentification AppSign est uniquement un mode de développement natif ; Django la refuse si `DEBUG=False`.

Pour le navigateur :

```sh
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

La caméra web exige **HTTPS ou localhost**. Une page ouverte sur `http://192.168.1.36:8080` n'est pas un contexte sécurisé et ne peut pas utiliser la caméra. Pour tester depuis un autre appareil dans un navigateur, servir le frontend et l'API en HTTPS avec un certificat reconnu. Le build web utilise JavaScript ; le SDK ZEGOCLOUD actuel ne prend pas en charge un build Flutter WebAssembly. Le wrapper JavaScript ZEGOCLOUD est intégré à `web/index.html`. Sans ServerSecret, l'accès web affiche une erreur de configuration avant toute création de supplément.

## iOS

Sur macOS avec Xcode et CocoaPods :

```sh
flutter pub get
cd ios
pod install
cd ..
flutter run --dart-define-from-file=config/zego.local.json --dart-define=API_BASE_URL=https://VOTRE_API/api
```

Les descriptions caméra/microphone et les macros natives de permission sont présentes ; iOS 15 minimum. La compilation et les permissions iOS doivent être vérifiées sur un Mac et un iPhone. Aucune capacité d'enregistrement des consultations n'a été activée.

## API

Toutes ces routes exigent la session authentifiée et vérifient le patient/médecin du rendez-vous :

- `GET /api/appointments/<id>/video` : accès et horaires selon l'horloge serveur, montant urgent et état de la dette.
- `POST /api/appointments/<id>/video` : `{ "platform": "native" | "web", "urgent": true|false, "acceptUrgentFee": true|false }` ; autorisation, création/réutilisation de salle, identifiants et jeton éventuel. Les réponses contenant les jetons sont `no-store`.
- `POST /api/appointments/<id>/video/presence` : `{ "roomId": "...", "action": "heartbeat" | "leave" }`.
- `GET /api/doctor/incoming-calls` : patients de ce médecin actuellement en attente.

Ne pas tester la création d'appels urgents sur de vrais comptes sans vouloir enregistrer le supplément. Utiliser des comptes de démonstration ou la base de test.

## Validation réelle

Après les tests automatiques, utiliser deux appareils/comptes distincts (patient et médecin), le même rendez-vous confirmé, une connexion Internet et un projet ZEGOCLOUD actif. Vérifier audio dans les deux sens, vidéo, bascule caméra, permissions refusées, coupure réseau, reconnexion et raccrochage. Une compilation réussie ne prouve pas qu'un appel réel a eu lieu.

Références :
- https://www.zegocloud.com/docs/real-time-video-flutter/quick-start/implementing-video-call
- https://github.com/ZEGOCLOUD/zego_server_assistant/tree/master/token/python/token04
