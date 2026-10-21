# 03 · iOS app（`ios/`）

> **一句话**：SwiftUI app「XEO 租赁」，走完「扫码 → 登录 → 配件适配 → 租期 → 假支付 → 订单 → 提醒 → 续租 / 归还 → 订单完成」。
> 业务规则全部在纯 Swift 包 **RentalKit** 里（可在没有 Xcode 的 Mac 上自检），界面层只负责展示与导航。
> 双端契约（二维码、状态机、演示数据）以 [01-架构与双端契约](01-架构与双端契约.md) 为准。

---

## 1. 结构

```
ios/
  project.yml                 # XcodeGen 配置（改了文件增删后 `cd ios && xcodegen` 重新生成）
  XEORental.xcodeproj         # 已生成并入库：只装 Xcode 就能打开
  RentalKit/                  # 纯逻辑 Swift 包（无 UI、无网络）
    Sources/RentalKit/
      Clock.swift             # DemoClock：演示工具快进时间用的「应用内时间」
      Catalog.swift           # 租期 1/3/7 天 · 示意价 · 演示 ID · 3 家示意影院 · 取件时段
      Fitting.swift           # 面罩/绑带/镜片/耳机 · 近视度数防呆 · 头围估算 HeadEstimator
      Order.swift             # 订单状态机 · 派生状态（即将到期 / 已逾期）· 归还阶段
      QRRoute.swift           # xeorental:// 二维码解析与生成
      RentalStore.swift       # 账号、订单、持久化（JSON）、二维码处理、演示时间跳转
    Sources/RentalKitChecks/  # 自检程序：swift run RentalKitChecks
  XEORental/
    App/        XEORentalApp（入口、onOpenURL）· AppModel（导航、弹窗、支付确认）
    UI/         Theme（品牌色、按钮、卡片）· Components（Logo、状态标签、时间线…）
    Screens/    首页 · 登录 · 配件适配 · 头围测量 · 租期/确认/待支付 · 订单 · 续租/归还 · 扫一扫 · 演示工具
    Services/   NotificationService（本地租期提醒：续租 / 稍后提醒）
    Assets.xcassets           # Logo（brand/logo_black.svg 原样矢量）· AppIcon · AccentColor
```

- **Bundle ID** `ink.xeo.rental` · **显示名**「XEO 租赁」· **URL Scheme** `xeorental` · iOS 17+ · 仅竖屏 iPhone。
- **没有付费账号专属能力**：「通过 Apple 登录」是外观相同的占位按钮（不调 Sign in with Apple、不需要 entitlement），
  推送全部是本地通知 ⇒ **免费的个人开发者团队就能签名装机**。
- 数据存在 App 的 Application Support 里一个 JSON 文件；删 App 或演示工具「清空全部数据」即重置。

## 2. 关键规则（实现位置 → RentalKit）

| 规则 | 值 / 行为 |
|---|---|
| 待支付窗口 | **10 分钟**，超时订单关闭（`Order.paymentWindow`） |
| 租期起算 | 支付成功即开始（柜机取货不在 Demo 范围） |
| 即将到期 | 剩余 ≤ 3 天（`Order.expiringThreshold`）；**3 天租期支付后立刻就是「即将到期」**，这是阈值决定的 |
| 已逾期 | 过了到期时间；续租从**原到期时间**起顺延（逾期部分被覆盖） |
| 归还推进 | 上门取件：已预约 → 运输中 → 核验中 → 完成；柜机：待交还 → 待核验 → 完成。**演示按钮手动推进** |
| 近视度数 | 只收 0–1200 的整数；负数、小数、非数字都有专门提示；输入框实时过滤成纯数字。界面写明**不支持散光** |
| 登录 | 手机号 11 位、以 1 开头；验证码任意 6 位数字。都不发真实请求 |
| 头围 | ARKit 面部追踪取面部网格宽度 → 中位数 → 椭圆周长模型估算；±1 cm 微调；不支持原深感时改手填 |

