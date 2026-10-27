# 🏆 Questions pour un champion

Un jeu de quiz développé avec **Flutter**, jouable dans le navigateur et sur mobile.

👉 **Jouer en ligne : https://abdouroihamane-s.github.io/jeu-question/**

## Fonctionnalités

- 5 thèmes (Culture générale, Géographie, Histoire, Sciences, Sénégal & Afrique) + un mode Mix
- 10 questions par partie, 20 secondes par question
- Score basé sur la rapidité et les séries de bonnes réponses 🔥
- Jokers : 50/50 et +10 secondes
- Animations, confettis et classement final (Apprenti → Champion)
- Meilleur score sauvegardé sur l'appareil

## Lancer le projet

```bash
flutter pub get
flutter run -d chrome
```

## Ajouter des questions

Dans `lib/main.dart`, ajoute une ligne dans la liste d'un thème :

```dart
Question('Ta question ?', 'Bonne réponse', ['Faux 1', 'Faux 2', 'Faux 3']),
```

## Publication

Le site est déployé automatiquement sur GitHub Pages à chaque `git push` sur la branche `main`
grâce au workflow `.github/workflows/deploy.yml`.

## Technologies

Flutter • Dart • shared_preferences • GitHub Actions • GitHub Pages