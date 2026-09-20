# DeviceMP3 for macOS

面向普通 Mac 用户的外接 U 盘音乐整理工具。双击运行后选择 U 盘，即可把 `.ncm`、`.flac` 和已有 `.mp3` 统一整理到 `MP3` 文件夹，适合游泳骨传导耳机及普通离线 MP3 播放器。

## 特点

- 自动列出已连接的外接磁盘，不写死 U 盘名称
- 输出 MP3 192 kbps、44.1 kHz、双声道
- 默认保留源文件；删除模式需要输入 `DELETE` 二次确认
- 递归扫描子文件夹，忽略 macOS 隐藏索引和废纸篓
- 转换失败时保留源文件
- 重复运行会跳过已有结果
- 在 U 盘的 `MP3/DeviceMP3-转换记录.txt` 保存处理记录

## 系统要求

- macOS 11 或更高版本
- Apple Silicon 或 Intel Mac
- [Homebrew](https://brew.sh/zh-cn/)
- `ffmpeg` 与 `ncmdump`

首次使用，在“终端”中运行：

```bash
brew install ffmpeg ncmdump
```

## 使用方法

1. 下载 `DeviceMP3.command`。
2. 插入 U 盘。
3. 双击脚本并选择 U 盘。
4. 建议首次选择“保留源文件”。
5. 完成后在 U 盘的 `MP3` 文件夹试听结果。

如果 macOS 阻止打开，可在 Finder 中右键脚本，选择“打开”，再确认一次。

## 安全说明

转换前建议备份重要文件。即使选择删除模式，脚本也只会在单个文件成功处理后删除对应的 NCM/FLAC，或移动已有 MP3；失败文件会保留。

本工具仅用于转换用户合法获得并有权处理的音频文件。请遵守当地法律、音乐服务条款及版权规定。

## 已知限制

- 首次安装依赖仍需使用终端。
- 同名歌曲以首个非空输出文件为准，后续同名文件会跳过。
- v0.1 主要在 Apple Silicon Mac 和 exFAT U 盘上验证。
- 这是一个 shell 脚本，不是经过 Apple 签名的 `.app`。

## 许可证

本项目脚本采用 MIT License。`ffmpeg`、`ncmdump` 及其依赖拥有各自的许可证，本项目不捆绑分发这些程序。
