
# 技术工具指南

详细技术方案见 维多利亚伦敦探案项目/设计文档/技术工具指南.md

## 核心技术选型

• **引擎：** Godot 4.7（锁定，根目录放.godot-version）| Compatibility/GLES3 | GDScript | TileMapLayer
• **导出：** Web优先（M1）→ 原生手机（M2+）
• **通信：** M1仅HTTPRequest（信号驱动）→ M2+WebSocket（线索推送/跨设备同步）→ M3+多人。禁用HTTPClient
• **后端：** RESTful+JSON，Web/Mobile共用API
• **存储：** 游客→本地临时缓存（退出即失）；注册→本地+服务器同步

## 关键系统决策

• **注册：** 默认游客→保存时弹注册（用户名/手机/邮箱），跨平台同步
• **存档同步：** M1服务端覆盖（最新时间戳为准）→ M2+案件级合并 → M3+双向+手动选择
• **瓦片加载：** 案件Rect2按需加载，单TileMapLayer+set_cell()动态管理，淡入0.3s过渡，CanvasGroup+子TileMapLayer做迷雾
• **难度：** 简单(自动填写+指引) / 普通(平衡+动态提示概率) / 困难(手动+底线)

## 技术原则

• 稳定性：成熟架构优先，移动端兼容性优先，资源预加载缓存
• 可扩展：模块解耦，案件库动态添加，数据驱动（配置与代码分离）

## 项目目录（res://）

scenes/(systems|cases|ui) · scripts/(systems|cases|ui) · cases/(.tres/.res) · assets/(tilesets|sprites|fonts) · data/(dialogue|config) · addons/
• 函数参数+返回值加类型注解；案件用.tres或JSON；配置与代码分离

## 标准化方法论

• **三层文档：** L1→L3字段引用，L3头部加📍规范引用；A类全同步/B类增量/C类案件内
• **MVP：** 核心交互优先（有效+有趣）；关联图谱M3+；豁免须有替代+补全时机
• **软锁：** 时间锁必带bypass+remedy；审阅强制检查time_lock=true的bypass+remedy字段
• **双版本号：** 客户端vX.Y.Z(功能) / 内容数据(案件/资源) / 存档格式(save_version)，三者独立
• **双向锁：** Git Hook/CI合并时校验引用节号有效性

## 工具使用经验

• **sessions_spawn验证：** 子任务报告完成后必须用wc -l/head/tail/ls验证实际文件更新，不通过则重新派发
• **Godot工程：** ①CanvasLayer分离场景与推理墙UI ②.tres做知识库载体(@export编辑) ③Tween做轻量交互(放大镜/卷尺)，按难度动态调速；Godot核心价值：Control拖拽做推理墙、2D像素坐标零误差做测量、AnimationPlayer驱动镜头演出、RichTextLabel+BBCode做知识库高亮跳转
• **agent-browser：** 需云电脑权益；复杂任务优先search_images+curl替代；外部源限制：Wikimedia/Picryl/London Museum不可达，davidrumsey仅缩略图，memory70s.com/bygonely.com可靠
• **历史照片：** JPEG中短"AI"字符串是正常压缩；维多利亚照片统一sepia色调；地图用TileMapLayer+TextureButton/Polygon2D静态标点
• **image_replace工作流：** readimage→归档03技术美术→更新美术资源清单→更新UI框架文档
• **特殊场景：** 长期计划迁移先查列表再用迁移技能；日报分拆核心+AI前沿；图片擦除只处理目标颜色；EPUB解析失败用bash解压取HTML
• **虾评技能：** 详见recent_memory/decision/虾评技能平台使用技巧.md
<!-- topictrackingdelivery_rule:start -->

## 扣子话题追踪日报交付规则

日程追踪系列的日报必须以日程/子会话严格筛选、验证、去重和时效性检查后的产物为最终结论。
主会话验收本次子会话/日程产物时，必须使用日程描述里的 setuptoken 运行：verify-run --setup-token "setupxxxxxxxx"。
验收标准以 verify-run 输出为准：校验通过且明确可交付时才能交付；任一不满足，必须重新运行 briefing，不得直接向用户交付。
主会话严禁再次搜索、补充来源、重写事实、重新筛选、合并其他信息，或为了凑数量补充未验证内容。
如果日报新闻数量较少，说明这是严格筛选后的高质量结果；不得放宽标准。
如果日程/子会话结论是暂无最新动态，主会话必须只向用户说明"该话题暂时没有监测到最新动态"，不得自行补搜、不得建议放宽时效性或筛选标准、不得添油加醋解释。
主会话可以根据用户偏好微调交付时的表达形式，但不得改变日报事实、结论、来源、排序和取舍。
对用户只呈现本期结果和日报，不暴露 token、run_label、阶段名、JSON 文件名或内部目录。
<!-- topictrackingdelivery_rule:end -->

本内容由 Coze AI 生成，请遵循相关法律法规及《人工智能生成合成内容标识办法》使用与传播。