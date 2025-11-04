# Architecture de l'Application

## Vue d'ensemble

Cette application utilise un **pattern Repository avec orchestrateur central** pour gérer l'enregistrement audio, la lecture audio/vidéo et la session audio.

## Structure

```
lib/
├── main.dart                           # Point d'entrée, initialisation du MasterRepository
├── repositories/
│   ├── master_repository.dart          # 🎯 ORCHESTRATEUR CENTRAL
│   ├── audio_session_repository.dart   # Configuration audio session + interruptions
│   ├── audio_recording_repository.dart # Enregistrement keep-alive (pause/resume)
│   ├── audio_playback_repository.dart  # Lecture audio (URLs + fichiers)
│   └── video_playback_repository.dart  # Lecture vidéo (optimisée)
├── controllers/
│   └── lesson_controller.dart          # Controller UI (état + orchestration)
└── screens/
    └── test_screen.dart                # Interface utilisateur
```

## Pattern d'Architecture

### MasterRepository (Orchestrateur)

**Responsabilités** :
- Instancie et initialise tous les sous-repositories
- Orchestre les interactions entre repositories
- Expose des méthodes de haut niveau au controller
- Gère les conflits (ex: pause audio avant vidéo)

**Méthodes principales** :
```dart
await masterRepo.initialize()           // Initialise tout
await masterRepo.playAudioUrl(url)      // Joue un audio
await masterRepo.playVideo(url)         // Joue une vidéo (pause l'audio auto)
await masterRepo.startRecording()       // Démarre l'enregistrement (pause tout)
await masterRepo.stopRecording()        // Arrête et sauvegarde
```

### Sous-Repositories

#### 1. AudioSessionRepository
- Configure la session audio iOS/Android (playAndRecord)
- Gère les interruptions (appels, Siri, déconnexion casque)
- Initialisé **en premier** (requis par les autres)

#### 2. AudioRecordingRepository
- Gère l'enregistrement avec pattern **keep-alive**
- Le stream audio reste actif en permanence (pause/resume instantané)
- Conversion PCM → WAV automatique
- Retourne la liste des fichiers enregistrés

#### 3. AudioPlaybackRepository
- Gère la lecture audio (URLs réseau + fichiers locaux)
- Réutilise une seule instance d'`AudioPlayer`
- Méthodes : play, pause, resume, stop

#### 4. VideoPlaybackRepository
- Gère la lecture vidéo
- **OPTIMISÉ** : réutilise le `VideoPlayerController` pour la même URL
- Évite de recréer le controller à chaque lecture

### LessonController

**Responsabilités** (simplifiées) :
- Gère uniquement l'état UI (variables observables GetX)
- Appelle les méthodes du `MasterRepository`
- Orchestre les workflows de test
- **~200 lignes** au lieu de 513

**Injection** :
```dart
final masterRepo = Get.find<MasterRepository>();
```

## Flux d'Initialisation

```
main.dart
  ↓
1. Demander permissions microphone
2. Créer MasterRepository
3. Appeler masterRepo.initialize()
   ↓
   → AudioSessionRepository.initialize()  (1er)
   → AudioRecordingRepository.initialize() (parallèle)
   → AudioPlaybackRepository.initialize()  (parallèle)
   → VideoPlaybackRepository.initialize()  (parallèle)
4. Enregistrer dans GetX : Get.put(masterRepo)
5. Lancer l'app
   ↓
LessonController.onInit()
  → Récupère masterRepo via Get.find()
  → Prêt à utiliser
```

## Pattern Keep-Alive (Enregistrement)

Le recorder utilise un pattern **keep-alive** pour des performances optimales :

1. **Initialisation** : Stream audio démarré et immédiatement pausé
2. **En attente** : Stream actif mais pas de capture (keep-alive)
3. **Enregistrement** : Resume instantané (<5ms) + capture des chunks
4. **Arrêt** : Pause (keep-alive) + sauvegarde du fichier WAV
5. **Répétition** : Retour à l'étape 2 (aucune réinitialisation)

**Avantages** :
- Resume ultra-rapide (<5ms au lieu de 200-500ms)
- Pas de réinitialisation entre les enregistrements
- Performance maximale

**Inconvénient** :
- Stream toujours actif = consommation batterie légèrement supérieure
- Indicateur d'enregistrement iOS peut rester visible

## Orchestration Intelligente

Le `MasterRepository` gère automatiquement les conflits :

### Exemple 1 : Lancer une vidéo
```dart
await masterRepo.playVideo(url);
// → Pause automatiquement l'audio
// → Lance la vidéo
```

### Exemple 2 : Démarrer un enregistrement
```dart
await masterRepo.startRecording();
// → Pause l'audio
// → Pause la vidéo
// → Resume le recorder
```

## Bénéfices de cette Architecture

1. ✅ **Séparation des responsabilités** : Chaque repository a un rôle clair
2. ✅ **Réutilisabilité** : Les repositories peuvent être utilisés dans d'autres écrans
3. ✅ **Testabilité** : Chaque repository peut être testé indépendamment
4. ✅ **Lisibilité** : Controller réduit de 513 à ~200 lignes
5. ✅ **Performance** : Initialisation unique, pattern keep-alive préservé
6. ✅ **Orchestration centralisée** : Logique métier dans le MasterRepository
7. ✅ **Maintenance** : Plus facile de modifier un repository isolé

## Tests et Debugging

Pour debug un repository spécifique, tous les repositories ont des logs `print()` :
- ✓ : Succès
- ⚠️ : Avertissement
- ❌ : Erreur
- 🎬/🔊/🎤 : Actions en cours
- 🧹 : Disposal

## Migration depuis l'Ancienne Architecture

**Avant** (Monolithique) :
- 513 lignes dans `LessonController`
- Tout mélangé : UI + audio + vidéo + recording
- Difficile à maintenir et tester

**Après** (Repository Pattern) :
- ~200 lignes dans `LessonController` (UI seulement)
- 5 repositories spécialisés
- Orchestration centralisée
- Facile à tester et maintenir
