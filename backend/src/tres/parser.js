// 对话资源 .tres 解析器 / 序列化器（无损、Godot 兼容）
//
// 支持 DialogueResource 结构：
//   - [gd_resource] 头部（含 uid）
//   - [ext_resource] 两个脚本引用（DialogueResource / DialogueNodeResource）
//   - [sub_resource] 节点块（DialogueNodeResource）
//   - [resource] 资源块（DialogueResource 本体：元数据 + nodes = [SubResource(...)]）
//
// 解析:  parseTres(content) -> { meta, extResources, resource, nodes }
// 序列化: serializeTres(data) -> .tres 文本（可被 Godot 4 直接加载）
//
// 设计目标：对任意 DialogueResource .tres 做 parse -> serialize -> parse 往返，
// 字段与结构保持一致（blank-line 风格差异除外），保证 Godot 可加载。

// ============ 字段类型表 ============
// 已知字段类型映射（用于序列化时选择正确的字面量格式）。
// 未知字段在解析时保留原始文本，序列化时原样回写，确保无损。

const NODE_TYPES = {
  node_id: 'string',
  speaker: 'string',
  text: 'string',
  mood: 'string',
  trigger: 'string',
  next_nodes: 'string_array',
  choice_texts: 'string_array',
  difficulty_filter: 'int',
  verify_filter: 'string',
  probability: 'float',
  exploration_step: 'int',
  is_step_entry: 'bool',
  stage_direction: 'string',
  note_text: 'string',
  system_hint: 'string',
};

const RESOURCE_TYPES = {
  scene_id: 'string',
  scene_name: 'string',
  phase_id: 'string',
  phase_name: 'string',
  exploration_step: 'int',
  easy_start_node: 'string',
  normal_start_node: 'string',
  hard_start_node: 'string',
  knowledge_domains: 'string_array',
  milestone_name: 'string',
  score_observation: 'int',
  score_reasoning: 'int',
  score_insight: 'int',
  badge_check: 'string',
  completion_event: 'string',
};

// sub_resource 块内部字段的规范输出顺序（未知字段排在已知字段之后）
const NODE_FIELD_ORDER = [
  'node_id', 'speaker', 'text', 'mood', 'trigger', 'next_nodes',
  'choice_texts', 'difficulty_filter', 'verify_filter', 'probability',
  'exploration_step', 'is_step_entry', 'stage_direction', 'note_text', 'system_hint',
];

// resource 块内部字段的规范输出顺序（nodes 始终最后输出）
const RESOURCE_FIELD_ORDER = [
  'scene_id', 'scene_name', 'phase_id', 'phase_name', 'exploration_step',
  'easy_start_node', 'normal_start_node', 'hard_start_node',
  'knowledge_domains', 'milestone_name',
  'score_observation', 'score_reasoning', 'score_insight',
  'badge_check', 'completion_event',
];

// ============ 字面量工具 ============

