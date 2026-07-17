// 对话树编辑器 API 路由
// 提供 .tres 对话资源的读取 / 解析 / 保存 / 校验能力，供 Web 编辑器使用。
const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { parseTres, serializeTres } = require('../tres/parser');

// Godot 项目中对话资源目录（相对于 backend 根的上一级）
const GODOT_ROOT = path.resolve(__dirname, '..', '..', '..', 'godot_project');
const DIALOGUE_DIR = path.join(GODOT_ROOT, 'resources', 'dialogues');

// 安全路径校验：防止目录穿越
function safeJoin(base, file) {
  const full = path.resolve(base, file);
  if (!full.startsWith(path.resolve(base))) {
    throw { status: 400, message: '非法文件路径' };
  }
  return full;
}

// GET /api/editor/files — 列出所有 .tres 对话文件
router.get('/files', (req, res) => {
  try {
    if (!fs.existsSync(DIALOGUE_DIR)) {
      return res.status(404).json({ error: '对话资源目录不存在', path: DIALOGUE_DIR });
    }
    const files = fs.readdirSync(DIALOGUE_DIR)
      .filter(f => f.endsWith('.tres'))
      .map(f => {
        const stat = fs.statSync(path.join(DIALOGUE_DIR, f));
        return { name: f, size: stat.size, mtime: stat.mtime.toISOString() };
      })
      .sort((a, b) => a.name.localeCompare(b.name));
    res.json({ files, dir: DIALOGUE_DIR });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/editor/file?name=scene_01_phase1_tutorial.tres — 读取并解析
router.get('/file', (req, res) => {
  try {
    const name = req.query.name;
    if (!name) return res.status(400).json({ error: '缺少 name 参数' });
    const full = safeJoin(DIALOGUE_DIR, name);
    if (!fs.existsSync(full)) return res.status(404).json({ error: '文件不存在' });
    const content = fs.readFileSync(full, 'utf-8');
    const data = parseTres(content);
    // 计算统计信息
    const stats = {
      node_count: data.nodes.length,
      speakers: [...new Set(data.nodes.map(n => n.speaker).filter(Boolean))],
      step_entries: data.nodes.filter(n => n.is_step_entry && n.exploration_step > 0).length,
      verify_branches: [...new Set(data.nodes.map(n => n.verify_filter).filter(Boolean))],
    };
    res.json({ name, ...data, stats });
  } catch (err) {
    if (err.status) return res.status(err.status).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// POST /api/editor/file — 保存（接收解析后的 JSON，序列化回 .tres）
// body: { name, nodes, meta, extResources, resource }
router.post('/file', (req, res) => {
  try {
    const { name, nodes, meta, extResources, resource } = req.body;
    if (!name) return res.status(400).json({ error: '缺少 name' });
    if (!Array.isArray(nodes)) return res.status(400).json({ error: 'nodes 应为数组' });
    const full = safeJoin(DIALOGUE_DIR, name);

    // 备份原文件
    let backupMade = false;
    if (fs.existsSync(full)) {
      const backup = full + `.bak.${Date.now()}`;
      fs.copyFileSync(full, backup);
      backupMade = true;
    }

    // 若前端未提供 resource 元数据，则从原文件回读以保留场景级信息
    let safeResource = resource;
    if (!safeResource && fs.existsSync(full)) {
      try { safeResource = parseTres(fs.readFileSync(full, 'utf-8')).resource || {}; }
      catch (_) { safeResource = {}; }
    }

    const content = serializeTres({
      meta: meta || {},
      extResources: extResources || [],
      nodes,
      resource: safeResource || {},
    });
    fs.writeFileSync(full, content, 'utf-8');

    res.json({ message: '已保存', name, node_count: nodes.length, backup: backupMade });
  } catch (err) {
    if (err.status) return res.status(err.status).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
});

// GET /api/editor/validate?name=xxx.tres — 结构校验（BFS 可达 + 悬空引用）
router.get('/validate', (req, res) => {
  try {
    const name = req.query.name;
    if (!name) return res.status(400).json({ error: '缺少 name' });
    const full = safeJoin(DIALOGUE_DIR, name);
    if (!fs.existsSync(full)) return res.status(404).json({ error: '文件不存在' });
    const content = fs.readFileSync(full, 'utf-8');
    const data = parseTres(content);

    const ids = {};
    const dangling = [];
    for (const n of data.nodes) ids[n.node_id] = n;
    for (const n of data.nodes) {
      for (const nx of (n.next_nodes || [])) {
        if (nx !== 'end' && !ids[nx]) dangling.push(`${n.node_id} -> ${nx}`);
      }
    }

    // BFS 从 difficulty=0 起点
    const start = data.nodes.find(n => n.difficulty_filter === 0);
    let reachable = true;
    if (start) {
      const visited = new Set();
      const queue = [start.node_id];
      while (queue.length) {
        const cur = queue.shift();
        if (cur === 'end') { reachable = true; break; }
        if (visited.has(cur) || !ids[cur]) { if (cur === 'end') break; continue; }
        visited.add(cur);
        for (const nx of (ids[cur].next_nodes || [])) queue.push(nx);
      }
      reachable = visited.has(start.node_id) && (queue.includes('end') || Array.from(visited).some(v => (ids[v]?.next_nodes || []).includes('end')));
    }

    res.json({
      name,
      node_count: data.nodes.length,
      dangling_refs: dangling,
      reachability_ok: dangling.length === 0,
      valid: dangling.length === 0,
    });
  } catch (err) {
    if (err.status) return res.status(err.status).json({ error: err.message });
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
