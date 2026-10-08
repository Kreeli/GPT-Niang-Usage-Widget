# 第三方来源与许可

## GPT娘额度挂件

- 上游：[T7moris/GPT-Niang-Usage-Widget](https://github.com/T7moris/GPT-Niang-Usage-Widget)
- 基线：v1.3.1 / `76859a8ba993103f9561b8388dd7c8dc94996446`。
- 本仓库保留上游完整 Git 历史、[LICENSE](LICENSE)、[子目录 LICENSE](gpt-niang-usage/LICENSE)、原版文档和贡献记录。本 fork 增补 Windows 多人物和交互修复，保留 macOS 上游实现。
- GPT 33 句语录来自 v1.3.1 Windows 发布包 `assets/quotes.json`，保留原始字节与 [quotes-LICENSE.txt](gpt-niang-usage/assets/quotes-LICENSE.txt)。
- GPT 龙娘图片与按压/松开声音沿用上游；上游 LICENSE 明确图片及角色参考保留其适用权利，本 fork 不宣称角色或声音为原创，也不扩张授权范围。

## DeepSeek 大肥鱼

- 上游：[MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)
- 使用的语料版本：dsh-whale-widget 0.3.17，`assets/whale-widget.js` 中 `BUBBLE_DEFAULT_ITEMS` 的随机文本条目，保留 47 句及原权重。
- 语料/相关代码的 MIT 声明见 [deepseek-quotes-LICENSE.txt](gpt-niang-usage/assets/deepseek-quotes-LICENSE.txt)，保留 Copyright (c) 2026 MeteorNOX。
- 原样保留上游美术范围说明：[deepseek-artwork-PROVENANCE.md](gpt-niang-usage/assets/deepseek-artwork-PROVENANCE.md)。其中「本仓库」「本插件」指 DSH 源工程，路径也相对于该工程。
- 该声明将 DSH `assets/` 美术素材排除在 MIT 之外，限定随原插件使用，未授予再许可。因此本 fork **不提交或打包大肥鱼原图**，仅支持使用者从自己合法持有的 DSH 安装中本地加载/导入 `DSniang1.png`。不包含 DSH 的动图或音效。

本 fork 的代码修改沿用 MIT；第三方美术素材的权利和使用条件仍由各自来源决定。新增角色由使用者自行在本地导入，不会自动上传。
