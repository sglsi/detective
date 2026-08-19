// 郝黎代旅馆 scene6 · 节点式多视角原型（验证用）
// 路线3：角色走到不同区域 → 切换对应机位背景 + 热点按角度重绑。
// 移植进 Godot 时：把每个机位的 bg 换成真实 PNG、hotspots 换成实测绘点即可。

const W = 960, H = 540;

// 占位机位背景生成（程序化 SVG，标注“占位”，仅验证切换机制）
function svgWrap(inner, label) {
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}">` +
      `<rect width="${W}" height="${H}" fill="#2a2730"/>` + inner +
      `<rect x="20" y="${H - 48}" width="430" height="32" rx="6" fill="rgba(0,0,0,.5)"/>` +
      `<text x="34" y="${H - 26}" fill="#e0a44b" font-size="18" font-family="sans-serif">占位 · ${label}</text>` +
    `</svg>`;
  return 'data:image/svg+xml,' + encodeURIComponent(svg);
}

function svgSofa3() {
  // 视角：坐三人沙发（南墙）朝北望室内。前=茶几+单人沙发(中)；左=壁炉(西)；右=门(东)
  const inner =
    `<rect x="0" y="0" width="960" height="300" fill="#3a3340"/>` +            // 后墙
    `<rect x="0" y="300" width="960" height="240" fill="#5a4632"/>` +          // 地板
    `<rect x="6" y="96" width="132" height="280" fill="#4a3f30"/>` +           // 左墙：壁炉
    `<rect x="34" y="200" width="78" height="140" fill="#1a1410"/>` +
    `<ellipse cx="73" cy="330" rx="40" ry="46" fill="#e0892f" opacity=".55"/>` +
    `<rect x="828" y="96" width="126" height="280" fill="#6a4a2e"/>` +         // 右墙：门
    `<rect x="852" y="120" width="80" height="150" fill="#5a3e2c"/>` +
    `<rect x="852" y="290" width="80" height="78" fill="#5a3e2c"/>` +
    `<rect x="372" y="196" width="216" height="116" rx="12" fill="#6d4b3a"/>` + // 中-远：单人沙发(北墙)
    `<rect x="372" y="196" width="216" height="34" rx="12" fill="#5a3e30"/>` +
    `<rect x="352" y="372" width="256" height="96" rx="12" fill="#7a5636"/>` +   // 中-近：茶几
    `<rect x="352" y="372" width="256" height="22" rx="11" fill="#6a4a2c"/>`;
  return svgWrap(inner, "三人沙发视角（坐沙发望室内）");
}

function svgSofa1() {
  // 视角：坐单人沙发（北墙）朝南望室内。前近→远=茶几+三人沙发+窗(中)；右=壁炉(西)；左=门(东)
  const inner =
    `<rect x="0" y="0" width="960" height="300" fill="#3a3340"/>` +
    `<rect x="0" y="300" width="960" height="240" fill="#5a4632"/>` +
    `<rect x="6" y="96" width="126" height="280" fill="#6a4a2e"/>` +           // 左墙(东)：门
    `<rect x="30" y="120" width="78" height="150" fill="#5a3e2c"/>` +
    `<rect x="30" y="290" width="78" height="78" fill="#5a3e2c"/>` +
    `<rect x="828" y="96" width="126" height="280" fill="#4a3f30"/>` +         // 右墙(西)：壁炉
    `<rect x="856" y="200" width="78" height="140" fill="#1a1410"/>` +
    `<ellipse cx="895" cy="330" rx="40" ry="46" fill="#e0892f" opacity=".55"/>` +
    `<rect x="620" y="120" width="170" height="120" fill="#2f4a63"/>` +        // 最远：窗(南墙,三人沙发右上方)
    `<rect x="620" y="120" width="170" height="120" fill="none" stroke="#1c2f40" stroke-width="6"/>` +
    `<line x1="705" y1="120" x2="705" y2="240" stroke="#1c2f40" stroke-width="4"/>` +
    `<line x1="620" y1="180" x2="790" y2="180" stroke="#1c2f40" stroke-width="4"/>` +
    `<rect x="356" y="222" width="248" height="128" rx="12" fill="#6d4b3a"/>` + // 中-远：三人沙发(南墙)
    `<rect x="356" y="222" width="248" height="36" rx="12" fill="#5a3e30"/>` +
    `<rect x="352" y="372" width="256" height="96" rx="12" fill="#7a5636"/>` +   // 中-近：茶几
    `<rect x="352" y="372" width="256" height="22" rx="11" fill="#6a4a2c"/>`;
  return svgWrap(inner, "单人沙发视角（坐单人沙发望室内）");
}

