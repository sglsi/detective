// .tres 往返（parse -> serialize -> parse）一致性校验
// 验证 serializeTres 输出与 Godot 加载所需的字段/结构一致。
const fs = require('fs');
const path = require('path');
const { parseTres, serializeTres } = require('../src/tres/parser');

const DIR = path.resolve(__dirname, '..', '..', 'godot_project', 'resources', 'dialogues');

function normalizeText(s) { return String(s == null ? '' : s); }

function compareNodes(a, b) {
  if (a.length !== b.length) return `节点数不一致: ${a.length} vs ${b.length}`;
  for (let i = 0; i < a.length; i++) {
    const na = a[i], nb = b[i];
    if (na.id !== nb.id) return `节点[${i}] id 不一致: ${na.id} vs ${nb.id}`;
    if (normalizeText(na.node_id) !== normalizeText(nb.node_id)) return `节点 ${na.id} node_id 不一致`;
    if (normalizeText(na.text) !== normalizeText(nb.text)) return `节点 ${na.id} text 不一致`;
    if (normalizeText(na.speaker) !== normalizeText(nb.speaker)) return `节点 ${na.id} speaker 不一致`;
    // next_nodes 数组
    const aa = (na.next_nodes || []).map(String);
    const bb = (nb.next_nodes || []).map(String);
    if (JSON.stringify(aa) !== JSON.stringify(bb)) return `节点 ${na.id} next_nodes 不一致: ${JSON.stringify(aa)} vs ${JSON.stringify(bb)}`;
    if (Number(na.difficulty_filter) !== Number(nb.difficulty_filter)) return `节点 ${na.id} difficulty_filter 不一致`;
    if (normalizeText(na.verify_filter) !== normalizeText(nb.verify_filter)) return `节点 ${na.id} verify_filter 不一致`;
    if (Number(na.exploration_step) !== Number(nb.exploration_step)) return `节点 ${na.id} exploration_step 不一致`;
    if (Boolean(na.is_step_entry) !== Boolean(nb.is_step_entry)) return `节点 ${na.id} is_step_entry 不一致`;
  }
  return null;
}

function compareResource(a, b) {
  if (!a || !b) return 'resource 缺失';
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  // nodes 数组不参与逐项比较（序列化时按节点顺序重建，引用一致即可）
  const ignore = new Set(['nodes']);
  for (const k of keys) {
    if (ignore.has(k)) continue;
    const va = a[k], vb = b[k];
    if (Array.isArray(va) || Array.isArray(vb)) {
      if (JSON.stringify((va || []).map(String)) !== JSON.stringify((vb || []).map(String)))
        return `resource.${k} 不一致: ${JSON.stringify(va)} vs ${JSON.stringify(vb)}`;
    } else if (normalizeText(va) !== normalizeText(vb)) {
      return `resource.${k} 不一致: ${normalizeText(va)} vs ${normalizeText(vb)}`;
    }
  }
  return null;
}

let pass = 0, fail = 0;
const files = fs.readdirSync(DIR).filter(f => f.endsWith('.tres')).sort();

for (const f of files) {
  const full = path.join(DIR, f);
  const original = fs.readFileSync(full, 'utf-8');
  const p1 = parseTres(original);
  const s1 = serializeTres(p1);
  const p2 = parseTres(s1);

  const errNodes = compareNodes(p1.nodes, p2.nodes);
  const errRes = compareResource(p1.resource, p2.resource);

  // 检查序列化输出是否包含 [resource] 块与 nodes 引用
  const hasResourceBlock = /\[resource\]/.test(s1);
  const hasNodesRef = /nodes = \[SubResource\(/.test(s1);

  if (!errNodes && !errRes && hasResourceBlock && hasNodesRef) {
    pass++;
    console.log(`✅ ${f}  节点=${p1.nodes.length}  scene_id=${p1.resource?.scene_id || '-'}  [resource]=${hasResourceBlock} nodesRef=${hasNodesRef}`);
  } else {
    fail++;
    console.log(`❌ ${f}`);
    if (errNodes) console.log(`   节点: ${errNodes}`);
    if (errRes) console.log(`   资源: ${errRes}`);
    if (!hasResourceBlock) console.log(`   缺少 [resource] 块`);
    if (!hasNodesRef) console.log(`   缺少 nodes 引用`);
  }
}

console.log(`\n=== 往返一致性: ${pass} 通过 / ${fail} 失败 (共 ${files.length}) ===`);
process.exit(fail === 0 ? 0 : 1);
