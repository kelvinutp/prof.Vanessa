# commands
## for running from github codespace
```
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

## Windows
1. Testing flutter installation

```cmd
flutter --version
flutter config --enable-windows-desktop

```
If everything is ok, 

2. FLutter configuration

This commands ensures that all required Windows toolchains (like Visual Studio for C++ build tools) and project dependencies are fully satisfied.
Check overall environment health
```cmd
flutter doctor
flutter pub get
flutter analyze
```

Once dependencies are verified and clean, they can launch the app locally on Windows.

3. **View available target devices:**
```cmd
flutter devices

```


*(They should see `windows` listed as a desktop device).*

4. **Run the application:**
```cmd
flutter run -d windows

```