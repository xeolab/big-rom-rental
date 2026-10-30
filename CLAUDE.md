# CLAUDE.md —— big-rom-rental（BIG + Rom 租赁体验 Demo）

@../xeo-pm/MONO.md

> 新会话先读本文件，再读 `docs/tech/01-架构与双端契约.md`。语言：**中文**。负责人：本人（PM/UX）。
> 跨仓库的规矩在私有仓库 `xeolab/xeo-pm` 的 `MONO.md`（上一行引用，需并排克隆在 `../xeo-pm`）；产品上下文在它的 `project/rom/`。
> ⚠️ **本仓库公开**：私有仓库里的内容、人名、客户信息不要搬进来。
> 姊妹仓库：`xeolab/xeo-big-movie-box`（墨水屏观影盒子，本 Demo 的墨水屏端是它的「开机前」一段）。

## 1. 当前生效的约束

- **两端：** `ios/`（SwiftUI，租与还）+ `eink/`（单文件 HTML，Rom 首次激活与到期提醒）。**无后端、无网络请求、无真实支付 / 登录 / 物流。**
- **两端唯一接口是二维码 URL**（scheme `xeorental`），契约在 `docs/tech/01` §2——**改契约先改文档，两端一起改**。
- **墨水屏端必须是单个自包含 HTML**（不许外链 / fetch / import / 相对资源），遵守墨水屏 UX 硬约束：禁动画、高对比、触控 ≥48dp、不靠颜色传达关键信息。
- **墨水屏浏览器下限 = Onyx Chromium 85**（控制端从文件管理器打开 HTML 用的自带浏览器）：不许用 85 之后的 JS / CSS（如 `inset`、`dvh`、`replaceChildren`）；`eink/build.mjs` 会扫源码、命中即构建失败。桌面 Chrome 测不出这类问题，**改完要上真机看**。
- **iOS 只用免费个人团队可签的能力**：不加 Sign in with Apple 等付费账号能力（Apple 登录是占位按钮）。
- **业务逻辑放 `ios/RentalKit`（纯 Swift 包）**，`swift run RentalKitChecks` 必须通过——这是没有 Xcode 时唯一能跑的自检。
- **负责人已定**：支付倒计时 10 分钟；度数只能填非负整数；头围用前置摄像头真实测量；归还进度由演示按钮手动推进；逾期弹窗只提供「关闭，继续使用」。
- **视觉**：XEO 品牌规范（XEO Purple `#6638B6`，深色底用 `#9068F0`；白底黑字；标识用 `brand/` 原件不重绘）。
- **原方案参考图** `docs/reference/` 是内部讨论稿素材，**已 gitignore，不许提交到这个公开仓库**。

## 2. 文档

| 文档 | 回答 |
|---|---|
| `docs/prd/` | 做什么、做到什么算完（不写实现） |
| `docs/tech/` | 怎么实现的、契约、哪里不能动 |
| `docs/验收清单.md` | 做到哪、验到哪（状态只能靠证据升级，不许直接填 ✅） |

## 3. 工作约定

- 改动走分支 → PR → 负责人网页合并 → 同步主副本；主副本只留在 `main`，改动开 worktree（xeo-pm `MONO.md` §3–§4）。
- 每次能力落地或验证状态变化，当场改验收清单对应行。
