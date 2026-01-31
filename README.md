# 🚂 TrainTime PDA UCAS

<div align="center">

[![Build and Release](https://github.com/wirsbf/traintime_pda_ucas/actions/workflows/build_and_release.yml/badge.svg)](https://github.com/wirsbf/traintime_pda_ucas/actions/workflows/build_and_release.yml)
![License](https://img.shields.io/badge/license-MPL%202.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10.4-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-%3E%3D3.10.4-0175C2?logo=dart)

**中国科学院大学 (UCAS) 教务管理系统客户端**

*基于 [TraintimePDA](https://github.com/BenderBlog/traintime_pda) 架构重构，专为国科大优化*

[📥 下载最新版本](../../releases/latest) • [📖 使用文档](#-使用指南) • [🔧 开发指南](#-开发指南) • [🐛 反馈问题](../../issues)

</div>

---

## ✨ 核心特性

### 🎯 自动抢课系统
- **🤖 全自动流程**: 监控课程名额 → 验证码识别 → 自动提交选课
- **🎨 OCR识别**: 内置 `ddddocr` ONNX模型，验证码识别率 >95%，无需网络请求
- **🎯 多目标支持**: 同时监控多门课程，智能队列管理
- **🔄 智能重试**: 自动处理session过期、网络异常等情况
- **📊 实时日志**: 详细记录每次抢课过程，便于调试优化

### 📅 智能课程表
- **📱 多视图展示**: 周视图直观呈现每日课程安排
- **🕐 智能映射**: 自动将讲座、考试时间映射到标准课节（1-12节）
- **➕ 自定义事件**: 支持手动添加讲座、会议等个人事项
- **🎓 近期讲座**: 自动抓取学校讲座网最新信息
- **📌 一键导入**: 快速将讲座、考试添加到课表

### 📊 成绩与考试管理
- **🎯 成绩查询**: 支持按学期查看，学位课自动高亮显示
- **📈 GPA计算**: 自动提取并计算加权平均学分绩
- **📝 考试安排**: "未来 > 已结束 > 待定" 智能排序
- **⏰ 考试提醒**: 支持一键导出到系统日历
- **🔍 详细信息**: 课程属性、考试方式等完整展示

### � 统一认证系统
- **🔑 一次登录**: 启动时统一认证，自动预取所有服务session
- **💾 Session缓存**: 智能缓存管理，减少重复登录
- **🔄 自动重试**: Session过期自动重新认证，用户无感知
- **🛡️ 安全加密**: 本地密码AES加密存储

## 🏗️ 技术架构

### 核心技术栈
```
Frontend:  Flutter (Material 3)
Language:  Dart (>=3.10.4)
Network:   Dio + CookieJar (Session持久化)
OCR:       ONNX Runtime + ddddocr.onnx
State:     Provider (状态管理)
Storage:   SharedPreferences (轻量存储)
CI/CD:     GitHub Actions (多平台自动构建)
```

### 架构设计
```
lib/
├── data/                    # 数据层
│   ├── ucas_client.dart    # 统一客户端 (Singleton + Session)
│   ├── auth/               # 认证服务 (SEP, JWXK, XKGO)
│   ├── services/           # 业务服务 (课表、成绩、讲座等)
│   ├── cache_manager.dart  # 缓存管理
│   └── captcha_ocr.dart    # ONNX验证码识别
├── ui/                      # UI层
│   ├── dashboard_page.dart # 首页 (实时优先，缓存fallback)
│   ├── schedule_page.dart  # 课程表
│   ├── score_page.dart     # 成绩
│   └── auto_select_page.dart # 自动抢课
└── logic/                   # 业务逻辑层
    └── course_robber.dart  # 抢课核心逻辑
```

### 关键设计模式
- **Singleton Pattern**: `UcasClient.instance` 全局统一实例
- **Service Layer**: 业务逻辑与网络请求分离
- **Repository Pattern**: 缓存管理统一封装
- **Provider Pattern**: 响应式状态管理

## 🚀 快速开始

### 📥 直接下载使用

前往 [Releases](../../releases/latest) 页面下载对应平台的安装包：

| 平台 | 下载文件 | 说明 |
|------|---------|------|
| Windows | `traintime_pda_ucas_windows_vX.X.X.zip` | 解压后运行 `traintime_pda_ucas.exe` |
| Linux | `traintime_pda_ucas_linux_vX.X.X.tar.gz` | 解压后运行 `traintime_pda_ucas` |
| macOS | `traintime_pda_ucas_macos_vX.X.X.zip` | 解压后运行 `.app` 文件 |
| Android | `app-release.apk` | 安装APK文件 |
| iOS | `traintime_pda_ucas_ios_vX.X.X.ipa` | 需企业签名或越狱安装 |

### 💻 从源码构建

#### 环境要求
- Flutter SDK >= 3.10.4
- Dart SDK >= 3.10.4
- 对应平台的开发工具链

#### 克隆仓库
```bash
git clone https://github.com/wirsbf/traintime_pda_ucas.git
cd traintime_pda_ucas
```

#### 安装依赖
```bash
flutter pub get
```

#### 下载 ONNX Runtime（桌面端必需）

<details>
<summary><b>Windows</b></summary>

```powershell
# PowerShell
Invoke-WebRequest -Uri "https://github.com/microsoft/onnxruntime/releases/download/v1.16.3/onnxruntime-win-x64-1.16.3.zip" -OutFile "onnxruntime.zip"
Expand-Archive onnxruntime.zip -DestinationPath .
New-Item -ItemType Directory -Force -Path windows/runner
Copy-Item onnxruntime-win-x64-1.16.3\lib\onnxruntime.dll -Destination windows/runner/
```
</details>

<details>
<summary><b>Linux</b></summary>

```bash
curl -L -o onnxruntime.tgz "https://github.com/microsoft/onnxruntime/releases/download/v1.16.3/onnxruntime-linux-x64-1.16.3.tgz"
tar -xzf onnxruntime.tgz
mkdir -p linux/runner
cp onnxruntime-linux-x64-1.16.3/lib/libonnxruntime.so.1.16.3 linux/runner/libonnxruntime.so
```
</details>

<details>
<summary><b>macOS</b></summary>

```bash
curl -L -o onnxruntime.tgz "https://github.com/microsoft/onnxruntime/releases/download/v1.16.3/onnxruntime-osx-universal2-1.16.3.tgz"
tar -xzf onnxruntime.tgz
cp onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.1.16.3.dylib macos/Runner/libonnxruntime.dylib
```
</details>

> **注意**: Android/iOS 不需要手动配置，`onnxruntime` 插件会自动处理。

#### 运行开发版
```bash
flutter run
```

#### 编译 Release 版本
```bash
# Android
flutter build apk --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release

# iOS
flutter build ios --release --no-codesign
```

## � 使用指南

### 首次登录
1. 启动应用后进入登录页面
2. 输入统一认证账号和密码
3. 系统自动预取所有服务session（SEP、JWXK、XKGO）
4. 登录成功后进入Dashboard主页

### 自动抢课
1. 进入 "自动选课" 页面
2. 点击 "搜索课程" 输入课程名称或代码
3. 从搜索结果中添加目标课程
4. 点击 "开始抢课" 启动监控
5. 系统自动处理验证码并提交选课

### 课程表管理
- **查看课表**: 主页显示本周课程
- **添加讲座**: 点击 "近期讲座" 选择感兴趣的讲座添加到课表
- **自定义事件**: 长按课表空白区域添加个人事项

### 成绩查询
- 点击 "成绩" 页面查看各学期成绩
- 学位课程自动高亮显示
- GPA自动计算并展示

## 🔧 开发指南

### 项目结构
```
traintime_pda_ucas/
├── lib/
│   ├── data/           # 数据层 (网络、缓存、模型)
│   ├── ui/             # UI层 (页面、组件)
│   ├── logic/          # 业务逻辑层
│   └── main.dart       # 应用入口
├── assets/             # 静态资源 (ONNX模型)
├── test/               # 单元测试
├── .github/workflows/  # CI/CD配置
└── pubspec.yaml        # 依赖配置
```

### 核心组件说明

#### UcasClient（统一客户端）
```dart
// Singleton实例
final client = UcasClient.instance;

// 一次性初始化（App启动时）
await client.initialize(username, password);

// 后续所有fetch都不需要传credentials
final schedule = await client.fetchSchedule();
final scores = await client.fetchScores();
```

#### 缓存策略
```dart
// 优先获取实时数据，失败时自动fallback到缓存
try {
  final data = await UcasClient.instance.fetchData();
  await CacheManager().saveData(data);
} catch (e) {
  final cachedData = await CacheManager().getData();
  // 使用缓存数据
}
```

### 添加新功能
1. **新增数据服务**: 在 `lib/data/services/` 创建新服务类
2. **注入到UcasClient**: 在 `ucas_client.dart` 中注册服务
3. **添加UI页面**: 在 `lib/ui/` 创建对应页面
4. **路由配置**: 在 `main.dart` 中添加路由

### 代码规范
- **命名**: 遵循Dart官方命名规范
  - 类名: `PascalCase`
  - 变量/函数: `camelCase`
  - 常量: `lowerCamelCase` 或 `UPPER_SNAKE_CASE`
- **注释**: 关键逻辑添加中英文注释
- **格式化**: 使用 `dart format` 格式化代码
- **分析**: 运行 `dart analyze` 消除警告

### 常用命令
```bash
# 安装依赖
flutter pub get

# 代码格式化
dart format .

# 静态分析
dart analyze

# 运行测试
flutter test

# 清理构建缓存
flutter clean
```

## 🤖 CI/CD 自动化

### 自动构建触发
- **Push触发**: 每次push到 `main`/`master` 分支自动触发
- **版本管理**: 自动递增patch版本号（如 v1.0.0 → v1.0.1）
- **手动触发**: 支持从Actions页面手动触发，可选major/minor/patch递增

### 构建产物
每次构建自动生成5个平台的release包：
- Android APK
- Windows ZIP
- Linux TAR.GZ
- macOS ZIP
- iOS IPA

### Release流程
1. 获取最新git tag
2. 自动递增版本号
3. 更新 `pubspec.yaml`
4. 并行构建所有平台
5. 创建GitHub Release
6. 上传所有构建产物

### 手动触发构建
1. 进入仓库的 "Actions" 标签页
2. 选择 "Build and Release" workflow
3. 点击 "Run workflow"
4. 选择版本递增类型（patch/minor/major）
5. 确认并运行

## 📋 常见问题

<details>
<summary><b>Q: 验证码识别失败率高怎么办？</b></summary>

A: 
1. 确保 `assets/ddddocr.onnx` 模型文件完整
2. 检查ONNX Runtime库是否正确安装
3. 尝试更新到最新版本
4. 验证码识别失败3次后会弹出手动输入框
</details>

<details>
<summary><b>Q: Windows版本提示缺少DLL？</b></summary>

A:
1. 确认 `onnxruntime.dll` 在可执行文件同目录下
2. 或从Release页面重新下载完整压缩包
3. 安装 Visual C++ Redistributable
</details>

<details>
<summary><b>Q: 登录后无法获取数据？</b></summary>

A:
1. 检查网络连接
2. 确认UCAS账号密码正确
3. 尝试退出重新登录
4. 查看终端日志定位具体问题
</details>

<details>
<summary><b>Q: 自动抢课不工作？</b></summary>

A:
1. 确认已添加目标课程
2. 检查是否在选课时间段内
3. 查看抢课日志确认错误信息
4. 验证账号是否有选课权限
</details>

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 提交Issue
- 明确描述问题或建议
- 提供复现步骤（如果是bug）
- 附上系统信息和日志（如有）

### 提交PR
1. Fork本仓库
2. 创建feature分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📄 开源协议

本项目采用 **Mozilla Public License 2.0 (MPL-2.0)** 协议。

- ✅ 允许商业使用
- ✅ 允许修改和分发
- ⚠️ 修改的文件必须声明变更
- ⚠️ 使用相同协议开源修改部分

详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

### 核心依赖
- **[BenderBlog/traintime_pda](https://github.com/BenderBlog/traintime_pda)** - 原项目，提供优秀的UI架构
- **[sml2h3/ddddocr](https://github.com/sml2h3/ddddocr)** - 通用验证码识别模型
- **[Flutter](https://flutter.dev)** - 跨平台UI框架
- **[ONNX Runtime](https://onnxruntime.ai/)** - 高性能ML推理引擎

### 社区资源
- **[UCAS-Course-Reviews](https://github.com/2654400439/UCAS-Course-Reviews)** - 课程评价分享平台
- **国科大同学们的反馈与建议**

## 📧 联系方式

- **Issue Tracker**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐Star 支持一下！**

Made with ❤️ for UCAS students

</div>
