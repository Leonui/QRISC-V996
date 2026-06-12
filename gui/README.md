# gui/ —— 串口控制台 GUI

WSLg / X11 上的 Tkinter 图形控制台,跟仿真里的 Linux(或裸机程序)交互。

```bash
python3 gui/biriscv_soc_console.py
```

## 文件
| 文件 | 作用 |
|---|---|
| `biriscv_soc_console.py` | GUI 本体(Tkinter):工具栏 + 输出窗 + 输入框 + 历史命令 |
| `run_soc_backend.sh` | GUI 调用的后端:按模式编译/取镜像 → 转 hex → 起 `tb/tb_soc` |

## 工具栏
```
[▶启动][■停止][Ctrl-C][清屏]  模式:[Linux/裸机]  选择:[…]  ☐虚拟磁盘  ☐录波形 周期[…] 深度:[…] [📊查看波形]
```
- **模式 = Linux**:选 hvc0 / ttyUL0 镜像,启动到 `~ #`。
  - **虚拟磁盘**(默认勾):挂 `disk.hex`,程序出现在 `/opt`(配合 `sdk/linux/mkdisk.sh`)。
- **模式 = 裸机**:选 `sdk/baremetal/examples/` 下的 `.c`,**现编现跑**(无 OS,几秒出结果)。
- **录波形**:勾上 + 选深度/周期 → 跑完用「📊 查看波形」开 gtkwave 看 FST(GPIO/SPI 引脚时序等)。

## 实现要点
- 后端 stdout = UART 真串行线反序列化的字节,经**增量 UTF-8 解码**(中文不被拆成乱码)
  + **去 `\r`**(行尾不留豆腐块)+ **ANSI 转义剥离**(`ls` 颜色码不花屏)后显示。
- 窗口标题用纯 ASCII(WSLg 窗口管理器字体无中文字形,中文标题会变方块)。
- WSLg 偶尔把窗口开到屏幕外:`xdotool search --name QRISC-V windowmove 60 60` 可拉回。

> 早期还有 `biriscv_console.py`(对接已删除的 SystemC `tb_top`),已随旧 tb 一并删除。
