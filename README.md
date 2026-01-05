# UCAS 课程表（纯 Flutter + Dart 爬取）

这是从原工程中抽离出的最小可用版本，UI 使用 Flutter，课程拉取逻辑使用 Dart 实现，不依赖 Rust。

## 运行

```bash
cd traintime_pda_ucas
flutter pub get
flutter run
```

## 说明

- 点击右上角“拉取”按钮，输入 UCAS 账号/邮箱和密码即可获取课表。
- 若 SEP 触发验证码，会提示先在网页端完成一次登录。
