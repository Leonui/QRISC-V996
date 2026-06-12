#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
QRISC-V996 串口控制台 —— biRISC-V SoC,tb_soc(全 RTL 外设)版

和 biriscv_console.py(tb_top / SystemC 版)长得一样,区别只在输入路径:
tb_soc 的 UART 是真 RTL,输入要经一条真实串行线。GUI 把你键入的命令**追加到一个
输入文件**,tb 里的串行发送器(reopen+fseek)把它按 8N1/BIT_DIV 一位位移进
uart_lite 的 RX 引脚 -> SBI console_getchar -> hvc0 -> busybox sh;内核/shell 的输出
从真实 uart_tx 串行线移出、被 tb 反序列化,经 stdout 回到这里。

依赖:  python3-tk
显示:  Windows 11 的 WSLg 自带图形;直接 `python3 biriscv_soc_console.py` 弹窗。
"""
import os
import re
import codecs
import queue
import threading
import subprocess
import tkinter as tk

# 剥掉 ANSI 转义码(busybox ls 等的颜色码),Tkinter 不解析它们,否则显示成乱码
_ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
from tkinter import scrolledtext

HERE = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.join(HERE, "run_soc_backend.sh")
ROOT = os.path.dirname(HERE)
INPUT_FILE = os.path.join(ROOT, "tb", "tb_soc", ".gui_input.txt")
VCD_FILE = os.path.join(ROOT, "tb", "tb_soc", "tb_soc.fst")

# 波形深度(verilator --trace-depth):录的层次越深 VCD 越大越慢。切换会重编对应深度的二进制(缓存)。
DEPTHS = {"顶层": "1", "+SoC接口": "2", "全部(大)": "0"}

# 可选镜像(下拉框):hvc0 = SBI 控制台(快);ttyUL0 = 内核 uartlite 驱动(真驱动,慢)
IMAGES = {
    "hvc0  (快)":          os.path.join(ROOT, "image", "biriscv-linux-5.4-hvc0.elf"),
    "ttyUL0  (真驱动·慢)": os.path.join(ROOT, "image", "biriscv-linux-5.4-ttyul0.elf"),
}

BM_EX_DIR = os.path.join(ROOT, "sdk", "baremetal", "examples")

def list_baremetal():
    """扫 sdk/baremetal/examples/*.c,返回 {程序名: 程序名}"""
    out = {}
    try:
        for f in sorted(os.listdir(BM_EX_DIR)):
            if f.endswith(".c"):
                out[f[:-2]] = f[:-2]
    except OSError:
        pass
    return out or {"(无示例)": ""}

BG, FG, BG2 = "#1e1e1e", "#d4d4d4", "#252526"
ACCENT, DIM, ERRCOL = "#4ec9b0", "#6a9955", "#f48771"


class Console(tk.Tk):
    def __init__(self):
        super().__init__()
        # 标题用纯 ASCII:WSLg 的窗口管理器字体没中文字形,中文标题会变方块
        self.title("QRISC-V996 Console  (biRISC-V SoC, full-RTL peripherals / real serial UART)")
        self.geometry("960x620")
        self.configure(bg=BG)
        self.proc = None
        self.q = queue.Queue()
        self._hist, self._hist_i = [], 0
        self._ansi_pending = ""        # 跨批次剥离 ANSI 码时,暂存末尾半截的转义序列
        # 增量 UTF-8 解码器:跨 drain 批次缓存半个多字节字符(否则汉字被拆 -> 乱码/?)
        self._dec = codecs.getincrementaldecoder("utf-8")("replace")
        self._build_ui()
        self.after(40, self._drain)
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        bar = tk.Frame(self, bg=BG2); bar.pack(side="top", fill="x")
        self.btn_start = tk.Button(bar, text="▶ 启动 Linux", command=self.start,
                                   bg="#0e639c", fg="white", relief="flat", padx=10, pady=4)
        self.btn_start.pack(side="left", padx=(8, 4), pady=6)
        self.btn_stop = tk.Button(bar, text="■ 停止", command=self.stop, state="disabled",
                                  bg="#5a1d1d", fg="white", relief="flat", padx=10, pady=4)
        self.btn_stop.pack(side="left", padx=4, pady=6)
        self.btn_ctrlc = tk.Button(bar, text="Ctrl-C", command=lambda: self._send_raw("\x03"),
                                   state="disabled", bg="#3a3d41", fg="white", relief="flat",
                                   padx=8, pady=4)
        self.btn_ctrlc.pack(side="left", padx=4, pady=6)
        tk.Button(bar, text="清屏", command=self.clear, bg="#3a3d41", fg="white",
                  relief="flat", padx=8, pady=4).pack(side="left", padx=4, pady=6)
        # 模式下拉(Linux / 裸机)
        tk.Label(bar, text="模式:", bg=BG2, fg="#999").pack(side="left", padx=(12, 2))
        self.mode_var = tk.StringVar(value="Linux")
        self.mode_menu = tk.OptionMenu(bar, self.mode_var, "Linux", "裸机", command=self._on_mode)
        self.mode_menu.configure(bg="#3a3d41", fg="white", relief="flat",
                                 highlightthickness=0, activebackground="#0e639c")
        self.mode_menu["menu"].configure(bg="#3a3d41", fg="white")
        self.mode_menu.pack(side="left", padx=2, pady=6)
        # 选择下拉(随模式变:Linux=镜像, 裸机=程序)
        self.sel_var = tk.StringVar(value=list(IMAGES.keys())[0])
        self.sel_menu = tk.OptionMenu(bar, self.sel_var, *IMAGES.keys())
        self.sel_menu.configure(bg="#3a3d41", fg="white", relief="flat",
                                highlightthickness=0, activebackground="#0e639c")
        self.sel_menu["menu"].configure(bg="#3a3d41", fg="white")
        self.sel_menu.pack(side="left", padx=2, pady=6)
        # 虚拟磁盘(仅 Linux):勾上则挂载 disk.hex,程序出现在 /opt(不用重建内核)
        self.disk_var = tk.BooleanVar(value=True)
        self.chk_disk = tk.Checkbutton(bar, text="虚拟磁盘", variable=self.disk_var,
                                       bg=BG2, fg=FG, selectcolor=BG, activebackground=BG2,
                                       activeforeground=FG, relief="flat")
        self.chk_disk.pack(side="left", padx=(10, 0))
        # 录波形 + 查看波形
        self.trace_var = tk.BooleanVar(value=False)
        self.chk_trace = tk.Checkbutton(bar, text="录波形", variable=self.trace_var,
                                        bg=BG2, fg=FG, selectcolor=BG, activebackground=BG2,
                                        activeforeground=FG, relief="flat")
        self.chk_trace.pack(side="left", padx=(12, 0))
        tk.Label(bar, text="周期", bg=BG2, fg="#999").pack(side="left")
        self.cyc_entry = tk.Entry(bar, width=8, bg="#3c3c3c", fg=FG, insertbackground=FG, relief="flat")
        self.cyc_entry.insert(0, "1000000")
        self.cyc_entry.pack(side="left", padx=2, pady=6)
        tk.Label(bar, text="深度", bg=BG2, fg="#999").pack(side="left")
        self.depth_var = tk.StringVar(value=list(DEPTHS.keys())[0])
        self.depth_menu = tk.OptionMenu(bar, self.depth_var, *DEPTHS.keys())
        self.depth_menu.configure(bg="#3a3d41", fg="white", relief="flat", highlightthickness=0)
        self.depth_menu["menu"].configure(bg="#3a3d41", fg="white")
        self.depth_menu.pack(side="left", padx=2, pady=6)
        self.btn_wave = tk.Button(bar, text="📊 查看波形", command=self.view_wave,
                                  bg="#3a3d41", fg="white", relief="flat", padx=8, pady=4)
        self.btn_wave.pack(side="left", padx=4, pady=6)
        self.status = tk.Label(bar, text="○ 未启动", bg=BG2, fg="#999")
        self.status.pack(side="right", padx=10)

        self.out = scrolledtext.ScrolledText(self, bg=BG, fg=FG, insertbackground=FG,
                                             font=("Monospace", 10), wrap="char",
                                             relief="flat", padx=8, pady=6, state="disabled")
        self.out.pack(side="top", fill="both", expand=True)
        self.out.tag_config("sys", foreground=ACCENT)
        self.out.tag_config("err", foreground=ERRCOL)

        row = tk.Frame(self, bg=BG2); row.pack(side="bottom", fill="x")
        tk.Label(row, text="输入:", bg=BG2, fg="#999").pack(side="left", padx=(8, 4), pady=6)
        self.entry = tk.Entry(row, bg="#3c3c3c", fg=FG, insertbackground=FG,
                              relief="flat", font=("Monospace", 10))
        self.entry.pack(side="left", fill="x", expand=True, pady=6)
        self.entry.bind("<Return>", lambda e: self.send_line())
        self.entry.bind("<Up>", self._hist_up)
        self.entry.bind("<Down>", self._hist_down)
        self.btn_send = tk.Button(row, text="发送 ⏎", command=self.send_line, state="disabled",
                                  bg="#0e639c", fg="white", relief="flat", padx=10, pady=2)
        self.btn_send.pack(side="left", padx=6, pady=6)

        self._write("QRISC-V996 串口控制台 —— biRISC-V SoC,tb_soc(全RTL外设,真串行UART)\n", "sys")
        self._write("点「▶ 启动 Linux」开始。周期级 RTL 仿真:到 shell (~ #) 约 4-5 分钟。\n"
                    "到提示符后在「输入」框敲命令(uname -a、cat /proc/cpuinfo、ls /)回车发送。\n"
                    "命令经真实串行线送入,约 15 字符/秒,回车后等一两秒回显属正常。\n\n", "sys")

    def _on_mode(self, *_):
        # 切模式 → 重填「选择」下拉:Linux=镜像, 裸机=程序
        items = IMAGES if self.mode_var.get() == "Linux" else list_baremetal()
        m = self.sel_menu["menu"]; m.delete(0, "end")
        for k in items:
            m.add_command(label=k, command=lambda v=k: self.sel_var.set(v))
        self.sel_var.set(list(items.keys())[0])

    def start(self):
        if self.proc:
            return
        if not os.access(BACKEND, os.X_OK):
            try: os.chmod(BACKEND, 0o755)
            except OSError: pass
        try:
            open(INPUT_FILE, "w").close()
        except OSError:
            pass
        env = dict(os.environ, SOC_INPUT=INPUT_FILE)
        if self.mode_var.get() == "裸机":
            sel = self.sel_var.get()
            env["MODE"] = "baremetal"; env["SEL"] = sel
            self._write(f"[裸机] 编译并运行 sdk/baremetal/examples/{sel}.c(无 OS,直接在核上)\n", "sys")
        else:
            elf = IMAGES[self.sel_var.get()]
            env["MODE"] = "linux"; env["ELF"] = elf
            self._write(f"[Linux] {self.sel_var.get()}  ({os.path.basename(elf)})\n", "sys")
            if self.disk_var.get():
                env["USE_DISK"] = "1"
                self._write("[虚拟磁盘] 挂载 disk.hex —— 程序会出现在 /opt(开机后 ls /opt 看；改程序跑 sdk/linux/mkdisk.sh,不用重建内核)\n", "sys")
        if self.trace_var.get():
            cyc = (self.cyc_entry.get().strip() or "1000000")
            depth = DEPTHS[self.depth_var.get()]
            env["TRACE"] = "1"; env["TRACE_CYCLES"] = cyc; env["TRACE_DEPTH"] = depth
            self._write(f"[波形] 录制开启:深度「{self.depth_var.get()}」,跑 {cyc} 周期后自动停 -> tb_soc.fst"
                        f"(该深度首次会先编译带 --trace 的版本,慢)\n", "sys")
            self._write("[波形] 点「停止」或等到周期上限,都会生成波形(到结束那一刻为止),"
                        "再点「📊 查看波形」打开。\n", "sys")
        self._dec.reset(); self._ansi_pending = ""   # 新一轮:清掉上次残留的半字符/转义
        try:
            self.proc = subprocess.Popen(["bash", BACKEND], stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT, bufsize=0, env=env)
        except Exception as e:
            self._write(f"\n[无法启动仿真] {e}\n", "err"); self.proc = None; return
        threading.Thread(target=self._read_worker, daemon=True).start()
        self._set_running(True)
        self._write("[启动仿真中…首次会先构建,稍候]\n", "sys")
        self.entry.focus_set()

    def stop(self):
        if not self.proc:
            return
        try: self.proc.terminate()
        except Exception: pass
        try: subprocess.Popen(["pkill", "-TERM", "-f", "build_vl.*tb_soc"])
        except Exception: pass
        self.proc = None
        self._set_running(False)
        self._write("\n[仿真已停止]\n", "sys")

    def _read_worker(self):
        f = self.proc.stdout
        try:
            while True:
                b = f.read(1)
                if not b:
                    break
                self.q.put(b)
        except Exception:
            pass
        self.q.put(None)

    def _drain(self):
        buf = []
        try:
            while True:
                item = self.q.get_nowait()
                if item is None:
                    if buf:
                        self._feed_bytes(b"".join(buf)); buf = []
                    self._feed_sim(self._dec.decode(b"", final=True))   # 冲掉残留半字符
                    self._write("\n[仿真进程已退出]\n", "sys")
                    self.proc = None; self._set_running(False); continue
                buf.append(item)
        except queue.Empty:
            pass
        if buf:
            self._feed_bytes(b"".join(buf))
        self.after(40, self._drain)

    def _feed_bytes(self, data):
        # 增量解码(半个汉字留到下批)+ 去掉 \r(否则行尾留个字体画不出的 口)
        text = self._dec.decode(data).replace("\r", "")
        if text:
            self._feed_sim(text)

    def send_line(self):
        text = self.entry.get()
        self._send_raw(text + "\n")
        if text.strip():
            self._hist.append(text)
        self._hist_i = len(self._hist)
        self.entry.delete(0, "end")

    def _send_raw(self, s):
        # tb_soc 的输入走文件追加:串行发送器(reopen+fseek)会读到新内容并移进串口
        if not self.proc:
            self._write("[未运行,无法发送]\n", "err"); return
        try:
            with open(INPUT_FILE, "a") as f:
                f.write(s); f.flush()
        except Exception as e:
            self._write(f"[发送失败] {e}\n", "err")

    def _hist_up(self, _e):
        if self._hist and self._hist_i > 0:
            self._hist_i -= 1
            self.entry.delete(0, "end"); self.entry.insert(0, self._hist[self._hist_i])
        return "break"

    def _hist_down(self, _e):
        if self._hist_i < len(self._hist) - 1:
            self._hist_i += 1
            self.entry.delete(0, "end"); self.entry.insert(0, self._hist[self._hist_i])
        else:
            self._hist_i = len(self._hist); self.entry.delete(0, "end")
        return "break"

    def _feed_sim(self, text):
        # 仿真输出:流式剥离 ANSI 颜色码。转义码可能被串口逐字节读取拆散在多批里,
        # 所以把末尾"半截还没结束的转义序列"暂存,和下一批拼起来再剥。
        text = self._ansi_pending + text
        self._ansi_pending = ""
        m = re.search(r"\x1b\[?[0-9;?]*$", text)   # 末尾不完整的 CSI 序列
        if m:
            self._ansi_pending = text[m.start():]
            text = text[:m.start()]
        self._write(_ANSI_RE.sub("", text))

    def _write(self, text, tag=None):
        self.out.configure(state="normal")
        self.out.insert("end", text, (tag,) if tag else ())
        self.out.see("end"); self.out.configure(state="disabled")

    def view_wave(self):
        if not os.path.exists(VCD_FILE) or os.path.getsize(VCD_FILE) == 0:
            self._write("[波形] 还没有波形文件 —— 勾选「录波形」跑一次(到设定周期会自动停)后再看\n", "err")
            return
        try:
            subprocess.Popen(["gtkwave", VCD_FILE], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            self._write(f"[波形] gtkwave 打开 {VCD_FILE}\n", "sys")
        except FileNotFoundError:
            self._write("[波形] 没装 gtkwave:sudo apt install -y gtkwave\n", "err")
        except Exception as e:
            self._write(f"[波形] 打开失败:{e}\n", "err")

    def clear(self):
        self.out.configure(state="normal"); self.out.delete("1.0", "end")
        self.out.configure(state="disabled")

    def _set_running(self, on):
        self.btn_start.configure(state="disabled" if on else "normal")
        self.btn_stop.configure(state="normal" if on else "disabled")
        self.btn_ctrlc.configure(state="normal" if on else "disabled")
        self.btn_send.configure(state="normal" if on else "disabled")
        self.mode_menu.configure(state="disabled" if on else "normal")
        self.sel_menu.configure(state="disabled" if on else "normal")
        self.chk_disk.configure(state="disabled" if on else "normal")
        self.chk_trace.configure(state="disabled" if on else "normal")
        self.cyc_entry.configure(state="disabled" if on else "normal")
        self.depth_menu.configure(state="disabled" if on else "normal")
        self.status.configure(text="● 运行中" if on else "○ 已停止",
                              fg=ACCENT if on else "#999")

    def _on_close(self):
        try: self.stop()
        finally: self.destroy()


if __name__ == "__main__":
    Console().mainloop()
