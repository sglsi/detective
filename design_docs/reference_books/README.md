# 维多利亚侦探学 · 参考资源库（reference_books）

本目录存放《谁是大侦探》**知识库编写所用的一手史料**。它们只作**参考素材**，用于撰写
`godot_project/data/knowledge/knowledge_base.json` 中的知识条目；游戏运行时**不加载**本目录内容。

- 配套设计文档：`godot_project/docs/02_核心设计/05_侦探学方法论知识库.md`
- 条目回写工具与补丁留痕：`godot_project/references/detective_books/`（`_apply_kb_patch.py` + `_kb_*_patch.json`）

> ⚠️ 本目录原由另一克隆在仓库根 `design_docs/reference_books/` 建立；2026-09-15 曾同时存在
> 一份重复副本于 `godot_project/references/detective_books/`，现已删除（见文末「去重记录」）。

---

## 一、已下载书目（公有领域，纯文本；共 14 本）

### 第一批 10 本（Project Gutenberg）

| 文件 | 书名 | 作者 | 年代 | 语言 | 来源 |
|------|------|------|------|------|------|
| `hans_gross_criminal_psychology_1911.txt` | *Criminal Psychology: A Manual for Judges, Practitioners, and Students* | Hans Gross（Kallen 译） | 1911（德文原版 1898） | en | Gutenberg #1320 |
| `witthaus_medical_jurisprudence_v1.txt` | *Medical Jurisprudence, Forensic Medicine and Toxicology, Vol. 1* | R. A. Witthaus / Becker | 1894–96 | en | Gutenberg #49027 |
| `robertson_aids_forensic_medicine.txt` | *Aids to Forensic Medicine and Toxicology* | W. G. Aitchison Robertson | 1900s | en | Gutenberg #19019 |
| `galton_fingerprints_1892.txt` | *Finger Prints* | Francis Galton | 1892 | en | Gutenberg #36979 |
| `lombroso_criminal_man_1911_en.txt` | *Criminal Man*（据 Lombroso 分类） | Gina Lombroso（英译） | 1911 | en | Gutenberg #29895 |
| `lombroso_uomo_delinquente_it.txt` | *L'uomo delinquente* | Cesare Lombroso | 1876/1897 | it | Gutenberg #59298 |
| `dilnot_scotland_yard_1915.txt` | *Scotland Yard: The Methods and Organisation of the Metropolitan Police* | George Dilnot | 1915 | en | Gutenberg #31629 |
| `pinkerton_expressman_and_the_detective.txt` | *The Expressman and the Detective* | Allan Pinkerton | 1874 | en | Gutenberg #22155 |
| `pinkerton_burglars_fate.txt` | *The Burglar's Fate, and The Detectives* | Allan Pinkerton | 1884 | en | Gutenberg #17762 |
| `pinkerton_true_detective_stories.txt` | *True Detective Stories from the Archives of the Pinkertons* | Cleveland Moffett | 1897 | en | Gutenberg #33922 |

### 第二批 4 本（Wellcome Collection / Internet Archive 扫描 OCR）

| 文件 | 书名 | 作者 | 年代 | 语言 | 来源 |
|------|------|------|------|------|------|
| `taylor_principles_practice_medical_jurisprudence_1865.txt` | *The Principles and Practice of Medical Jurisprudence* | Alfred Swaine Taylor | 1865 | en | Wellcome `b21964944`（IA ALTO） |
| `taylor_manual_medical_jurisprudence_1874.txt` | *A Manual of Medical Jurisprudence*（12th ed.） | Alfred Swaine Taylor（Stevenson 编） | 1874 | en | Wellcome `b22652516`（IA ALTO） |
| `guy_principles_forensic_medicine_vol2.txt` | *Principles of Forensic Medicine*（Vol. 2） | William A. Guy | 1840s | en | Wellcome `b3303073x`（IA ALTO） |
| `henry_classification_finger_prints_1900.txt` | *Classification and Uses of Finger Prints*（3rd ed.） | E. R. Henry | 1900 | en | Wellcome `b31357908`（IA ALTO） |

> 第二批为扫描 OCR 文本（含页标记 `[N/总数 ....jp2]`），OCR 有少量错字（如 JURISPRUDENCE 被识成
> JUKISPEUDENCE），条目引文中的数字与术语已逐条核对。抓取脚本见 `tools/wellcome_alto_fetch.sh`。

