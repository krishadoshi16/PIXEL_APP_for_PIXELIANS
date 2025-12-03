# 🎨 Pixel Art Maker – Social Pixel Drawing App

Pixel Art Maker is a creative mobile app built with Flutter and Supabase. Users can draw pixel art, save their artwork, share it publicly, explore other artists’ work, and interact socially. The idea is simple — a fun drawing app mixed with a community experience.

---

## 🚀 What the app offers

### 🎨 Pixel Drawing Studio
- Interactive pixel editor
- Brush and eraser tools
- Zoom in / zoom out
- Undo / redo
- Mirror mode for symmetry
- Convert a photo into a pixel grid
- Export drawings as PNG or PDF (step-by-step color guide)

### 👤 Profiles & Login
- Email and password login
- Google login (with account selection popup)
- Profile screen where you can:
  - Change your name
  - Set a profile picture
  - View your drawings
  - View your favorite drawings

### 🌍 Explore / Public Feed
- Browse pixel art posted by other creators
- See the name of the artist and the artwork title
- Tap any post to open a detailed view

### ❤️ Social Features
| Feature | What it does |
|--------|--------------|
| Likes | Like / unlike public drawings |
| Comments | Add comments, and also edit or delete only your own comments |
| Favorites | Save drawings privately in your favorites list |
| Notifications | Artists receive alerts when someone likes or comments on their public posts |

---

## 🗄 Database Overview

The project uses Supabase with the following tables:

| Table | Purpose |
|-------|---------|
| `users` | Stores user information (name, avatar, email ID link) |
| `drawings` | Stores pixel art images and their visibility (public/private) |
| `favorites` | Stores drawings saved by users |
| `comments` | Stores comments on drawings |
| `notifications` | Alerts artists about likes and comments |

---

## 🧠 Tech Stack
- Flutter (Dart)
- Supabase Auth
- Supabase Database
- Supabase Storage
- Share Plus (for sharing images)

---

## 📂 Folder Structure (simplified)

lib/
│ main.dart
│ login_screen.dart
│ signup_screen.dart
│ forgot_password_screen.dart
│ pixel_screen.dart
│ gallery_screen.dart
│ draw_screen.dart
│ explore_screen.dart
│ post_detail_screen.dart
│ comments_screen.dart
│ favorites_screen.dart
│ profile_screen.dart
└ widgets/


---

## 💡 How to run the project (for developers)

git clone https://github.com/
<username>/pixel_art_app.git
cd pixel_art_app
flutter pub get
flutter run

(Add your own Supabase URL and anon key inside `main.dart` before running.)

---

## 📱 App distribution
The app is being built for Android. An APK can be generated using:
flutter build apk --release

The APK can then be installed and shared with users.

---

## 👩‍💻 Creator
Developed with ❤️ by **Krisha Doshi**

If you like the project, starring the repository is appreciated 🙂
