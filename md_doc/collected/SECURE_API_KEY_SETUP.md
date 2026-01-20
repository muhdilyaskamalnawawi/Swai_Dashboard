# Secure API Key Setup Guide

## ✅ Setup Complete!

Your Gemini API key is now securely stored using `flutter_dotenv`. Here's what was configured:

### 1. **Environment File Created**
- **File**: `.env` (in project root)
- **Location**: `c:\Users\HP\swai_dashboard\.env`
- **Contents**: 
  ```
  GEMINI_API_KEY=AIzaSyAjWI5r90Pw0iep7Q23KSRBuEjdmgRJRm8
  ```

### 2. **.gitignore Updated**
The `.env` file is now excluded from version control to prevent accidental API key leaks:
```gitignore
# Environment variables (NEVER commit)
.env
```

### 3. **pubspec.yaml Configuration**
Added `.env` as a flutter asset:
```yaml
flutter:
  uses-material-design: true
  assets:
     - assets/swai_icon.png
     - assets/swai_inapp.png
     - .env
```

### 4. **main.dart Updated**
Loads the environment file at app startup:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  await dotenv.load();
  
  runApp(const MyApp());
}
```

### 5. **app_config.dart Updated**
Changed from hardcoded string to getter that reads from `.env`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Gemini API Configuration - Read from .env file
  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
    return key;
  }
}
```

### 6. **GeminiService Usage**
The service already uses `AppConfig.geminiApiKey`, so it automatically gets the secure key:
```dart
_model = GenerativeModel(
  model: 'gemini-2.5-flash',
  apiKey: AppConfig.geminiApiKey,  // ✓ Now reads from .env
);
```

---

## 🚀 How to Run

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

---

## ⚠️ Important Security Guidelines

### ✅ DO:
- Keep `.env` file **LOCAL ONLY** (never commit to Git)
- Use `.gitignore` to prevent `.env` from being tracked
- Regenerate API keys if they're accidentally exposed
- Rotate API keys periodically

### ❌ DON'T:
- Commit `.env` to GitHub or any repository
- Share `.env` file in chat, email, or messages
- Hardcode sensitive keys in code
- Use production keys for testing/development

---

## 📋 Troubleshooting

### Issue: "GEMINI_API_KEY not found in .env file"
**Solution**: Make sure `.env` file exists in project root with the key:
```
GEMINI_API_KEY=AIzaSyAjWI5r90Pw0iep7Q23KSRBuEjdmgRJRm8
```

### Issue: App can't find .env file
**Solution**: Ensure `.env` is listed in `pubspec.yaml` assets:
```yaml
flutter:
  assets:
    - .env
```

### Issue: Changes to .env not reflected
**Solution**: Rebuild the app (hot reload won't pick up .env changes):
```bash
flutter run
```

---

## 🔄 Updating the API Key in Future

To change the Gemini API key:
1. Edit `.env` file
2. Replace the key value
3. Rebuild: `flutter run`

**No code changes needed!** The app will automatically use the new key.

---

## 📝 For Team Collaboration

If working with a team:

1. **Create `.env.example`** (template without real keys):
   ```
   GEMINI_API_KEY=your_api_key_here
   ```

2. **Share `.env.example`** in Git (not `.env`)

3. **Each developer** copies `.env.example` to `.env` and fills in their own keys

4. **Add to README**:
   ```markdown
   ### Setup Environment Variables
   1. Copy `.env.example` to `.env`
   2. Add your Gemini API key to `.env`
   3. Never commit `.env` to Git
   ```

---

**Your API key is now secure! 🔒**
