/**
 * 维多利亚伦敦探案 — 后端 API 集成测试
 *
 * 用法:
 *   node tests/api_test.js                    # 运行全部测试
 *   node tests/api_test.js --base=http://...  # 指定服务器地址
 *   node tests/api_test.js --verbose          # 详细输出
 *
 * 前提: 后端服务已启动 (npm start)
 */

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:3000';

// ============ 工具函数 ============

let passed = 0;
let failed = 0;
let verbose = process.argv.includes('--verbose');

function log(level, msg) {
  const prefix = { info: '  ℹ', pass: '  ✅', fail: '  ❌', header: '\n📌' }[level] || '  ';
  console.log(`${prefix} ${msg}`);
}

async function request(method, path, body = null, token = null, guestId = null) {
  const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (guestId) headers['X-Guest-ID'] = guestId;

  const opts = { method, headers };
  if (body && method !== 'GET') opts.body = JSON.stringify(body);

  const res = await fetch(`${BASE_URL}${path}`, opts);
  const data = await res.json().catch(() => ({ raw: 'not json' }));
  return { status: res.status, data };
}

async function test(name, fn) {
  try {
    await fn();
    passed++;
    log('pass', name);
  } catch (err) {
    failed++;
    log('fail', `${name} — ${err.message}`);
    if (verbose) console.error('    ', err);
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || '断言失败');
}

function assertEq(actual, expected, msg) {
  if (actual !== expected) throw new Error(msg || `期望 ${expected}，实际 ${actual}`);
}

function assertOk(status, msg) {
  if (status < 200 || status >= 300) throw new Error(msg || `HTTP ${status}`);
}

function assertErr(status, msg) {
  if (status < 400) throw new Error(msg || `期望错误状态码，实际 ${status}`);
}

// ============ 测试数据 ============

const TEST_USER = {
  email: `test_${Date.now()}@sherlock.com`,
  password: 'TestPass123!',
  username: `测试侦探_${Date.now()}`,
  phone: '+86-13800138000',
};

let authToken = null;
let userId = null;
let guestId = null;

// ============ 测试用例 ============

