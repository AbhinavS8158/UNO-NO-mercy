# 🎴 UNO Show 'em No Mercy - Real-time Multiplayer & Voice Chat

An authoritative real-time multiplayer implementation of **UNO Show ’em No Mercy** built with **Flutter** (Front-end), **Firebase Cloud Functions & Firestore** (Authoritative Server Game Engine), and **LiveKit WebRTC** (Secure In-Game Voice Chat).

### 🌐 [🎮 Live Demo: Play Online Here](https://abhinavs8158.github.io/UNO-NO-mercy/)

---

## 🚀 Key Highlights

- **Anti-Cheat Server-Authoritative Architecture**:
  - The Flutter client **never** determines the winner or edits game states directly.
  - Strict **Firestore Security Rules** (`/rooms/{roomId}/private_hands/{playerId}`): players can **only** read their own cards. Opponents' hands are completely hidden to prevent client inspection or packet-sniffing cheats.
  - All game actions (*Play, Draw, Stacking, 7/0 Hand Swap*) are validated on the server via Cloud Functions transactions.

- **Official UNO Show 'em No Mercy Ruleset**:
  - **The Mercy Rule (25 Cards Limit)**: Any player accumulating 25 or more cards is instantly **Knocked Out** of the game.
  - **Stacking Penalty Rules**: Pass penalties by stacking matching or higher draw cards (`+2`, `+4`, `+6`, `+10`).
  - **7 & 0 Rules**: Playing a `7` lets you swap your hand with another player; playing a `0` rotates everyone's hand in the current direction of play.
  - **Special Action Cards**: *Discard All of a Color*, *Skip Everyone*, *Roulette*, *Wild Draw 6*, and *Wild Draw 10*.

- **Live In-Game Voice & Text Chat**:
  - Encrypted, low-latency WebRTC voice communication powered by **LiveKit**.
  - Server-authenticated voice room tokens linked directly to room codes (e.g. `UNO7K2`).
  - In-game active speaker detection glow around avatars.
  - In-game floating drawer for real-time text chat and quick UNO taunts (`NO MERCY! 😈`, `TAKE +10! 🔥`).

---

## 🛠️ Tech Stack

- **Client**: Flutter (Dart 3.x), `flutter_animate`, `google_fonts`
- **Backend / Database**: Firebase Cloud Firestore & Cloud Functions (TypeScript)
- **Voice RTC**: LiveKit / WebRTC Server SDK
- **Security**: Granular Firestore Security Rules with atomic batch transactions

---

## 📂 Project Structure

```
.
├── firestore.rules               # Strict player card privacy & anti-cheat rules
├── firebase.json                 # Firebase local emulators & deployment setup
├── functions/                    # Server-Authoritative Game Engine (TypeScript)
│   ├── src/
│   │   ├── types.ts              # Data models for cards, rooms, and players
│   │   ├── deck.ts               # 168-card No Mercy full deck generator
│   │   ├── gameEngine.ts         # Stacking, 25-Mercy elimination & winner logic
│   │   └── index.ts              # Callable Functions & LiveKit token generation
│   └── package.json
└── lib/                          # Flutter Application
    ├── core/theme/uno_colors.dart
    ├── models/
    │   ├── uno_card.dart
    │   ├── game_room.dart
    │   └── chat_message.dart
    ├── services/
    │   ├── game_service.dart
    │   └── voice_service.dart
    └── views/
        ├── lobby/lobby_screen.dart           # Room creation, joining & player waiting list
        ├── game_board/
        │   ├── game_screen.dart              # Main table view & game manager
        │   ├── table_center_view.dart        # Realistic 3D discard & draw pile
        │   └── animated_card_overlay.dart    # Smooth card flight animation
        └── widgets/
            ├── uno_card_widget.dart          # Vector card renderer (Front & Back)
            ├── card_fan_layout.dart          # Curved horizontal player hand
            ├── voice_control_bar.dart        # Mute / Deafen voice bottom sheet
            └── chat_overlay_dialog.dart      # Real-time text chat & quick taunts
```

---

## 🧪 Testing

Run the automated Flutter unit and smoke tests:
```bash
flutter test
```
Compile TypeScript Cloud Functions:
```bash
cd functions
npm run build
```

---

## 📜 License
MIT License.
