# XEO 租赁 · iOS app

SwiftUI 演示 app：扫码 → 登录 → 配件适配（含面部测量头围）→ 租期 → 假支付 → 订单 → 租期提醒 → 续租 / 归还 → 订单完成。
不联网，所有支付、登录、物流都是演示占位。

```bash
# 业务逻辑自检（不需要 Xcode）
cd ios/RentalKit && swift run RentalKitChecks

# 打开工程（需要 Xcode）
open ios/XEORental.xcodeproj
```

- 签名：Target → Signing & Capabilities 选你的 Team，免费个人账号即可。
- 演示工具：长按首页左上角 XEO 标志。
- 二维码 / URL Scheme：`xeorental://rent|activate|renew?…`，详见 `docs/tech/01-架构与双端契约.md`。

完整说明（结构、装机步骤、哪些还没验证）：[`docs/tech/03-iOS-app.md`](../docs/tech/03-iOS-app.md)。
