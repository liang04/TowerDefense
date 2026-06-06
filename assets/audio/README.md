# 音频素材（拖入即生效）

游戏内置了音频接口（`scripts/sfx.gd`）。把音频文件按下面的约定放进对应目录，
就会**优先播放真实音频**；**没放文件时**自动回退到程序合成的"哔"声，游戏照常出声。
文件以"直接从磁盘载入"方式加载，**无需在编辑器里导入**，放进去即可。

支持格式：`.ogg`（推荐，尤其音乐）或 `.wav`。同名时优先用 `.ogg`。

## 音效

```
assets/audio/sfx/<name>.ogg   （或 .wav）
```

`<name>` 必须是下列之一（对应游戏事件）：

| 文件名 | 触发时机 |
|---|---|
| `shoot`     | 植物开火 |
| `hit`       | 子弹命中僵尸 |
| `kill`      | 击退僵尸 |
| `leak`      | 僵尸突破防线（漏怪） |
| `wave`      | 新一波开始 |
| `upgrade`   | 升级植物 |
| `sell`      | 铲除植物 |
| `win`       | 通关胜利 |
| `game_over` | 游戏失败 |

只放其中几个也可以，未放的继续用合成音。

## 背景音乐

```
assets/audio/bgm/theme.ogg    （或 .wav，循环播放）
```

放一个 `theme.ogg` 即可，进入游戏自动循环播放。建议用 OGG（循环更顺滑）。

> 提示：游戏内按 **M 键**可一键静音/取消静音（音效与音乐同时生效，状态跨场景保留）。

## 从哪里拿 CC0 音频（免费、可商用、免署名）

- <https://kenney.nl/assets>（搜 "Audio"，有 *Interface Sounds*、*RPG Audio*、*Impact Sounds* 等）
- <https://freesound.org>（注意筛选 CC0 许可）
- <https://opengameart.org>（筛选 CC0）

下载后挑合适的音效，**按上表重命名**放进 `sfx/`；音乐重命名为 `theme.ogg` 放进 `bgm/` 即可。

## 调音量

在 `scripts/sfx.gd` 顶部：

```gdscript
const SFX_VOLUME_DB := -8.0    # 音效音量
const BGM_VOLUME_DB := -14.0   # 音乐音量
```