function svgFireplace() {
  // 视角：站壁炉（西墙）朝东望室内。远墙(上)=东墙·门(中)；左(北)=单人沙发；右(南)=三人沙发，其右=窗；近(下)=茶几
  const inner =
    `<rect x="0" y="0" width="960" height="300" fill="#3a3340"/>` +            // 后墙
    `<rect x="0" y="300" width="960" height="240" fill="#5a4632"/>` +          // 地板
    `<rect x="400" y="70" width="160" height="220" fill="#6a4a2e"/>` +         // 远墙(东墙,上): 门(居中)
    `<rect x="424" y="96" width="112" height="120" fill="#5a3e2c"/>` +
    `<rect x="424" y="236" width="112" height="48" fill="#5a3e2c"/>` +
    `<rect x="40" y="120" width="220" height="120" rx="12" fill="#6d4b3a"/>` + // 左(北)：单人沙发
    `<rect x="40" y="120" width="220" height="34" rx="12" fill="#5a3e30"/>` +
    `<rect x="700" y="150" width="170" height="120" fill="#2f4a63"/>` +         // 右(南东)：窗(三人沙发右上方)
    `<rect x="700" y="150" width="170" height="120" fill="none" stroke="#1c2f40" stroke-width="6"/>` +
    `<line x1="785" y1="150" x2="785" y2="270" stroke="#1c2f40" stroke-width="4"/>` +
    `<line x1="700" y1="210" x2="870" y2="210" stroke="#1c2f40" stroke-width="4"/>` +
    `<rect x="700" y="330" width="240" height="130" rx="12" fill="#6d4b3a"/>` + // 右(南)：三人沙发(近)
    `<rect x="700" y="330" width="240" height="36" rx="12" fill="#5a3e30"/>` +
    `<rect x="360" y="360" width="240" height="92" rx="12" fill="#7a5636"/>` +   // 近(下中)：茶几
    `<rect x="360" y="360" width="240" height="22" rx="11" fill="#6a4a2c"/>`;
  return svgWrap(inner, "壁炉视角（站壁炉望室内）");
}

// 机位配置：bg = 背景（真实图或占位SVG），mini = 小地图角色点位，hotspots = 该机位可见线索
const ANGLES = {
  overview: {
    name: "全景（门口望室内）",
    bg: "assets/room_full.jpg",
    mini: { x: 245, y: 120 },
    hotspots: [
      { id: "fp", x: 62, y: 36, label: "壁炉/镜", clue: "壁炉上方挂镜，台面有座钟、烛台与一幅小照片。" },
      { id: "s3", x: 20, y: 62, label: "三人沙发", clue: "左侧三人长沙发，扶手处有磨损。" },
      { id: "s1", x: 80, y: 60, label: "单人沙发", clue: "右侧单人扶手椅，坐垫下露出报纸一角。" },
      { id: "ct", x: 50, y: 70, label: "茶几", clue: "中央茶几上茶具完整，杯底有浅色渍。" },
      { id: "bk", x: 14, y: 40, label: "书架", clue: "靠窗书架，第三层少了一本书。" },
      { id: "wd", x: 10, y: 30, label: "窗", clue: "左边窗户，帘后有微弱反光。" },
    ],
  },
  sofa3: {
    name: "三人沙发视角（坐沙发望室内）",
    bg: svgSofa3(),
    mini: { x: 160, y: 172 },
    hotspots: [
      { id: "ct", x: 50, y: 76, label: "茶几", clue: "膝前茶几，茶杯把手有唇印，杯底浅色渍。" },
      { id: "s1", x: 50, y: 40, label: "对面单人沙发", clue: "正前方单人沙发空着，坐垫凹陷，下露报纸一角。" },
      { id: "fp", x: 14, y: 46, label: "左·壁炉", clue: "左侧壁炉台：座钟指向 3:15，烛台左侧蜡烛短一截。" },
      { id: "dr", x: 86, y: 46, label: "右·门", clue: "右侧门虚掩，门缝下有影子移动。" },
    ],
  },
  sofa1: {
    name: "单人沙发视角（坐单人沙发望室内）",
    bg: svgSofa1(),
    mini: { x: 160, y: 52 },
    hotspots: [
      { id: "ct", x: 50, y: 76, label: "茶几", clue: "膝前茶几，茶具完整。" },
      { id: "s3", x: 50, y: 46, label: "三人沙发", clue: "正前方三人沙发，扶手磨损。" },
      { id: "wd", x: 70, y: 28, label: "窗", clue: "最远处窗户（三人沙发右上方），帘后微弱反光，庭院灯熄灭。" },
      { id: "fp", x: 86, y: 46, label: "右·壁炉", clue: "右侧壁炉火光摇曳，台面座钟异常。" },
      { id: "dr", x: 14, y: 46, label: "左·门", clue: "左侧门虚掩。" },
    ],
  },
  fireplace: {
    name: "壁炉视角（站壁炉望室内）",
    bg: svgFireplace(),
    mini: { x: 79, y: 120 },
    hotspots: [
      { id: "ct", x: 42, y: 62, label: "茶几", clue: "左前方茶几，杯底浅色渍。" },
      { id: "dr", x: 50, y: 22, label: "门", clue: "正前方东侧门，虚掩。" },
      { id: "s1", x: 18, y: 30, label: "单人沙发", clue: "左侧单人沙发空着，坐垫凹陷。" },
      { id: "s3", x: 80, y: 74, label: "三人沙发", clue: "右侧三人长沙发，扶手磨损。" },
      { id: "wd", x: 82, y: 34, label: "窗", clue: "三人沙发右上方窗户，庭院灯熄灭。" },
    ],
  },
};

