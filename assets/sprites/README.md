# 精灵帧动画素材（拖入即生效）

游戏内置了帧动画框架（`scripts/sprite_library.gd`）。把符合命名约定的 PNG 放进
下面的目录，敌人 / 防御塔就会自动改用 `AnimatedSprite2D` 渲染；**没有放图时**
自动回退到原来的 SVG / 程序化绘制，游戏照常运行。

## 命名约定

```
assets/sprites/enemies/<type>_<index>.png
assets/sprites/towers/<type>_<index>.png
```

- `<index>` 从 `0` 起、必须连续（`_0, _1, _2 …`）。
- **单帧**（只有 `_0`）= 静态贴图；**多帧** = 逐帧循环动画（走路 / 待机）。
- 框架按字节流直接解码 PNG，**无需在编辑器里导入**，放进去即可。

### 需要的文件名

| 单位 | 文件（静态最少放第一个） |
|---|---|
| 普通怪 grunt | `enemies/grunt_0.png` `grunt_1.png` … |
| 快速怪 runner | `enemies/runner_0.png` `runner_1.png` … |
| 重甲怪 tank | `enemies/tank_0.png` `tank_1.png` … |
| 箭塔 arrow | `towers/arrow_0.png` `arrow_1.png` … |
| 炮塔 cannon | `towers/cannon_0.png` `cannon_1.png` … |
| 冰塔 frost | `towers/frost_0.png` `frost_1.png` … |

## 从哪里拿 Kenney 素材（CC0，可商用、可改、免署名）

1. 打开 <https://kenney.nl/assets> ，搜索并下载下列任一包（都是 CC0）：
   - **Tower Defense (Top-Down)** —— 含塔与敌人的俯视图，适合直接做静态贴图。
   - **Toon Characters 1** / **Tiny Town** / **Robot Pack** —— 含多帧，可做走路动画。
2. 解压后从包里挑选合适的 PNG，**按上表重命名**放入对应目录即可。
   - 想要动画就放多帧（角色行走序列重命名为 `grunt_0.png, grunt_1.png …`）。
   - 只想换静态美术就各放一张 `_0.png`。

## 调参

帧率与显示缩放在 `scripts/sprite_library.gd` 的 `ENEMY_TUNING` / `TOWER_TUNING` 里：

```gdscript
const ENEMY_TUNING := {
    "grunt": {"fps": 8.0, "scale": 0.55},
    ...
}
```

- `fps`：多帧动画的播放速度。
- `scale`：精灵显示缩放（按你素材的像素尺寸调，使其约占一个 80px 格子）。

## 行为说明

- 敌人精灵按行进方向水平翻转（`flip_h`），受击时整体提亮，死亡 / 减速 / 血条等
  状态层仍由代码绘制并叠加在精灵之上。
- 防御塔精灵开火时短暂提亮；等级点、射程圈、攻击指示线叠加在精灵之上。
- 任何一类缺图都会**单独回退**到原渲染，可逐个替换、混用。