function unquote(s) {
  s = s.trim();
  if (s.startsWith('"') && s.endsWith('"')) {
    return s.slice(1, -1)
      .replace(/\\"/g, '"')
      .replace(/\\n/g, '\n')
      .replace(/\\\\/g, '\\');
  }
  return s;
}

function quote(s) {
  return '"' + String(s)
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n') + '"';
}

// 解析数组：支持 ["a", "b"] 与 [SubResource("x"), SubResource("y")]
function parseArray(raw) {
  raw = raw.trim();
  if (!raw.startsWith('[')) return [];
  const inner = raw.slice(1, raw.lastIndexOf(']'));
  if (!inner.trim()) return [];
  const items = [];
  let cur = '';
  let depth = 0;
  let inStr = false;
  for (let i = 0; i < inner.length; i++) {
    const ch = inner[i];
    if (ch === '"') inStr = !inStr;
    if (!inStr) {
      if (ch === '(') depth++;
      else if (ch === ')') depth--;
      else if (ch === ',' && depth === 0) {
        items.push(cur.trim());
        cur = '';
        continue;
      }
    }
    cur += ch;
  }
  if (cur.trim()) items.push(cur.trim());
  return items.map(it => {
    // SubResource("x") | ExtResource("x") | "string"
    const sub = it.match(/^SubResource\("(.+?)"\)$/);
    if (sub) return { __sub: sub[1] };
    const ext = it.match(/^ExtResource\("(.+?)"\)$/);
    if (ext) return { __ext: ext[1] };
    return unquote(it);
  });
}

function serializeArray(arr) {
  return '[' + arr.map(v => {
    if (v && typeof v === 'object') {
      if (v.__sub) return `SubResource("${v.__sub}")`;
      if (v.__ext) return `ExtResource("${v.__ext}")`;
    }
    return quote(v);
  }).join(', ') + ']';
}

// 仅用于字符串数组的序列化（不含 SubResource 引用）
function serializeStringArray(arr) {
  return '[' + (arr || []).map(quote).join(', ') + ']';
}

// 根据已知类型序列化单个值
function serializeTyped(key, val, typeMap) {
  const type = typeMap[key];
  switch (type) {
    case 'string': return quote(val);
    case 'string_array': return serializeStringArray(val);
    case 'int': return String(Math.trunc(Number(val) || 0));
    case 'float':
      const n = Number(val);
      return Number.isFinite(n) && !Number.isInteger(n) ? String(n) : (Number.isFinite(n) ? n.toFixed(1) : '0.0');
    case 'bool': return val ? 'true' : 'false';
    default:
      // 未知字段：若已是字符串则原样（去掉可能的引号包装由调用方决定），否则按字符串
      return typeof val === 'string' ? val : quote(val);
  }
}

// ============ 块解析 ============
// 解析 [sub_resource] 或 [resource] 内部字段（不含头部方括号行）。
// 返回 { __script, _order?, ...fields }，所有字段使用 JS 原生类型。
function parseBlockFields(block) {
  const obj = { __script: null };
  const lines = block.split('\n');
  for (const line of lines) {
    const idx = line.indexOf('=');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const raw = line.slice(idx + 1).trim();
    if (key === 'script') {
      const m = raw.match(/ExtResource\("(.+?)"\)/);
      obj.__script = m ? m[1] : raw;
      continue;
    }
    obj[key] = parseValue(raw, key);
  }
  return obj;
}

// 仅依据文本推断类型解析（不依赖类型表，保证解析无损）
function parseValue(raw, keyHint) {
  raw = raw.trim();
  if (raw.startsWith('"')) return unquote(raw);
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  // SubResource / ExtResource 引用（通常出现在数组中，单独出现时亦处理）
  const sub = raw.match(/^SubResource\("(.+?)"\)$/);
  if (sub) return { __sub: sub[1] };
  const ext = raw.match(/^ExtResource\("(.+?)"\)$/);
  if (ext) return { __ext: ext[1] };
  if (raw.startsWith('[')) return parseArray(raw);
  // 数字（int 或 float）
  if (/^-?\d+$/.test(raw)) return parseInt(raw, 10);
  if (/^-?\d*\.\d+$/.test(raw)) return parseFloat(raw);
  // 其余原样保留
  return raw;
}

function parseTres(content) {
  const lines = content.split('\n');
  const meta = {};
  const extResources = [];
  let resource = null;
  const nodes = [];
  let curBlock = null;
  let curBlockType = null; // 'sub_resource' | 'resource' | null

  for (const line of lines) {
    const headerMatch = line.match(/^\[(.+?)\]/);
    if (headerMatch) {
      // 结束上一个块
      if (curBlock && curBlockType === 'sub_resource') {
        nodes.push(parseBlockFields(curBlock));
      } else if (curBlock && curBlockType === 'resource') {
        resource = parseBlockFields(curBlock);
      }
      const head = headerMatch[1];
      if (head.startsWith('gd_resource')) {
        const m = head.match(/uid="(.+?)"/);
        if (m) meta.uid = m[1];
        meta.header = head;
        curBlock = null;
        curBlockType = null;
      } else if (head.startsWith('ext_resource')) {
        const idm = head.match(/id="(.+?)"/);
        const pathm = head.match(/path="(.+?)"/);
        extResources.push({ id: idm ? idm[1] : '', path: pathm ? pathm[1] : '' });
        curBlock = null;
        curBlockType = null;
      } else if (head.startsWith('sub_resource')) {
        curBlock = '';
        curBlockType = 'sub_resource';
      } else if (head.startsWith('resource')) {
        curBlock = '';
        curBlockType = 'resource';
      } else {
        curBlock = null;
        curBlockType = null;
      }
      continue;
    }
    if (curBlock !== null) {
      curBlock += line + '\n';
    }
  }
  // 最后一个块
  if (curBlock && curBlockType === 'sub_resource') {
    const parsed = parseBlockFields(curBlock);
    nodes.push(parsed);
  } else if (curBlock && curBlockType === 'resource') {
    resource = parseBlockFields(curBlock);
  }

  // 回填 sub_resource id（从头部捕获）
  // 注意：上面循环里 curBlock._pendingId 在重新赋值为 '' 时丢失，
  // 因此下面单独扫描一遍头部以正确绑定 id。
  const idStack = [];
  for (const line of lines) {
    const sm = line.match(/^\[sub_resource[^\]]*id="(.+?)"\]/);
    if (sm) idStack.push(sm[1]);
  }
  nodes.forEach((n, i) => { n.id = idStack[i] || `node_${i}`; });

  // 归一化：移除内部标记 __script（序列化时单独处理），
  // 但保留以便知道使用哪个 ext_resource。
  const cleanNodes = nodes.map(n => {
    const o = {};
    for (const k of Object.keys(n)) {
      if (k === '__script') continue;
      o[k] = n[k];
    }
    return o;
  });

  // resource 块归一化（保留 __script 标记）
  let cleanResource = null;
  if (resource) {
    cleanResource = {};
    for (const k of Object.keys(resource)) {
      if (k === '__script') continue;
      cleanResource[k] = resource[k];
    }
  }

  return { meta, extResources, resource: cleanResource, nodes: cleanNodes };
}