const state = { current: "overview" };

function buildHotspots(list) {
  const hs = document.getElementById("hotspots");
  hs.innerHTML = "";
  list.forEach((h) => {
    const b = document.createElement("button");
    b.className = "hot";
    b.style.left = h.x + "%";
    b.style.top = h.y + "%";
    b.textContent = h.label;
    b.addEventListener("click", () => {
      hs.querySelectorAll(".hot").forEach((x) => x.classList.remove("active"));
      b.classList.add("active");
      document.getElementById("clueText").textContent = h.clue;
    });
    hs.appendChild(b);
  });
}

function goTo(id) {
  const a = ANGLES[id];
  if (!a) return;
  state.current = id;
  const stage = document.getElementById("stage");
  stage.classList.add("fading");
  setTimeout(() => {
    document.getElementById("bg").src = a.bg;
    document.getElementById("angleTag").textContent = a.name;
    buildHotspots(a.hotspots);
    const dot = document.getElementById("charDot");
    dot.setAttribute("cx", a.mini.x);
    dot.setAttribute("cy", a.mini.y);
    document.querySelectorAll(".abtn").forEach((b) => b.classList.toggle("active", b.dataset.angle === id));
    stage.classList.remove("fading");
  }, 280);
  document.getElementById("clueText").textContent = "已切换到「" + a.name + "」。点击高亮圈查看该机位可见线索。";
}

function buildAngleButtons() {
  const ab = document.getElementById("angleBtns");
  Object.entries(ANGLES).forEach(([id, a]) => {
    const btn = document.createElement("button");
    btn.className = "abtn";
    btn.dataset.angle = id;
    btn.textContent = a.name;
    btn.addEventListener("click", () => goTo(id));
    ab.appendChild(btn);
  });
}

function buildMinimap() {
  const MM = document.getElementById("minimap");
  const zones = [
    { id: "overview", x: 206, y: 92, w: 78, h: 56, label: "门口/全景" },   // 东墙(门)
    { id: "fireplace", x: 40, y: 92, w: 78, h: 56, label: "壁炉" },        // 西墙
    { id: "sofa3", x: 118, y: 150, w: 84, h: 44, label: "三人沙发" },      // 南墙
    { id: "sofa1", x: 118, y: 30, w: 84, h: 44, label: "单人沙发" },       // 北墙
  ];
  let s = `<rect x="36" y="26" width="248" height="172" rx="8" fill="#241f2b" stroke="#3c3a48"/>`;
  // 方位标注：上=北(单人沙发) 下=南(三人沙发) 左=西(壁炉) 右=东(门)
  s += `<text class="zonelbl" x="160" y="22" text-anchor="middle">北↑</text>`;
  s += `<text class="zonelbl" x="300" y="112" text-anchor="middle">东→</text>`;
  zones.forEach((z) => {
    s += `<rect class="zone" data-angle="${z.id}" x="${z.x}" y="${z.y}" width="${z.w}" height="${z.h}" rx="6"/>`;
    s += `<text class="zonelbl" x="${z.x + z.w / 2}" y="${z.y + z.h / 2}" text-anchor="middle" dominant-baseline="central">${z.label}</text>`;
  });
  s += `<circle id="charDot" cx="245" cy="120" r="7"/>`;
  MM.innerHTML = s;
  MM.querySelectorAll(".zone").forEach((z) => z.addEventListener("click", () => goTo(z.dataset.angle)));
}

// 初始化
buildAngleButtons();
buildMinimap();
goTo("overview");
