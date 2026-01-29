# TraintimePDA UCAS (Flutter + Dart)

[![Build and Release](https://github.com/your-username/traintime_pda_ucas/actions/workflows/build_and_release.yml/badge.svg)](https://github.com/your-username/traintime_pda_ucas/actions/workflows/build_and_release.yml)
![License](https://img.shields.io/badge/license-MPL%202.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

这是一个基于 [TraintimePDA/XDYou](https://github.com/BenderBlog/traintime_pda) 重构的**中国科学院大学 (UCAS)** 专用版本。

本项目保留了原项目优秀的 Flutter UI 设计，但**彻底重构了底层逻辑**：
*   **纯 Flutter/Dart**: 移除了原有的 Rust 混合开发架构，极大地降低了维护成本和编译复杂度。
*   **ONNX 验证码识别**: 集成 `ddddocr` 的 ONNX 模型，实现了全平台（移动端+桌面端）统一、高效的验证码自动识别。
*   **SEP/JWXK 适配**: 专为国科大教务系统定制的爬虫与抢课逻辑。

## ✨ 核心功能 (Features)

### � 自动抢课 (Course Robber)
*   **全自动流程**: 监控名额 -> 自动识别验证码 -> 提交选课。
*   **高成功率**: 内置 `ddddocr` 模型，验证码识别率极高且无需额外网络请求。
*   **多目标支持**: 支持同时监控多门课程，并通过 SIDS 智能去重。

### �📅 课程表 (Schedule)
*   **多视图支持**: 周视图直观展示每日课程。
*   **智能时间映射**: 自动将讲座、考试时间映射到标准的 1-12 节课段。
*   **自定义事件**: 支持手动添加讲座或其他事件。
*   **近期讲座**: 自动抓取学校讲座网信息，并支持一键添加到课表。

### 📊 成绩与考试 (Scores & Exams)
*   **成绩查询**: 支持按学期查看成绩，学位课自动高亮。
*   **GPA 计算**: 自动提取并计算 GPA。
*   **考试安排**: 按 "未考 > 已结束" 智能排序，支持一键导入考试到日程。

## 🛠️ 技术架构 (Architecture)

*   **UI 框架**: Flutter (Material 3)
*   **因特网**: Dio + CookieJar (持久化 Session)
*   **OCR**: ONNX Runtime (`onnxruntime` dart plugin) + `ddddocr.onnx`
*   **CI/CD**: GitHub Actions (自动构建全平台 Release)

## 🚀 快速开始 (Getting Started)

### 环境要求
*   Flutter SDK >= 3.0.0
*   **桌面端开发需额外的动态库**:
    *   **Windows**: 需下载 `onnxruntime.dll` (v1.16.3) 放入 `windows/runner/`。
    *   **Linux**: 需下载 `libonnxruntime.so` (v1.16.3) 放入 `linux/runner/`。
    *   **macOS**: 需下载 `libonnxruntime.dylib` (v1.16.3) 放入 `macos/Runner/`。
    *   *注: Android 和 iOS 不需要额外配置，插件会自动处理。*

### 获取代码
```bash
git clone https://github.com/your-username/traintime_pda_ucas.git
cd traintime_pda_ucas
```

### 运行开发版
```bash
flutter pub get
flutter run
```

### 编译 Release 版本
```bash
# Android (自动集成 ONNX)
flutter build apk --release

# Windows (需手动放置 dll)
flutter build windows --release

# Linux (需手动放置 so)
flutter build linux --release

# macOS (需手动放置 dylib)
flutter build macos --release
```

## 📄 授权信息 (License)

本项目沿用原项目的 **MPL-2.0** (Mozilla Public License 2.0) 协议。
UI 及核心架构代码版权归原作者 [BenderBlog](https://github.com/BenderBlog) 所有，UCAS 适配部分的修改归开发者所有。

## 🙏 致谢 (Credits)

*   **[BenderBlog/traintime_pda](https://github.com/BenderBlog/traintime_pda)**: 原项目，提供了非常优秀的 UI 框架和设计思路。
*   **[sml2h3/ddddocr](https://github.com/sml2h3/ddddocr)**: 优秀的通用验证码识别模型。

