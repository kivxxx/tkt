# TKT — 台科大校園助手

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](#支援平台)
[![Version](https://img.shields.io/badge/Version-1.2.1-green)](#)
[![License](https://img.shields.io/badge/License-見%20LICENSE-orange)](LICENSE)

TKT 是一款專為 **國立台灣科技大學（NTUST）** 學生打造的校園助手 App，整合了課表查詢、成績查詢、校園公告、停車場即時資訊、行事曆等多項校園服務，讓你一站掌握所有校園資訊。

---

## 目錄

- [功能介紹](#功能介紹)
- [支援平台](#支援平台)
- [技術架構](#技術架構)
- [開始使用](#開始使用)
  - [環境需求](#環境需求)
  - [安裝依賴](#安裝依賴)
  - [執行專案](#執行專案)
  - [建置正式版本](#建置正式版本)
- [使用說明](#使用說明)
- [專案結構](#專案結構)
- [隱私政策](#隱私政策)
- [授權](#授權)

---

## 功能介紹

| 功能 | 說明 |
|------|------|
| 🏠 **Dashboard（首頁）** | 一覽用戶資訊、快速功能入口，以及公告與課表的預覽卡片 |
| 📅 **課表查詢** | 依星期分頁顯示課程時間表，支援網格 / 列表切換及課程匯入 |
| 📢 **校園公告** | 即時抓取台科大官網公告，支援無限下捲（Infinite Scroll）分頁載入 |
| 🗺️ **校園地圖** | 可縮放的互動式校園平面圖（支援雙指縮放） |
| 📆 **行事曆** | 學期行事曆檢視，支援匯入 / 解析 ICS 格式學術行事曆 |
| 🖥️ **學務資訊系統** | 內嵌 WebView 連結至台科大學生資訊系統入口 |
| 🏆 **成績查詢** | 顯示各科成績、GPA 及排名，並提供本地快取 |
| 🅿️ **停車場即時狀態** | 顯示宿舍、圖書館、帆船大樓、研揚大樓等 4 處停車場的即時剩餘車位 |
| 🔔 **課程提醒通知** | 設定課程提前提醒的本地推播通知 |
| ⚙️ **設定** | 深色模式切換、通知偏好、帳號管理等個人化設定 |
| 👤 **帳號管理** | 儲存並管理 NTUST SSO 登入憑證 |

---

## 支援平台

| 平台 | 狀態 |
|------|------|
| Android（最低 API 21 / Android 5.0） | ✅ 支援 |
| iOS | ✅ 支援 |
| Web | ✅ 已設定 |
| Windows | ✅ 已設定 |
| macOS | ✅ 已設定 |
| Linux | ✅ 已設定 |

> 主要開發與測試目標為 **Android** 及 **iOS**。

---

## 技術架構

| 類別 | 套件 / 技術 |
|------|-------------|
| 框架 | [Flutter](https://flutter.dev) 3.x / Dart |
| 狀態管理 | [Provider](https://pub.dev/packages/provider) |
| 網路請求 | [http](https://pub.dev/packages/http)、[Dio](https://pub.dev/packages/dio) + [dio_cookie_manager](https://pub.dev/packages/dio_cookie_manager) |
| 本地儲存 | [shared_preferences](https://pub.dev/packages/shared_preferences)、[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) |
| WebView | [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview) |
| 本地通知 | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| 行事曆 | [table_calendar](https://pub.dev/packages/table_calendar)、[icalendar_parser](https://pub.dev/packages/icalendar_parser) |
| 字體 | [google_fonts](https://pub.dev/packages/google_fonts) |
| 國際化 | [intl](https://pub.dev/packages/intl) |
| JWT 解碼 | [jwt_decoder](https://pub.dev/packages/jwt_decoder) |

---

## 開始使用

### 環境需求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.0.0 <4.0.0`
- Dart SDK（隨 Flutter 附帶）
- Android：Java 17、Android Studio（建議）、Android SDK（minSdkVersion 21）
- iOS：Xcode 14+、CocoaPods（macOS only）

### 安裝依賴

```bash
flutter pub get
```

### 執行專案

```bash
# Android / iOS（連接裝置或開啟模擬器後執行）
flutter run

# 指定裝置
flutter run -d <device_id>

# Web
flutter run -d chrome
```

### 建置正式版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle（上架 Play Store 用）
flutter build appbundle --release

# iOS（macOS only）
flutter build ios --release

# Web
flutter build web --release
```

#### 產生 App 圖示（可選）

```bash
flutter pub run flutter_launcher_icons
```

---

## 使用說明

1. **登入**：使用你的 NTUST 學號與密碼進行 SSO 登入。登入後憑證會安全地儲存在裝置上，之後自動登入。
2. **首頁（Dashboard）**：提供公告、課表預覽與常用功能快捷入口。
3. **課表**：點選頂部分頁標籤切換星期，點擊課程查看詳細資訊。
4. **公告**：向下滑動以載入更多公告，點擊進入公告詳細內容。
5. **停車場**：首頁或工具頁點選「停車場」即可查看各場即時剩餘車位。
6. **行事曆**：可從官方來源下載 ICS 學術行事曆並匯入 App。
7. **通知設定**：在設定頁啟用課程提醒，選擇提前通知的時間（如上課前 10 分鐘）。

> **注意：** 部分功能（成績、課表、學務系統）需要有效的 NTUST 帳號，並於校內網路或 VPN 環境下使用可能效果較佳。

---

## 專案結構

```
lib/
├── main.dart            # App 進入點，Provider 初始化
├── config/              # 常數、路由設定
├── connector/           # NTUST API 連線層
├── models/              # 資料模型（課程、公告、成績等）
├── pages/               # 頁面（WebView、帳號設定等）
├── providers/           # Provider 狀態管理
├── screens/             # 主要畫面（Dashboard、課表、公告等）
├── services/            # 業務邏輯服務（認證、通知、停車等）
├── tasks/               # 背景排程任務
├── utils/               # 工具函式
└── widgets/             # 共用 UI 元件
assets/
├── images/              # 圖片資源（Logo、校園地圖等）
```

---

## 隱私政策

請參閱 [PRIVACY_POLICY.md](PRIVACY_POLICY.md) 瞭解本 App 的隱私政策。

---

## 授權

本專案採用 [LICENSE](LICENSE) 所列之授權條款。

