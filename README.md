# big-rom-rental · BIG + Rom 租赁体验 Demo

用一台 iPhone 和一台墨水屏 Rom，演示「影院扫码租 → 开箱激活 → 到期续租或归还 → 订单完成」的完整租赁体验。
没有后端、没有真实支付——流程走得通、看得懂、好看。

| 目录 | 是什么 |
|---|---|
| [`ios/`](ios/) | iOS app（SwiftUI）：租与还的全流程 |
| [`eink/`](eink/) | 墨水屏演示（单文件 HTML）：Rom 首次激活、到期 / 逾期提醒；另有打印用入口二维码 |
| [`docs/prd/`](docs/prd/) | 需求：做什么、做到什么算完 |
| [`docs/tech/`](docs/tech/) | 实现：架构、**两端二维码契约**、各端说明 |
| [`docs/验收清单.md`](docs/验收清单.md) | 做到哪、验到哪 |
| [`brand/`](brand/) | XEO 标识（直接使用，勿重绘） |

## 快速开始

**墨水屏端**
```bash
node eink/build.mjs
adb push eink/dist/XEO-Rom-激活演示.html /sdcard/Download/
```
在墨水屏安卓机的浏览器里打开该文件。入口二维码：浏览器打开 `eink/dist/租赁入口二维码.html` 打印。

**iOS 端**：需要完整 Xcode（App Store 安装）。打开 `ios/XEORental.xcodeproj`，Signing 里选你的个人团队，连上 iPhone 运行。
详见 [`docs/tech/03-iOS-app.md`](docs/tech/03-iOS-app.md)。

## 演示脚本（约 5 分钟）

1. iPhone 相机扫打印的入口二维码 → 打开「XEO 租赁」→ 登录 → 配件适配 → 选租期 → 支付；
2. 墨水屏打开激活演示 → 走到「扫码激活」→ 用 app 的「扫一扫」扫墨水屏二维码 → 继续到「开始观影」；
3. app 演示工具「快进到剩 20 小时」→ 手机收到提醒；墨水屏演示面板弹「租期即将到期」→ 去续租 → app 扫码 → 续租；
4. 或选择归还 → 演示按钮推进 → 订单完成。

## 品牌

视觉遵循《XEO 品牌视觉识别规范》：XEO Purple `#6638B6`、白底黑字、大量留白；标识用 `brand/` 原件。
