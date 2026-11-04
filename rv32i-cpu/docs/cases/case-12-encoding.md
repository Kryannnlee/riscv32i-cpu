# Case 12 · 中文在 Windows 终端变乱码，以及脚本改文件把中文写坏

> **代码来源**：原始　**严重程度**：浪费（不致命，但会误以为文件坏了）　**阶段**：全程

---

## 1. 现象 A：读文件时满屏乱码

用命令打印含中文的文件内容：

```
����=136
```

第一反应是"文件编码坏了"。**但文件其实是好的 UTF-8。**

## 2. 原因 A

Windows 中文版控制台默认代码页是 **GBK（936）**。
它按 GBK 去解释 UTF-8 的字节流，于是中文全变成乱码。

**文件没问题，是"看"的方式不对。**

## 3. 现象 B：脚本改完文件，中文真的坏了

用 PowerShell 批量替换：

```powershell
Get-Content file.md -Raw | Set-Content file.md
```

结果文件里的中文**真的**变成了乱码，保存下来也是坏的。

## 4. 原因 B

Windows PowerShell 5.1 的 `Get-Content` / `Set-Content` **默认不是 UTF-8**，
而是系统 ANSI（GBK）。

读的时候按 GBK 解码 UTF-8 字节 → 已经坏了；
写回去再按 GBK 编码 → 彻底救不回来。

## 5. 怎么区分 A 和 B

| | 现象 A（只是显示） | 现象 B（真的坏了） |
| --- | --- | --- |
| 用 VSCode 打开 | 中文正常 | 中文乱码 |
| 字节层面检查 | UTF-8 合法 | 已不是合法 UTF-8 |
| 需不需要修 | 不用 | 必须恢复 |

检查方法：

```bash
python -I -c "open('file.md','rb').read().decode('utf-8'); print('utf8 OK')"
```

能顺利解码 = 文件是好的。

## 6. 当时的做法

- **看文件**：用 Read 工具 / VSCode，不用 `type`、`more`、`cat`
- **改文件**：用编辑工具，不用 PowerShell 管道
- **必须用脚本时**：Python 显式指定编码

```python
open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8', newline='\n').write(s)
```

PowerShell 版（必须两个都指定）：

```powershell
Get-Content file.md -Raw -Encoding utf8 | Set-Content file.md -Encoding utf8
```

## 7. 怎么防止再犯

- **先判断文件坏没坏，再决定怎么办**。十次里有九次只是显示问题。
- 项目里所有 `.sv` / `.md` 统一 UTF-8，改文件只走编辑器或 Python。
- 用脚本批量替换含中文的文件之前，先备份。

## 8. 一句话记忆

> 终端乱码 ≠ 文件坏了。先 `decode('utf-8')` 试一下，能过就是显示问题。
> PowerShell 5.1 默认不是 UTF-8，读写都要显式指定。