### 头围估算（⚠️ 待真机校准）

`HeadEstimator`：头宽 ≈ 面部网格宽 × 1.10；头长 = 头宽 ÷ 0.79（头型指数）；
头围 = 椭圆周长（Ramanujan 公式）+ 1.5 cm，夹在 48–66 cm，采满 30 帧取中位数。
这些系数是人体测量学平均值，**必须拿软尺对几个人实测后回来调 `Fitting.swift` 顶部常量**。
采样只取「大致正脸」的帧（面部前向轴偏差 < 0.35，故意放宽，真机上再收紧）。

## 3. 打开、签名、装到 iPhone

前提：从 App Store 装 **Xcode**，然后 `sudo xcode-select -s /Applications/Xcode.app`。

1. 双击 `ios/XEORental.xcodeproj`。首次打开会解析本地包 RentalKit（几秒）。
2. 左侧选工程 → Target **XEORental** → **Signing & Capabilities** → Team 选你的 Apple ID（Xcode → Settings → Accounts 先登录）。
   免费账号若提示 Bundle ID 被占用，把 `ink.xeo.rental` 改成 `ink.xeo.rental.<你的名字>`。
3. iPhone 用线连 Mac，手机上打开 **设置 › 隐私与安全性 › 开发者模式**，重启手机。
4. 顶部设备选你的 iPhone，⌘R 运行。首次运行要在手机 **设置 › 通用 › VPN 与设备管理** 里信任开发者证书。
5. 免费账号签的包 **7 天后过期**，届时重新 ⌘R 一次即可。

## 4. 演示怎么走

- **入口二维码**：打印 `xeorental://rent?cabinet=XEO-IMAX-DEMO-01` 的二维码（墨水屏演示 `eink/` 里有可打印页）。
  iPhone 系统相机扫码 → 提示「在 XEO 租赁中打开」→ 进入流程。没有打印？在 iPhone **Safari 地址栏**输入同样的 URL 也能拉起。
- **Rom 激活 / 续租**：墨水屏上显示 `xeorental://activate?device=ROM-DEMO-0001` / `xeorental://renew?device=ROM-DEMO-0001`，
  用 app 首页「扫一扫」扫。扫一扫页底部可粘贴链接（模拟器没有相机时用）。
- **演示工具**：**长按首页左上角 XEO 标志**进入。
  - 时间快进：租期剩 2 天 / 已逾期 5 小时 / 待支付剩 30 秒 / 恢复真实时间（只改应用内时间，不动系统时间）
  - 3 秒后发送租期提醒通知（锁屏可见，带「续租 / 稍后提醒」；稍后提醒演示为 1 分钟后再响）
  - 直接模拟三种二维码
  - 清空全部数据

## 5. 验证状态（2026-10-21）

| 项 | 状态 |
|---|---|
| RentalKit 业务规则 | ✅ `swift run RentalKitChecks`：**78 项全过**（本机 Command Line Tools，无 Xcode） |
| 界面代码类型检查 | 🟡 全部 14 个界面源文件在 **macOS 版 SwiftUI** 下编译通过（临时 harness，未入库）；`#if os(iOS)` 分支只做了语法解析 |
| 工程文件 | 🟡 XcodeGen 生成，`plutil -lint` 通过 |
| **iOS 真编译 / 真机运行** | ⬜ **未验证**——等装好 Xcode |

**装好 Xcode 之前没有验证过的**（第一次编译时重点看）：

- `#if os(iOS)` 里的代码：ARKit 面部追踪预览（`HeadMeasureView.swift`）、AVFoundation 扫码（`ScannerScreen.swift`）、
  `keyboardType` / `textContentType` / `navigationBarTitleDisplayMode` / `toolbar(.hidden, for: .navigationBar)`。
- 资源编译：SVG 矢量 Logo、AppIcon（1024 单尺寸）、AccentColor。
- 运行期行为：通知授权与锁屏动作按钮、`onOpenURL` 冷启动拉起、相机权限弹窗、头围估算的实际数值。