// ============ 序列化 ============

function serializeTres(data) {
  const { meta, extResources, resource, nodes } = data;
  const out = [];

  // 头部
  const nodeCount = (nodes || []).length;
  const uid = (meta && meta.uid) || 'uid://c00000000000';
  out.push(`[gd_resource type="Resource" script_class="DialogueResource" load_steps=${nodeCount + 2} format=3 uid="${uid}"]`);
  out.push('');

  // ext_resources（固定两个脚本引用）
  out.push(`[ext_resource type="Script" path="res://resources/dialogues/dialogue_resource.gd" id="1_resource"]`);
  out.push(`[ext_resource type="Script" path="res://resources/dialogues/dialogue_node_resource.gd" id="2_node"]`);
  out.push('');

  // sub_resources
  (nodes || []).forEach((node, i) => {
    const id = node.id || `node_${i}`;
    out.push(`[sub_resource type="Resource" id="${id}"]`);
    out.push('script = ExtResource("2_node")');
    const known = NODE_FIELD_ORDER.filter(f => node[f] !== undefined);
    const knownSet = new Set(known);
    const extras = Object.keys(node).filter(k => k !== 'id' && !knownSet.has(k));
    const ordered = [...known, ...extras.sort()];
    for (const f of ordered) {
      out.push(`${f} = ${serializeTyped(f, node[f], NODE_TYPES)}`);
    }
    out.push('');
  });

  // [resource] 块
  out.push('[resource]');
  out.push('script = ExtResource("1_resource")');
  if (resource) {
    const known = RESOURCE_FIELD_ORDER.filter(f => resource[f] !== undefined && f !== 'nodes');
    const knownSet = new Set(known);
    const extras = Object.keys(resource).filter(k => k !== 'nodes' && !knownSet.has(k));
    const ordered = [...known, ...extras.sort()];
    for (const f of ordered) {
      out.push(`${f} = ${serializeTyped(f, resource[f], RESOURCE_TYPES)}`);
    }
  }
  // nodes 引用数组（始终最后，保证结构正确）
  const nodeRefs = (nodes || []).map((n, i) => `SubResource("${n.id || `node_${i}`}")`);
  out.push(`nodes = [${nodeRefs.join(', ')}]`);

  return out.join('\n') + '\n';
}

module.exports = { parseTres, serializeTres, NODE_TYPES, RESOURCE_TYPES, NODE_FIELD_ORDER, RESOURCE_FIELD_ORDER };
