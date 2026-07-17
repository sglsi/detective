// 编辑器集成测试：读 → 保存（原样回写临时文件）→ 校验 → 复读一致 → 清理
// 使用临时文件名，避免污染真实场景资源；验证 Module 9 的 save 产物 Godot 可加载。
const BASE = 'http://localhost:3000';
const SRC = 'scene_04_police.tres';
const TMP = '_ci_edit_test.tres';
const fs = require('fs');
const path = require('path');
const DIALOGUE_DIR = path.resolve(__dirname, '..', '..', 'godot_project', 'resources', 'dialogues');

async function main() {
  // 1. 读取真实场景作为数据源
  let r = await fetch(`${BASE}/api/editor/file?name=${SRC}`);
  let d = await r.json();
  if (!r.ok) throw new Error('读取失败: ' + JSON.stringify(d));
  if (!d.resource) throw new Error('resource 块缺失');
  console.log(`GET  ${SRC}: nodes=${d.nodes.length} scene_id=${d.resource.scene_id} speakers=${d.stats.speakers.length} step_entries=${d.stats.step_entries}`);

  // 2. 原样保存到【临时文件】（不污染真实场景）
  r = await fetch(`${BASE}/api/editor/file`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: TMP, nodes: d.nodes, meta: d.meta, extResources: d.extResources, resource: d.resource }),
  });
  let p = await r.json();
  if (!r.ok) throw new Error('保存失败: ' + JSON.stringify(p));
  console.log(`POST ${TMP}: ${JSON.stringify(p)}`);

  // 3. 校验结构
  r = await fetch(`${BASE}/api/editor/validate?name=${TMP}`);
  let v = await r.json();
  console.log(`VALIDATE ${TMP}: node_count=${v.node_count} dangling=${JSON.stringify(v.dangling_refs)} valid=${v.valid}`);
  if (!v.valid) throw new Error('校验失败');

  // 4. 复读一致性
  r = await fetch(`${BASE}/api/editor/file?name=${TMP}`);
  let d2 = await r.json();
  if (d2.nodes.length !== d.nodes.length) throw new Error(`保存后节点数变化: ${d2.nodes.length} vs ${d.nodes.length}`);
  if (d2.resource.scene_id !== d.resource.scene_id) throw new Error('保存后 scene_id 变化');

  // 5. 清理临时文件及其 .bak
  for (const f of [TMP, TMP + '.bak']) {
    const fp = path.join(DIALOGUE_DIR, f);
    if (fs.existsSync(fp)) fs.unlinkSync(fp);
  }
  console.log('EDITOR_INTEGRATION_OK (临时文件已清理)');
}

main().catch(e => { console.error('EDITOR_INTEGRATION_FAIL: ' + e.message); process.exit(1); });