> 全部为 **Public Domain**（公有领域），可自由复制、改写、再加工。Gutenberg 头部/尾部的
> 许可声明段落可去除后使用正文。

**内容映射（对应知识库 KB-A~L 各域）**

- **KB-H 侦查学总纲/现场勘查** → `hans_gross_criminal_psychology_1911.txt`
- **KB-I 身份识别技术** → `galton_fingerprints_1892.txt`、`henry_classification_finger_prints_1900.txt`
- **KB-J 犯罪学理论与时代观念** → `lombroso_criminal_man_1911_en.txt`、`lombroso_uomo_delinquente_it.txt`
- **KB-K 侦探职业与警务实务** → `dilnot_scotland_yard_1915.txt`、`pinkerton_*`（3 本）
- **KB-L 法医学与尸体检验** → `witthaus_*`、`robertson_*`、`taylor_*`（2 本）、`guy_*`
- （KB-A~G 为早期以游戏叙事为基础编制，可靠性有限，仅作时代背景保留）

---

## 二、待获取书目（本机网络暂不可直连，需手动下载）

以下站点在本机当前网络下**不可直连**：archive.org / HathiTrust / Google Books
（Wellcome Collection 可经 `tools/wellcome_alto_fetch.sh` 抓取 ALTO 全文，第二批 4 本即由此而来）。

| 书名 | 作者 | 年代 | 建议来源（手动） |
|------|------|------|-----------------|
| *Criminal Investigation: A Practical Handbook for Magistrates, Police Officers, and Lawyers* | Hans Gross（Adam 兄弟译） | 1906 | archive.org：`criminalinvestig00grosuoft`（3 卷）<br>https://archive.org/details/criminalinvestig00grosuoft |
| *Handbuch für Untersuchungsrichter als System der Kriminalistik* | Hans Gross | 1908（第 5 版，德文，2 卷） | archive.org / HathiTrust |
| *A Police Code and General Manual of the Criminal Law* | C. E. Howard Vincent | 1881／1889／1895 | archive.org |
| *Professional Criminals of America* | Thomas Byrnes | 1886 | archive.org |
| *Signaletic Instructions*（*Instructions signalétiques* 英译） | Alphonse Bertillon | 1893／1896 | archive.org / Gallica（BnF） |

> ✅ 已获取（原列于本表）：Taylor《Principles》(1865)、Taylor《Manual》(1874)、Guy《Principles》、
> Henry《Finger Prints》(1900) —— 见上表第二批。
>
> 若有可直连的新源（如校园网/镜像），把 `.txt`/`.pdf` 放入本目录即可，命名沿用
> `<作者姓>_<书名关键词>_<年份>.<ext>`。

---

## 三、使用注意

1. **只做素材，不入游戏包**：本目录仅作编写参考；知识库正文写入 `knowledge_base.json`。
2. **保留时代缺陷**：原典中的"天生犯罪人""面相学""颅相学""刑讯"等属时代真貌，撰写条目时应**如实保留并标注**
   （`limitation` 字段），不要用现代结论"修正"。
3. **可溯源**：每条知识条目须在 `source` 字段注明来源（作者 + 书名 + 年代 + 章节），并尽量补 `case_ref` 真实案例。
4. **改了 KB 数据要重导出 Web**：`knowledge_base.json` 在 `res://data/` 下、会被打进 pck，
   因此浏览器端要看到新条目必须重新导出 Web 包（详见 `godot-detective-sop` 技能）。

---

## 四、去重记录（2026-09-15）

- **背景**：本仓库曾同时存在两份参考书——本目录（另一克隆提交，正式位置）与
  `godot_project/references/detective_books/`（本地下载副本，未跟踪）。
- **核对结果**：
  - 7 本（dilnot / galton / lombroso_en / pinkerton ×3 / robertson）两份**内容完全一致**（仅 CRLF vs LF）；
  - **3 本**（hans_gross / lombroso_uo&shy;mo_it / witthaus）本目录版本**被截断**，分别只剩完整全文的
    约 28% / 31% / 18%（结尾停在句子中间）。
- **处理**：以完整全文替换上述 3 个截断文件（并统一为 LF），随后删除
  `godot_project/references/detective_books/` 下的 10 个重复 `.txt`；
  该目录仅保留条目回写工具与补丁留痕（`_apply_kb_patch.py`、`_kb_*_patch.json`）。
- 复检：14 本在两处不再重复，本目录文件均与下载原件逐字节一致。
