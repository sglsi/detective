// 生成所有 .tres 的序列化版本到 godot 项目目录（供 Godot 加载测试），文件名前缀 _ser_
const fs = require('fs');
const path = require('path');
const { parseTres, serializeTres } = require('../src/tres/parser');

const DIR = path.resolve(__dirname, '..', '..', 'godot_project', 'resources', 'dialogues');
const files = fs.readdirSync(DIR).filter(f => f.endsWith('.tres')).sort();
for (const f of files) {
  const original = fs.readFileSync(path.join(DIR, f), 'utf-8');
  const data = parseTres(original);
  const ser = serializeTres(data);
  fs.writeFileSync(path.join(DIR, '_ser_' + f), ser, 'utf-8');
}
console.log('已生成 ' + files.length + ' 个序列化测试文件 (前缀 _ser_)');
