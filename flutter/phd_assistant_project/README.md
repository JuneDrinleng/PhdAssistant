# phd_assistant_project

A new Flutter project.

## 开启调试

win 和 chrome 都是直接 flutter run 后选择就行
对于 Android 而言，首先需要 flutter emulators 查看有没有模拟器

```
E:\GitHubStorage\WordHandbook\flutter\phd_assistant_project>flutter emulators
1 available emulator:

Id                                       • Name                                     • Manufacturer • Platform

Pixel_3a_API_34_extension_level_7_x86_64 • Pixel_3a_API_34_extension_level_7_x86_64 • Google       • android
```

对于这种情况就可以直接（需要把 emulator 和 platform-tools 添加到环境变量）：

```
emulator -avd Pixel_3a_API_34_extension_level_7_x86_64 -wipe-data -no-snapshot
```

来启动模拟器，-wipe-data 是每次都清除数据，-no-snapshot 是不使用快照启动,然后再：

```
flutter devices --device-timeout 60
```

查看模拟器的 id：

```
E:\GitHubStorage\WordHandbook\flutter\phd_assistant_project>flutter devices --device-timeout 60
Found 4 connected devices:
  sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64    • Android 14 (API 34) (emulator)
  Windows (desktop)            • windows       • windows-x64    • Microsoft Windows [版本 10.0.26100.6899]
  Chrome (web)                 • chrome        • web-javascript • Google Chrome 141.0.7390.108
  Edge (web)                   • edge          • web-javascript • Microsoft Edge 141.0.3537.85
```

最后根据 id：

```
flutter run -d emulator-5554 --device-timeout 60
```