async function runTests() {
  console.log('='.repeat(55));
  console.log('  维多利亚伦敦探案 — API 集成测试');
  console.log('='.repeat(55));
  console.log(`  服务器: ${BASE_URL}`);
  console.log(`  时间: ${new Date().toISOString()}`);
  console.log('='.repeat(55));

  // ---- 1. 健康检查 ----
  log('header', '1. 健康检查 (Health Check)');

  await test('GET /api/health 返回 200', async () => {
    const { status, data } = await request('GET', '/api/health');
    assertOk(status, `健康检查失败: ${status}`);
    assertEq(data.status, 'ok', 'status 应为 ok');
  });

  await test('GET /api/health 包含端点列表', async () => {
    const { data } = await request('GET', '/api/health');
    const eps = data.endpoints;
    assert(typeof eps === 'object' && eps !== null, 'endpoints 应为对象');
    assert(Object.keys(eps).length >= 4, '至少应有4个端点');
  });

  // ---- 2. 游客会话 ----
  log('header', '2. 游客会话 (Guest Session)');

  await test('POST /api/auth/guest 创建游客会话', async () => {
    const { status, data } = await request('POST', '/api/auth/guest');
    assertOk(status, `游客会话失败: ${status}`);
    assert(data.guest_id, '应返回 guest_id');
    assert(data.expires_at, '应返回 expires_at');
    guestId = data.guest_id;
    log('info', `guest_id: ${guestId}`);
  });

  // ---- 3. 用户注册 ----
  log('header', '3. 用户注册 (Register)');

  await test('POST /api/auth/register 缺少参数返回 400', async () => {
    const { status } = await request('POST', '/api/auth/register', {});
    assertErr(status, '缺少参数应返回 400');
  });

  // 注意：本地模式下注册会成功（StorageAdapter 自动切换为 SQLite）
  await test('POST /api/auth/register 提交有效数据', async () => {
    const { status, data } = await request('POST', '/api/auth/register', TEST_USER);
    if (status === 201) {
      assert(data.user, '应返回 user 对象');
      assert(data.user.id, '应返回 user.id');
      userId = data.user.id;
      log('info', `注册成功: ${data.user.username} (${data.user.id})`);
    } else {
      throw new Error(`注册失败: ${status} ${JSON.stringify(data)}`);
    }
  });

  // ---- 4. 用户登录 ----
  log('header', '4. 用户登录 (Login)');

  await test('POST /api/auth/login 缺少参数返回 400', async () => {
    const { status } = await request('POST', '/api/auth/login', {});
    assertErr(status, '缺少参数应返回 400');
  });

  await test('POST /api/auth/login 错误密码返回 401', async () => {
    const { status } = await request('POST', '/api/auth/login', {
      email: TEST_USER.email,
      password: 'wrong_password',
    });
    assertEq(status, 401, '错误密码应返回 401');
  });

  await test('POST /api/auth/login 正确凭据返回 token', async () => {
    const { status, data } = await request('POST', '/api/auth/login', {
      email: TEST_USER.email,
      password: TEST_USER.password,
    });
    assertOk(status, `登录失败: ${status}`);

    // 本地模式下 token 由后端 JWT 签发；Supabase 模式下 token 来自 Supabase Auth
    if (!data.token) {
      throw new Error('应返回 token');
    }
    assert(data.user, '应返回 user 对象');

    // 如果是本地模式生成的 token，验证其可解析出 userId
    authToken = data.token;
    userId = data.user.id;
    log('info', `登录成功: ${data.user.username}`);
  });

  // ---- 5. 认证中间件 ----
  log('header', '5. 认证中间件 (Auth Middleware)');

  await test('无 token 访问受保护端点返回 401', async () => {
    const { status } = await request('GET', '/api/saves');
    assertEq(status, 401, '无 token 应返回 401');
  });

  await test('无效 token 访问受保护端点返回 401', async () => {
    const { status } = await request('GET', '/api/saves', null, 'invalid_token_here');
    assertEq(status, 401, '无效 token 应返回 401');
  });

  // ---- 6. 存档接口 ----
  log('header', '6. 存档接口 (Saves)');

  const testSave = {
    case_id: 'case_test_001',
    save_version: 1,
    scene_id: 'scene_tutorial',
    difficulty: 1,
    clue_count: 5,
    observation_score: 3,
    reasoning_score: 2,
    insight_score: 1,
    unlocked_locations: ['贝克街221B'],
    completed_milestones: ['tutorial_started'],
    dialogue_progress: { scene_01: 5 },
    clue_states: { clue_001: 'DISCOVERED' },
    game_time: 600,
    metadata: { version: '0.1.0', platform: 'test' },
  };

  await test('POST /api/saves 上传存档', async () => {
    if (!authToken) {
      log('info', '无 token，跳过存档上传测试');
      return;
    }
    const { status, data } = await request('POST', '/api/saves', testSave, authToken);
    assertOk(status);
    assert(data.save_id || data.message, '应返回 save_id 或 message');
  });

  await test('POST /api/saves 缺少 case_id 返回 400', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    const { status } = await request('POST', '/api/saves', { scene_id: 'test' }, authToken);
    assertErr(status);
  });

  await test('GET /api/saves 获取存档列表', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    const { status, data } = await request('GET', '/api/saves', null, authToken);
    assertOk(status);
    assert(Array.isArray(data.saves), 'saves 应为数组');
    assert(typeof data.count === 'number', 'count 应为数字');
  });

  await test('GET /api/saves/latest 获取最新存档', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    const { status, data } = await request('GET', '/api/saves/latest?case_id=case_test_001', null, authToken);
    // 可能 200（有存档）或 404（无存档），都是合理的
    assert([200, 404].includes(status), `状态码应为 200 或 404，实际 ${status}`);
  });

  // ---- 7. 案件进度接口 ----
  log('header', '7. 案件进度 (Progress)');

  await test('GET /api/progress/:caseId 获取案件进度', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    const { status, data } = await request('GET', '/api/progress/case_test_001', null, authToken);
    assertOk(status);
    assert(data.progress, '应返回 progress');
    assert(data.progress.case_id === 'case_test_001', 'case_id 应匹配');
  });

  await test('PUT /api/progress/:caseId 更新案件进度', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    const { status, data } = await request('PUT', '/api/progress/case_test_001', {
      status: 'in_progress',
      clues_found: 5,
      observation_stars: 3,
    }, authToken);
    assertOk(status);
    assert(data.progress || data.message, '应返回 progress 或 message');
  });

  await test('GET /api/progress 获取所有案件进度', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    const { status, data } = await request('GET', '/api/progress', null, authToken);
    assertOk(status);
    assert(Array.isArray(data.progress), 'progress 应为数组');
  });

  // ---- 7.5 离线队列 flush 模拟 ----
  // 模拟 Godot 客户端离线时累积的本地存档，恢复网络后批量 flush 到服务端
  log('header', '7.5 离线队列同步 (Offline Queue Flush)');

  await test('离线增量存档 flush — 覆盖最新存档', async () => {
    if (!authToken) {
      log('info', '无 token，跳过');
      return;
    }
    // 第一次保存（场景 1）
    const saveV1 = { ...testSave, scene_id: 'scene_01', clue_count: 3, game_time: 100 };
    const r1 = await request('POST', '/api/saves', saveV1, authToken);
    assertOk(r1.status);
    assert(r1.data.save_id, '应返回 save_id');

    // 离线期间玩家推进，本地累积新存档（场景 4）
    const saveV2 = { ...testSave, scene_id: 'scene_04', clue_count: 12, game_time: 800 };
    const r2 = await request('POST', '/api/saves', saveV2, authToken);
    assertOk(r2.status);
    assert(r2.data.save_id, 'flush 应返回 save_id');

    // 拉取最新存档，应反映离线期间的最新进度
    const { status, data } = await request('GET', '/api/saves/latest?case_id=case_test_001', null, authToken);
    assertOk(status);
    assert(data.save, '应返回 save');
    assertEq(data.save.scene_id, 'scene_04', '最新存档应反映离线推进后的场景');
    assertEq(data.save.clue_count, 12, '线索数应反映最新进度');
    log('info', `离线 flush 成功: scene=${data.save.scene_id}, clues=${data.save.clue_count}`);
  });

  // ---- 8. 404 处理 ----
  log('header', '8. 错误处理 (Error Handling)');

  await test('GET /api/nonexistent 返回 404', async () => {
    const { status, data } = await request('GET', '/api/nonexistent');
    assertEq(status, 404, '不存在的端点应返回 404');
    assert(data.error, '应返回错误信息');
  });

  // ---- 9. 速率限制 ----
  log('header', '9. 速率限制 (Rate Limiting)');

  await test('快速请求不应立即触发限流', async () => {
    const results = await Promise.all(
      Array.from({ length: 5 }, () => request('GET', '/api/health'))
    );
    const allOk = results.every(r => r.status === 200);
    assert(allOk, '5次请求不应触发限流');
  });

  // ---- 结果汇总 ----
  console.log('\n' + '='.repeat(55));
  console.log(`  测试完成: ${passed} 通过, ${failed} 失败, ${passed + failed} 总计`);
  console.log('='.repeat(55));

  if (failed > 0) {
    process.exit(1);
  }
}

// 检查服务器是否可达
async function checkServer() {
  try {
    await request('GET', '/api/health');
    return true;
  } catch (err) {
    console.error(`❌ 无法连接到服务器: ${BASE_URL}`);
    console.error('   请先启动后端服务: cd backend && npm start');
    return false;
  }
}

(async () => {
  const serverReady = await checkServer();
  if (!serverReady) {
    process.exit(1);
  }
  await runTests();
})();
