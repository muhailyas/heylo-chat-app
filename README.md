# Heylo 💬

> **Heylo** is a modern, real-time messaging and calling application built with Flutter, designed to provide a seamless and premium communication experience.

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-%2342A5F5.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://riverpod.dev)

---

## 📸 Screenshots

| Home Screen | Chat Interface | Calling |
|:---:|:---:|:---:|
| <img src="assets/screenshots/home.png" alt="Home" width="250"/> | <img src="assets/screenshots/chat.png" alt="Chat" width="250"/> | <img src="assets/screenshots/call.png" alt="Call" width="250"/> |
> *Note: Add screenshots to an `assets/screenshots` folder to display them here.*

---

## ✨ Key Features

*   **⚡ Real-time Messaging**
    *   Instant 1-on-1 and Group chats.
    *   Powered by Supabase Realtime.
*   **📞 Audio & Video Calls**
    *   High-quality voice and video calls.
    *   Seamless integration with Zego Cloud.
*   **📂 Rich Media Sharing**
    *   Send **Images, Videos, and Files**.
    *   Share **Voice Notes** with playback controls.
    *   Dedicated **Media, Links & Docs** gallery.
*   **🎨 Smart UI/UX**
    *   Modern, clean design with smooth animations.
    *   Message **Reactions** and **Replies**.
    *   **Typing Indicators** and **Read Receipts** (Sent, Delivered, Seen).
*   **👥 Contact Management**
    *   Syncs with device contacts.
    *   Block/Unblock functionality.

---

## 🛠️ Tech Stack

| Component | Technology |
|:---:|:---|
| **Frontend** | Flutter (Dart) |
| **State Management** | Riverpod |
| **Backend** | Supabase (PostgreSQL, Realtime, Auth) |
| **Calling SDK** | Zego Cloud UIKit |
| **Storage** | Supabase Storage |
| **Local Storage** | Shared Preferences / Flutter Secure Storage |

---

## 🚀 Getting Started

Follow these steps to set up the project locally.

### Prerequisites
*   **Flutter SDK**: = 3.38.1
*   **Dart SDK**: = 3.10.0
*   Supabase Account

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/yourusername/heylo.git
    cd heylo
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Setup**
    Create a `.env` file in the root directory and add your credentials:
    ```env
    SUPABASE_URL=your_supabase_url
    SUPABASE_ANON_KEY=your_supabase_anon_key
    # Add other necessary keys
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

---

## 🤝 Contributing

Contributions are currently **closed** for this project as it is a personal review project. However, feel free to fork and experiment!

---

<p align="center">
  Built with ❤️ using Flutter
</p>
