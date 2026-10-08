# 娘化桌宠融合版（Windows）

Kreeli 基于 [T7moris/GPT-Niang-Usage-Widget](https://github.com/T7moris/GPT-Niang-Usage-Widget) **v1.3.1** 制作的 fork，融合 [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) **dsh-whale-widget 0.3.17** 的大肥鱼娘语料和本机形象加载。感谢两个源工程及其贡献者。

<img src="gpt-niang-usage/assets/gpt-dragon-niang-bust.png" alt="上游原版白发 GPT 龙娘" width="220">

## 这一版增加了什么

- 右键「人物形象」切换 GPT 白发龙娘、本机 DSH 蓝发大肥鱼娘；支持导入自定义 PNG / JPG / BMP，自动保存选择。
- 每个人物使用独立的语录、编辑器和保存文件。大肥鱼采用 DSH 原版 47 句及权重；GPT 采用源工程原版 33 句。源语料中相同的句子原样保留。
- 轻点也能完整显示压扁与回弹。
- 快速连点采用独立后台混音，保留每次点击的按下与松开声音；预先缓存语录排版并合并设置保存，减少卡住后集中刷新的情况。
- 保留上游的 Codex 订阅额度、窗口跟随、拖动缩放、静音和自动启动功能。

这是独立的 Windows 桌面挂件，需本机 Codex 登录；并非 OpenAI 或 DeepSeek 官方项目。此次融合功能仅修改 Windows 端，`macos/` 保留上游实现，不包含上述多人物及连点修复。未接入 DSH 的 API 余额记账服务。

## 安装和使用

需要 Windows 10 / 11、Node.js 20+ 和已登录的 Codex 桌面端。

1. 在本 fork 的 **Code → Download ZIP** 下载完整源码并解压，或克隆本 fork 的默认分支。保留隐藏的 `.agents` 目录以及完整的 `gpt-niang-usage` 目录。
2. 双击根目录的 **`安装GPT娘.cmd`**。若已经运行旧版，请在原安装目录覆盖更新，避免同时登记两套安装。
3. 打开 Codex 主窗口；右键桌宠 → **人物形象**，即可切换角色或导入自己的图片。

**大肥鱼娘原图由使用者在本机提供。** 本仓库不打包 `DSniang1.png`，不重新授权该第三方素材。程序优先读取个人数据目录中的导入图、兼容本机已有的 `assets/deepseek-niang.png`，再查找常见 DSH 安装位置：

```text
%USERPROFILE%\.dsh\profiles\desktop\node_modules\dsh-whale-widget\assets\DSniang1.png
```

如果没有自动找到，在「人物形象 → 从 DSH 导入大肥鱼娘原图…」选择你已有 DSH 插件中的 **DSniang1.png**。导入原样保存图片，使用专属大肥鱼语录；没有 DSH 图片时自动显示 GPT 娘。其它人物请用「导入自己的人物图片…」。请按素材原许可使用，详细说明见 [第三方来源与许可](THIRD_PARTY_NOTICES.md)。

右键「编辑此人物的语录」只修改当前角色。偏好、导入图片和自定义语录保存在 `%LOCALAPPDATA%\GPTNiangUsage\state`，不会写回源码或随 GitHub 上传。双击 `打开GPT娘.cmd` 恢复显示；`停用GPT娘.cmd` 移除自动启动与插件登记，保留个人内容。

## 来源和版本

| 内容 | 源工程及版本 |
| --- | --- |
| Windows 主体、额度后端、GPT 龙娘、声音、原版 GPT 33 句 | [T7moris/GPT-Niang-Usage-Widget v1.3.1](https://github.com/T7moris/GPT-Niang-Usage-Widget/releases/tag/v1.3.1)，基线提交 `76859a8ba993103f9561b8388dd7c8dc94996446` |
| 大肥鱼 47 句默认随机语料及权重 | [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)，本机 dsh-whale-widget 0.3.17 的 `BUBBLE_DEFAULT_ITEMS` |
| 大肥鱼形象 | 使用者本机 DSH 插件的 `DSniang1.png`，本 fork 仅提供加载/导入代码 |
| 多人物、语录隔离、动画与快速连点修复 | 本 fork 的 Windows 修改 |

保留上游 Git 历史、MIT 许可证和素材声明。MIT 适用于代码，不代表第三方角色图片、声音等全部获得 MIT 授权。更多来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)；上游完整文档见 [README.upstream.md](README.upstream.md)，其中上游下载链接和 macOS 功能说明指向原项目。

## 验证

```powershell
cd gpt-niang-usage
npm test
npm run test:windows
```

Windows 检查包含安装/生命周期、完整 WPF 启动、角色选择及原图缺失回退、语录隔离、单击动画、排版，以及 200 次连续点击下的动画、气泡、声音和设置保存联合检查。真实音频测试需要输出设备；无音频设备的 CI 只跳过音频及联合声画压力检查，其余照常执行。

本机已有真实音频设备上的完整测试通过记录；性能数字只代表该测试机器，不保证所有电脑相同。用户配置、账户快照、登录信息和本机安装路径均不在本仓库中。
