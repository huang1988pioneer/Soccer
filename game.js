(() => {
  "use strict";

  const canvas = document.querySelector("#game-canvas");
  const ctx = canvas.getContext("2d");
  const mascot = new Image();
  mascot.src = "assets/maomao-mascot.png";
  const matchBackground = new Image();
  matchBackground.src = "assets/generated/match-stadium-background-v2.png";
  const generatedPlayers = {
    captain: new Image(),
    calico: new Image(),
    whitecat: new Image(),
    redcat: new Image(),
  };
  generatedPlayers.captain.src = "assets/generated/character-maid-captain-v1.png";
  generatedPlayers.calico.src = "assets/generated/character-calico-midfielder-v1.png";
  generatedPlayers.whitecat.src = "assets/generated/character-white-goalkeeper-v1.png";
  generatedPlayers.redcat.src = "assets/generated/character-red-rival-v1.png";
  const goalkeeperDive = new Image();
  goalkeeperDive.src = "assets/generated/goalkeeper-dive-v2.png";

  const ui = {
    menu: document.querySelector("#menu-screen"),
    match: document.querySelector("#match-screen"),
    start: document.querySelector("#start-button"),
    help: document.querySelector("#help-button"),
    guideStart: document.querySelector("#guide-start-button"),
    brand: document.querySelector("#brand-button"),
    pause: document.querySelector("#pause-button"),
    quit: document.querySelector("#quit-button"),
    matchTitle: document.querySelector("#match-title"),
    matchMode: document.querySelector(".match-clock small"),
    footerTip: document.querySelector(".game-footer-tip"),
    redTeamName: document.querySelector(".red-score b"),
    redTeamMeta: document.querySelector(".red-score small"),
    resume: document.querySelector("#resume-button"),
    pauseQuit: document.querySelector("#pause-quit-button"),
    goalContinue: document.querySelector("#goal-continue-button"),
    helpModal: document.querySelector("#help-modal"),
    pauseModal: document.querySelector("#pause-modal"),
    goalModal: document.querySelector("#goal-modal"),
    playerScore: document.querySelector("#player-score"),
    cpuScore: document.querySelector("#cpu-score"),
    matchTime: document.querySelector("#match-time"),
    skillBar: document.querySelector("#skill-bar"),
    skillValue: document.querySelector("#skill-value"),
    xpBar: document.querySelector("#xp-bar"),
    shots: document.querySelector("#shots-value"),
    passes: document.querySelector("#passes-value"),
    possession: document.querySelector("#possession-value"),
    combo: document.querySelector("#combo-value"),
    aimHint: document.querySelector("#aim-hint"),
    toast: document.querySelector("#toast"),
    toastText: document.querySelector("#toast-text"),
    joystick: document.querySelector("#joystick"),
    joystickKnob: document.querySelector("#joystick-knob"),
    goalTitle: document.querySelector("#goal-title"),
    goalSubtitle: document.querySelector("#goal-subtitle"),
    goalPlayerScore: document.querySelector("#goal-player-score"),
    goalCpuScore: document.querySelector("#goal-cpu-score"),
    captainName: document.querySelector(".captain-profile h3"),
    captainRole: document.querySelector(".captain-profile p"),
    captainPortrait: document.querySelector(".captain-portrait img"),
  };

  const WORLD = { width: 1280, height: 720, left: 48, right: 1232, top: 54, bottom: 666, goalTop: 258, goalBottom: 462 };
  const TEAM = { blue: "blue", red: "red" };
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const lerp = (a, b, t) => a + (b - a) * t;
  const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const normalize = (x, y) => {
    const length = Math.hypot(x, y);
    return length > 0.001 ? { x: x / length, y: y / length, length } : { x: 0, y: 0, length: 0 };
  };
  const random = (min, max) => min + Math.random() * (max - min);

  const state = {
    active: false,
    mode: "quick",
    selectedMode: "quick",
    selectedPlayerId: "blue-captain",
    paused: false,
    goalLock: false,
    finalMatch: false,
    playerScore: 0,
    cpuScore: 0,
    timeLeft: 120,
    skill: 42,
    shots: 0,
    passes: 0,
    possessionBlue: 50,
    blueTouches: 0,
    redTouches: 0,
    combo: 1,
    comboTimer: 0,
    lastFrame: 0,
    lastUiUpdate: 0,
    shootCharging: false,
    shootStartedAt: 0,
    dashTimer: 0,
    dashCooldown: 0,
    toastTimer: 0,
    penaltyRound: 0,
    penaltyGoal: false,
    penaltyAim: 0,
    penaltyKeeperTargetY: WORLD.height / 2,
    penaltyShotTimer: 0,
    penaltyShotDuration: .58,
    penaltyShotStart: { x: 930, y: WORLD.height / 2 },
    penaltyShotTarget: { x: WORLD.right + 18, y: WORLD.height / 2 },
    penaltyShotActive: false,
    moveTarget: { x: 0, y: 0 },
    moveTargetActive: false,
    joystick: { active: false, x: 0, y: 0, pointerId: null },
    keys: new Set(),
  };

  const players = [];
  const ball = {
    x: WORLD.width / 2,
    y: WORLD.height / 2,
    vx: 0,
    vy: 0,
    r: 14,
    ownerId: null,
    noClaimUntil: 0,
    lastTouch: TEAM.blue,
  };
  const particles = [];
  const crowd = Array.from({ length: 88 }, (_, index) => ({
    x: random(24, WORLD.width - 24),
    y: index % 2 ? random(17, 39) : random(WORLD.height - 39, WORLD.height - 17),
    r: random(2, 4),
    color: ["#ffe08b", "#8bdcff", "#ff9f9f", "#f5f7ff"][index % 4],
  }));

  function createPlayer(config) {
    return {
      ...config,
      x: config.x,
      y: config.y,
      vx: 0,
      vy: 0,
      facing: config.team === TEAM.blue ? 0 : Math.PI,
      radius: 25,
      baseSpeed: config.baseSpeed || 235,
      stamina: 100,
      dashCooldown: 0,
      aiThink: random(.2, .7),
      aiAction: 0,
      actionCooldown: random(.5, 1.6),
      pulse: random(0, Math.PI * 2),
      homeX: config.x,
      homeY: config.y,
    };
  }

  function buildTeams() {
    players.length = 0;
    players.push(
      createPlayer({ id: "blue-captain", team: TEAM.blue, name: "喵白白", number: 10, role: "前鋒", kind: "captain", portrait: "assets/generated/character-maid-captain-v1.png", x: 310, y: 360, baseSpeed: 265, controlled: state.selectedPlayerId === "blue-captain" }),
      createPlayer({ id: "blue-mid", team: TEAM.blue, name: "喵布布", number: 8, role: "中場", kind: "calico", portrait: "assets/generated/character-calico-midfielder-v1.png", x: 236, y: 235, baseSpeed: 224, controlled: state.selectedPlayerId === "blue-mid" }),
      createPlayer({ id: "blue-keeper", team: TEAM.blue, name: "喵小白", number: 1, role: "守門", kind: "whitecat", portrait: "assets/generated/character-white-goalkeeper-v1.png", x: 120, y: 360, baseSpeed: 190, controlled: state.selectedPlayerId === "blue-keeper" }),
      createPlayer({ id: "red-striker", team: TEAM.red, name: "紅啵啵", number: 9, role: "前鋒", kind: "redcat", x: 970, y: 360, baseSpeed: 218 }),
      createPlayer({ id: "red-mid", team: TEAM.red, name: "小栗子", number: 7, role: "中場", kind: "redcat", x: 1040, y: 235, baseSpeed: 205 }),
      createPlayer({ id: "red-keeper", team: TEAM.red, name: "守門喵", number: 1, role: "守門", kind: "redcat", x: 1160, y: 360, baseSpeed: 180 }),
    );
  }
  buildTeams();

  const getPlayer = (id) => players.find((player) => player.id === id) || null;
  const userPlayer = () => getPlayer(state.selectedPlayerId) || getPlayer("blue-captain");
  const teammates = (team) => players.filter((player) => player.team === team);
  const opponents = (team) => players.filter((player) => player.team !== team);

  function resetPositions(kickoff = true) {
    for (const player of players) {
      player.x = player.homeX;
      player.y = player.homeY;
      player.vx = 0;
      player.vy = 0;
      player.stamina = 100;
      player.dashCooldown = 0;
      player.facing = player.team === TEAM.blue ? 0 : Math.PI;
    }
    ball.x = WORLD.width / 2;
    ball.y = WORLD.height / 2;
    ball.vx = kickoff ? 0 : random(-40, 40);
    ball.vy = 0;
    ball.ownerId = null;
    ball.noClaimUntil = performance.now() + 550;
    state.dashTimer = 0;
    state.dashCooldown = 0;
    state.moveTarget = { x: 0, y: 0 };
    state.moveTargetActive = false;
  }

  function showScreen(screen) {
    const isMatch = screen === "match";
    ui.menu.hidden = isMatch;
    ui.match.hidden = !isMatch;
    ui.menu.classList.toggle("is-active", !isMatch);
    ui.match.classList.toggle("is-active", isMatch);
  }

  function preparePenaltyRound() {
    const shooter = userPlayer();
    const keeper = getPlayer("red-keeper");
    shooter.x = 884; shooter.y = WORLD.height / 2; shooter.vx = 0; shooter.vy = 0; shooter.facing = 0;
    keeper.x = 1158; keeper.y = WORLD.height / 2; keeper.vx = 0; keeper.vy = 0; keeper.facing = Math.PI;
    ball.x = 930; ball.y = WORLD.height / 2; ball.vx = 0; ball.vy = 0; ball.ownerId = shooter.id; ball.lastTouch = TEAM.blue;
    ball.noClaimUntil = performance.now() + 300;
    state.penaltyAim = 0;
    state.penaltyKeeperTargetY = WORLD.height / 2;
    state.penaltyShotTimer = 0;
    state.penaltyShotActive = false;
  }

  function configureModeUi() {
    const isPenalty = state.mode === "penalty";
    ui.match.classList.toggle("penalty-mode", isPenalty);
    if (ui.matchTitle) ui.matchTitle.textContent = isPenalty ? "點球挑戰 · 5 球制" : "快速賽 · 第 1 局";
    if (ui.matchMode) ui.matchMode.textContent = isPenalty ? "點球挑戰" : "快速賽";
    if (ui.redTeamName) ui.redTeamName.textContent = isPenalty ? "守門喵" : "紅隊";
    if (ui.redTeamMeta) ui.redTeamMeta.textContent = isPenalty ? "GOALKEEPER · AI" : "CPU · NOVICE";
    if (ui.aimHint) {
      ui.aimHint.textContent = isPenalty ? "W/S 或 A/D 瞄準　SPACE 射門" : "長按射門蓄力";
      ui.aimHint.classList.remove("is-hidden");
    }
    if (ui.footerTip) ui.footerTip.innerHTML = isPenalty
      ? "⌁ 點擊球門落點或 W/S 瞄準 · <b>SPACE</b> 出腳 · 5 球後結算"
      : "⌁ 點擊／拖曳球場移動 · <b>SPACE</b> 蓄力射門 · <b>E</b> 傳球 · <b>SHIFT</b> 衝刺";
  }

  function startMatch(mode = state.selectedMode) {
    state.mode = mode === "penalty" ? "penalty" : "quick";
    state.selectedMode = state.mode;
    players.filter((player) => player.team === TEAM.blue).forEach((player) => {
      player.controlled = player.id === state.selectedPlayerId;
    });
    state.active = true;
    state.paused = false;
    state.goalLock = false;
    state.finalMatch = false;
    state.playerScore = 0;
    state.cpuScore = 0;
    state.timeLeft = state.mode === "penalty" ? 35 : 120;
    state.skill = 42;
    state.shots = 0;
    state.passes = 0;
    state.possessionBlue = 50;
    state.blueTouches = 0;
    state.redTouches = 0;
    state.combo = 1;
    state.comboTimer = 0;
    state.shootCharging = false;
    state.penaltyRound = 0;
    state.penaltyGoal = false;
    state.penaltyAim = 0;
    state.penaltyKeeperTargetY = WORLD.height / 2;
    state.penaltyShotTimer = 0;
    state.penaltyShotActive = false;
    state.moveTarget = { x: 0, y: 0 };
    state.moveTargetActive = false;
    hideModal(ui.helpModal);
    hideModal(ui.pauseModal);
    hideModal(ui.goalModal);
    resetPositions(true);
    if (state.mode === "penalty") preparePenaltyRound();
    configureModeUi();
    updateCaptainCard(userPlayer());
    updateRosterSelection();
    showScreen("match");
    updateUi(true);
    showToast(state.mode === "penalty" ? "A / D 瞄準，SPACE 射門！" : "開球！靠近足球就能自動控球。", 2600);
    state.lastFrame = performance.now();
    requestAnimationFrame(loop);
  }

  function quitToMenu() {
    state.active = false;
    state.paused = false;
    state.goalLock = false;
    state.shootCharging = false;
    state.penaltyShotActive = false;
    state.mode = "quick";
    state.selectedMode = "quick";
    hideModal(ui.pauseModal);
    hideModal(ui.goalModal);
    showScreen("menu");
    ui.match.classList.remove("penalty-mode");
    ui.start.innerHTML = '<span class="button-icon">⚽</span> 開始 3v3 快速賽';
    state.moveTargetActive = false;
    document.querySelectorAll(".mode-card").forEach((item) => item.classList.toggle("selected", item.dataset.mode === "quick"));
    updateCaptainCard(userPlayer());
    updateRosterSelection();
  }

  function togglePause(force) {
    if (!state.active || state.goalLock) return;
    state.paused = typeof force === "boolean" ? force : !state.paused;
    if (state.paused) showModal(ui.pauseModal); else hideModal(ui.pauseModal);
    ui.pause.textContent = state.paused ? "▶ 繼續" : "Ⅱ 暫停";
  }

  function showModal(element) { element.hidden = false; }
  function hideModal(element) { element.hidden = true; }

  let toastTimeout;
  function showToast(message, duration = 1800) {
    ui.toastText.textContent = message;
    ui.toast.classList.add("is-visible");
    clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => ui.toast.classList.remove("is-visible"), duration);
  }

  function playerAbility(player) {
    if (!player) return "高速衝刺射門";
    if (player.id === "blue-mid") return "精準傳球與盤帶";
    if (player.id === "blue-keeper") return "穩定撲救與回防";
    return "高速衝刺射門";
  }

  function updateCaptainCard(player = userPlayer()) {
    if (!player) return;
    if (ui.captainName) ui.captainName.textContent = player.name;
    if (ui.captainRole) ui.captainRole.textContent = playerAbility(player);
    if (ui.captainPortrait && player.portrait) {
      ui.captainPortrait.src = player.portrait;
      ui.captainPortrait.alt = player.name;
    }
    document.querySelectorAll(".mini-player[data-player-id]").forEach((row) => {
      const selected = row.dataset.playerId === player.id;
      row.classList.toggle("active", selected);
      const role = row.querySelector("small");
      if (role) role.textContent = `${getPlayer(row.dataset.playerId)?.role || ""} · ${selected ? "1P" : "AI"}`;
    });
    const tip = document.querySelector(".tip-card p");
    if (tip) tip.innerHTML = `<b>小提醒</b><br />射門方向會跟著${player.name}面向改變，衝刺後接射門更容易突破守門員！`;
  }

  function updateRosterSelection() {
    document.querySelectorAll(".roster-item[data-player-id]").forEach((item) => {
      item.classList.toggle("selected", item.dataset.playerId === state.selectedPlayerId);
      item.setAttribute("aria-pressed", item.dataset.playerId === state.selectedPlayerId ? "true" : "false");
    });
  }

  function selectPlayer(playerId) {
    if (state.active) return;
    const selected = getPlayer(playerId);
    if (!selected || selected.team !== TEAM.blue) return;
    state.selectedPlayerId = selected.id;
    players.filter((player) => player.team === TEAM.blue).forEach((player) => {
      player.controlled = player.id === state.selectedPlayerId;
    });
    updateCaptainCard(selected);
    updateRosterSelection();
    showToast(`${selected.name} 已加入先發 · ${selected.role}`, 1300);
  }

  function setSkill(amount) {
    state.skill = clamp(state.skill + amount, 0, 100);
    updateUi();
  }

  function getInputVector() {
    let x = 0;
    let y = 0;
    if (state.keys.has("arrowleft") || state.keys.has("a")) x -= 1;
    if (state.keys.has("arrowright") || state.keys.has("d")) x += 1;
    if (state.keys.has("arrowup") || state.keys.has("w")) y -= 1;
    if (state.keys.has("arrowdown") || state.keys.has("s")) y += 1;
    if (state.joystick.active && state.joystick.x ** 2 + state.joystick.y ** 2 > .02) {
      x = state.joystick.x;
      y = state.joystick.y;
    }
    if (x || y) {
      state.moveTargetActive = false;
      return normalize(x, y);
    }
    if (state.moveTargetActive) {
      const player = userPlayer();
      const target = normalize(state.moveTarget.x - player.x, state.moveTarget.y - player.y);
      if (target.length <= 18) {
        state.moveTargetActive = false;
        return { x: 0, y: 0, length: 0 };
      }
      return target;
    }
    return normalize(x, y);
  }

  function setMoveTarget(point) {
    state.moveTarget = {
      x: clamp(point.x, WORLD.left + 24, WORLD.right - 24),
      y: clamp(point.y, WORLD.top + 24, WORLD.bottom - 24),
    };
    state.moveTargetActive = true;
  }

  function moveToward(player, targetX, targetY, dt, speedScale = 1) {
    const direction = normalize(targetX - player.x, targetY - player.y);
    const speed = player.baseSpeed * speedScale;
    player.vx = lerp(player.vx, direction.x * speed, clamp(dt * 8, 0, 1));
    player.vy = lerp(player.vy, direction.y * speed, clamp(dt * 8, 0, 1));
    if (direction.length > .1) player.facing = Math.atan2(direction.y, direction.x);
    player.x += player.vx * dt;
    player.y += player.vy * dt;
    keepPlayerOnPitch(player);
  }

  function keepPlayerOnPitch(player) {
    player.x = clamp(player.x, WORLD.left + 23, WORLD.right - 23);
    player.y = clamp(player.y, WORLD.top + 24, WORLD.bottom - 24);
  }

  function updateControlledPlayer(player, dt) {
    const input = getInputVector();
    const isDashing = state.dashTimer > 0;
    let speed = player.baseSpeed * (isDashing ? 1.82 : 1);
    if (!isDashing && input.length < .05) speed *= .15;
    if (isDashing) {
      player.stamina = clamp(player.stamina - dt * 34, 0, 100);
      if (player.stamina <= 0) state.dashTimer = 0;
    } else {
      player.stamina = clamp(player.stamina + dt * 12, 0, 100);
    }
    player.vx = lerp(player.vx, input.x * speed, clamp(dt * 13, 0, 1));
    player.vy = lerp(player.vy, input.y * speed, clamp(dt * 13, 0, 1));
    player.x += player.vx * dt;
    player.y += player.vy * dt;
    if (input.length > .08) player.facing = Math.atan2(input.y, input.x);
    keepPlayerOnPitch(player);
  }

  function updateTeammate(player, dt) {
    const owner = getPlayer(ball.ownerId);
    let tx = player.homeX;
    let ty = player.homeY;
    if (owner && owner.team === TEAM.blue) {
      if (player.role === "中場") { tx = clamp(owner.x + 85, WORLD.left + 90, WORLD.right - 120); ty = clamp(owner.y - 110, WORLD.top + 45, WORLD.bottom - 45); }
      else { tx = clamp(owner.x - 115, WORLD.left + 65, WORLD.right - 95); ty = clamp(owner.y + 100, WORLD.top + 50, WORLD.bottom - 45); }
    } else if (owner && owner.team === TEAM.red) {
      const pressure = distance(player, ball) < 240;
      if (pressure) { tx = ball.x - 40; ty = ball.y; }
    } else {
      tx = lerp(player.homeX, ball.x - 85, .15);
      ty = lerp(player.homeY, ball.y, .08);
    }
    moveToward(player, tx, ty, dt, .72);
  }

  function updateCpu(player, dt) {
    const owner = getPlayer(ball.ownerId);
    const nearestCpu = nearestPlayer(ball, TEAM.red);
    let tx = player.homeX;
    let ty = player.homeY;
    if (owner && owner.team === TEAM.red && owner.id === player.id) {
      tx = WORLD.left + 100;
      ty = clamp(lerp(player.y, WORLD.height / 2, .01), WORLD.top + 50, WORLD.bottom - 50);
      player.actionCooldown -= dt;
      if (player.actionCooldown <= 0 && player.x < 560) {
        cpuShoot(player);
        player.actionCooldown = random(1.6, 2.8);
      }
    } else if (!owner && nearestCpu && nearestCpu.id === player.id) {
      tx = ball.x; ty = ball.y;
    } else if (owner && owner.team === TEAM.blue) {
      const pressure = distance(player, owner) < 240 || player.role === "前鋒";
      if (pressure) { tx = owner.x + 20; ty = owner.y; }
      else { tx = player.homeX; ty = player.homeY; }
    } else {
      tx = lerp(player.homeX, ball.x + 110, .07);
      ty = lerp(player.homeY, ball.y, .06);
    }
    moveToward(player, tx, ty, dt, player.role === "守門" ? .64 : .78);
  }

  function nearestPlayer(point, team, includeKeeper = true) {
    const list = players.filter((player) => player.team === team && (includeKeeper || player.role !== "守門"));
    return list.sort((a, b) => distance(a, point) - distance(b, point))[0] || null;
  }

  function claimBall(player) {
    if (performance.now() < ball.noClaimUntil) return false;
    ball.ownerId = player.id;
    ball.lastTouch = player.team;
    if (player.team === TEAM.blue) state.blueTouches += 1; else state.redTouches += 1;
    player.pulse = 0;
    return true;
  }

  function autoPossession() {
    if (ball.ownerId || performance.now() < ball.noClaimUntil) return;
    const candidates = players
      .map((player) => ({ player, d: distance(player, ball) }))
      .filter((entry) => entry.d < 45)
      .sort((a, b) => a.d - b.d);
    if (candidates[0]) claimBall(candidates[0].player);
  }

  function releaseBall(vx, vy, sourceTeam = TEAM.blue) {
    ball.ownerId = null;
    ball.vx = vx;
    ball.vy = vy;
    ball.lastTouch = sourceTeam;
    ball.noClaimUntil = performance.now() + 170;
  }

  function updateBall(dt) {
    const owner = getPlayer(ball.ownerId);
    if (owner) {
      const offsetX = Math.cos(owner.facing) * 31;
      const offsetY = Math.sin(owner.facing) * 31;
      ball.x = owner.x + offsetX;
      ball.y = owner.y + offsetY;
      ball.vx = owner.vx;
      ball.vy = owner.vy;
      return;
    }
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    const drag = Math.pow(.085, dt);
    ball.vx *= drag;
    ball.vy *= drag;
    if (ball.y < WORLD.top + ball.r) { ball.y = WORLD.top + ball.r; ball.vy = Math.abs(ball.vy) * .72; }
    if (ball.y > WORLD.bottom - ball.r) { ball.y = WORLD.bottom - ball.r; ball.vy = -Math.abs(ball.vy) * .72; }
    const inGoalMouth = ball.y > WORLD.goalTop && ball.y < WORLD.goalBottom;
    if (inGoalMouth && ball.x < -ball.r) { scoreGoal(TEAM.red); return; }
    if (inGoalMouth && ball.x > WORLD.width + ball.r) { scoreGoal(TEAM.blue); return; }
    // Outside the goal mouth the touchline behaves like a soft wall. Inside the
    // mouth the ball is allowed to travel beyond the pitch until it crosses the net.
    if (ball.x < WORLD.left + ball.r && !inGoalMouth) { ball.x = WORLD.left + ball.r; ball.vx = Math.abs(ball.vx) * .72; }
    if (ball.x > WORLD.right - ball.r && !inGoalMouth) { ball.x = WORLD.right - ball.r; ball.vx = -Math.abs(ball.vx) * .72; }
    autoPossession();
  }

  function ensureUserPossession() {
    const player = userPlayer();
    if (ball.ownerId === player.id) return true;
    if (!ball.ownerId && distance(player, ball) < 68) return claimBall(player);
    return false;
  }

  function updatePenalty(dt) {
    const keeper = getPlayer("red-keeper");
    if (state.penaltyShotActive) {
      state.penaltyShotTimer = Math.max(0, state.penaltyShotTimer - dt);
      const progress = 1 - state.penaltyShotTimer / state.penaltyShotDuration;
      const eased = 1 - (1 - clamp(progress, 0, 1)) ** 1.35;
      ball.x = lerp(state.penaltyShotStart.x, state.penaltyShotTarget.x, eased);
      ball.y = lerp(state.penaltyShotStart.y, state.penaltyShotTarget.y, eased);
      keeper.y = lerp(keeper.y, state.penaltyKeeperTargetY, clamp(dt * 9, 0, 1));
      if (state.penaltyShotTimer <= 0) resolvePenaltyShot();
      return;
    }
    keeper.y = lerp(keeper.y, WORLD.height / 2 + Math.sin(performance.now() / 660) * 7, clamp(dt * 3, 0, 1));
    ball.x = 930; ball.y = WORLD.height / 2; ball.ownerId = userPlayer().id;
  }

  function penaltyShoot() {
    if (!state.active || state.mode !== "penalty" || state.paused || state.goalLock || state.penaltyShotActive) return;
    const aimY = clamp(WORLD.height / 2 + state.penaltyAim * 112, WORLD.goalTop + 18, WORLD.goalBottom - 18);
    const keeperSlots = [WORLD.goalTop + 38, WORLD.height / 2, WORLD.goalBottom - 38];
    state.penaltyKeeperTargetY = keeperSlots[Math.floor(Math.random() * keeperSlots.length)];
    state.penaltyGoal = Math.abs(aimY - state.penaltyKeeperTargetY) > 43;
    state.penaltyShotStart = { x: ball.x, y: ball.y };
    state.penaltyShotTarget = { x: WORLD.right + 18, y: aimY };
    state.penaltyShotTimer = state.penaltyShotDuration;
    state.penaltyShotActive = true;
    ball.ownerId = null;
    state.shots += 1;
    showToast("射門！看看能不能騙過守門員。", 1000);
  }

  function resolvePenaltyShot() {
    state.penaltyShotActive = false;
    state.penaltyRound += 1;
    if (state.penaltyGoal) {
      state.playerScore += 1;
      spawnGoalParticles(WORLD.right - 22, state.penaltyShotTarget.y, "#ffdf69");
      ui.goalTitle.textContent = "進球！";
      ui.goalSubtitle.textContent = "漂亮的點球，守門員被你騙過了！";
      showToast("命中！下一球繼續保持。", 1100);
    } else {
      state.cpuScore += 1;
      spawnKickParticles(WORLD.right - 72, state.penaltyKeeperTargetY, "#8fdcff", 16);
      ui.goalTitle.textContent = "撲救！";
      ui.goalSubtitle.textContent = "守門員猜中了方向，再試一次。";
      showToast("被守住了，調整瞄準再踢。", 1100);
    }
    state.finalMatch = state.penaltyRound >= 5;
    if (state.finalMatch) {
      ui.goalTitle.textContent = "點球結束！";
      ui.goalSubtitle.textContent = state.playerScore > state.cpuScore ? "喵咪隊勝利！" : state.playerScore === state.cpuScore ? "平局！" : "守門員拿下勝利！";
      ui.goalContinue.textContent = "返回主選單  →";
    } else {
      ui.goalContinue.textContent = "下一球  →";
    }
    ui.goalPlayerScore.textContent = String(state.playerScore);
    ui.goalCpuScore.textContent = String(state.cpuScore);
    state.goalLock = true;
    state.paused = true;
    updateUi(true);
    showModal(ui.goalModal);
  }

  function beginShoot() {
    if (!state.active || state.paused || state.goalLock || state.shootCharging) return;
    if (state.mode === "penalty") { penaltyShoot(); return; }
    if (!ensureUserPossession()) { showToast("靠近足球後才能射門！", 1200); return; }
    state.shootCharging = true;
    state.shootStartedAt = performance.now();
    ui.aimHint.textContent = "放開射門！力量正在累積";
    ui.aimHint.classList.remove("is-hidden");
  }

  function finishShoot() {
    if (state.mode === "penalty") { state.shootCharging = false; return; }
    if (!state.shootCharging) return;
    state.shootCharging = false;
    const player = userPlayer();
    if (!player || ball.ownerId !== player.id) return;
    const charge = clamp((performance.now() - state.shootStartedAt) / 1000, .18, 1);
    const direction = normalize(Math.cos(player.facing), Math.sin(player.facing));
    const speed = 490 + charge * 430;
    releaseBall(direction.x * speed, direction.y * speed, TEAM.blue);
    state.shots += 1;
    state.comboTimer = 4;
    setSkill(10 + charge * 7);
    spawnKickParticles(player.x + direction.x * 30, player.y + direction.y * 30, "#ffe17b", 8);
    showToast(charge > .82 ? "Perfect Timing！超強射門！" : "射門！把球送進球門！", 1300);
    ui.aimHint.textContent = "長按射門蓄力";
  }

  function passBall() {
    if (!state.active || state.paused || state.goalLock) return;
    const player = userPlayer();
    if (!ensureUserPossession()) { showToast("還沒拿到球，先靠近一點！", 1200); return; }
    const candidates = teammates(TEAM.blue).filter((mate) => mate.id !== player.id);
    const direction = { x: Math.cos(player.facing), y: Math.sin(player.facing) };
    candidates.sort((a, b) => {
      const score = (mate) => (mate.x - player.x) * direction.x + (mate.y - player.y) * direction.y - distance(mate, player) * .22;
      return score(b) - score(a);
    });
    const target = candidates[0];
    const aim = normalize(target.x - player.x, target.y - player.y);
    releaseBall(aim.x * 470, aim.y * 470, TEAM.blue);
    state.passes += 1;
    state.comboTimer = 4;
    setSkill(6);
    spawnKickParticles(player.x + aim.x * 28, player.y + aim.y * 28, "#78dfff", 5);
    showToast(`傳給 ${target.name}！`, 1000);
  }

  function dash() {
    if (!state.active || state.paused || state.goalLock) return;
    const player = userPlayer();
    if (player.stamina < 18 || state.dashCooldown > 0) { showToast("體力還沒恢復！", 900); return; }
    state.dashTimer = .27;
    state.dashCooldown = .72;
    player.stamina -= 15;
    spawnKickParticles(player.x, player.y + 17, "#6de6ff", 5);
  }

  function tackle() {
    if (!state.active || state.paused || state.goalLock) return;
    const player = userPlayer();
    const owner = getPlayer(ball.ownerId);
    if (owner && owner.team === TEAM.red && distance(player, owner) < 76) {
      ball.ownerId = player.id;
      ball.lastTouch = TEAM.blue;
      state.blueTouches += 1;
      setSkill(12);
      spawnKickParticles(player.x, player.y, "#9ce7ff", 10);
      showToast("漂亮搶球！", 1000);
      return;
    }
    if (!owner && distance(player, ball) < 82) {
      claimBall(player);
      setSkill(7);
      showToast("把球留下來！", 900);
      return;
    }
    state.dashTimer = Math.max(state.dashTimer, .16);
  }

  function useSkill() {
    if (!state.active || state.paused || state.goalLock) return;
    if (state.skill < 100) { showToast(`喵力值還差 ${Math.ceil(100 - state.skill)}%！`, 1100); return; }
    if (!ensureUserPossession()) { showToast("拿到球才能發動必殺技！", 1100); return; }
    const player = userPlayer();
    const direction = normalize(Math.cos(player.facing), Math.sin(player.facing));
    releaseBall(direction.x * 1050, direction.y * 1050, TEAM.blue);
    state.shots += 1;
    state.skill = 0;
    state.comboTimer = 7;
    spawnKickParticles(player.x + direction.x * 30, player.y + direction.y * 30, "#ffdc62", 22);
    showToast("海浪射門！必殺技發動！", 1800);
  }

  function cpuShoot(player) {
    const targetY = WORLD.height / 2 + random(-95, 95);
    const aim = normalize(WORLD.left - player.x, targetY - player.y);
    releaseBall(aim.x * random(430, 560), aim.y * random(430, 560), TEAM.red);
    spawnKickParticles(player.x + aim.x * 27, player.y + aim.y * 27, "#ff9e79", 6);
  }

  function scoreGoal(team) {
    if (state.goalLock || state.mode === "penalty") return;
    state.goalLock = true;
    state.paused = true;
    ball.ownerId = null;
    ball.vx = 0;
    ball.vy = 0;
    if (team === TEAM.blue) {
      state.playerScore += 1;
      state.combo = clamp(state.combo + 1, 1, 9);
      state.skill = clamp(state.skill + 30, 0, 100);
      spawnGoalParticles(WORLD.right - 22, WORLD.height / 2, "#ffdf69");
    } else {
      state.cpuScore += 1;
      state.combo = 1;
      spawnGoalParticles(WORLD.left + 22, WORLD.height / 2, "#ff8a77");
    }
    state.finalMatch = state.playerScore >= 3 || state.cpuScore >= 3 || state.timeLeft <= 0;
    ui.goalTitle.textContent = "GOAL!";
    ui.goalSubtitle.textContent = team === TEAM.blue ? "喵咪隊拿下一分！" : "紅隊突破了防線！";
    ui.goalPlayerScore.textContent = String(state.playerScore);
    ui.goalCpuScore.textContent = String(state.cpuScore);
    ui.goalContinue.textContent = state.finalMatch ? "查看比賽結果 →" : "繼續比賽 →";
    updateUi(true);
    showModal(ui.goalModal);
  }

  function finishMatchByTime() {
    if (state.goalLock || state.finalMatch || state.mode === "penalty") return;
    state.goalLock = true;
    state.paused = true;
    state.finalMatch = true;
    const won = state.playerScore > state.cpuScore;
    ui.goalTitle.textContent = "時間到！";
    ui.goalSubtitle.textContent = state.playerScore === state.cpuScore ? "平局！兩隊都踢得很精彩" : won ? "喵咪隊拿下勝利！" : "紅隊暫時領先，下次再來挑戰！";
    ui.goalPlayerScore.textContent = String(state.playerScore);
    ui.goalCpuScore.textContent = String(state.cpuScore);
    ui.goalContinue.textContent = "返回主選單 →";
    updateUi(true);
    showModal(ui.goalModal);
  }

  function continueAfterGoal() {
    if (state.finalMatch) { quitToMenu(); return; }
    hideModal(ui.goalModal);
    state.goalLock = false;
    state.paused = false;
    if (state.mode === "penalty") {
      preparePenaltyRound();
      showToast(`第 ${state.penaltyRound + 1} 球！W/S 或 A/D 瞄準後按 SPACE。`, 1500);
      return;
    }
    resetPositions(true);
    showToast("重新開球！這次換你進攻。", 1200);
  }

  function update(dt) {
    if (!state.active || state.paused || state.goalLock) return;
    if (state.mode === "penalty") {
      updatePenalty(dt);
      updateParticles(dt);
      if (performance.now() - state.lastUiUpdate > 90) updateUi();
      return;
    }
    state.timeLeft = Math.max(0, state.timeLeft - dt);
    if (state.timeLeft <= 0) { finishMatchByTime(); return; }
    state.dashTimer = Math.max(0, state.dashTimer - dt);
    state.dashCooldown = Math.max(0, state.dashCooldown - dt);
    state.comboTimer = Math.max(0, state.comboTimer - dt);
    if (state.comboTimer === 0) state.combo = 1;
    const player = userPlayer();
    updateControlledPlayer(player, dt);
    for (const teammate of players.filter((p) => p.team === TEAM.blue && !p.controlled)) updateTeammate(teammate, dt);
    for (const cpu of players.filter((p) => p.team === TEAM.red)) updateCpu(cpu, dt);
    resolvePlayerBumps();
    updateBall(dt);
    const totalTouches = state.blueTouches + state.redTouches;
    if (totalTouches > 0) state.possessionBlue = Math.round((state.blueTouches / totalTouches) * 100);
    updateParticles(dt);
    if (performance.now() - state.lastUiUpdate > 90) updateUi();
  }

  function resolvePlayerBumps() {
    for (let i = 0; i < players.length; i += 1) {
      for (let j = i + 1; j < players.length; j += 1) {
        const a = players[i]; const b = players[j];
        const dx = b.x - a.x; const dy = b.y - a.y;
        const d = Math.hypot(dx, dy) || .001;
        const min = a.radius + b.radius - 5;
        if (d < min) {
          const push = (min - d) / 2;
          const nx = dx / d; const ny = dy / d;
          a.x -= nx * push; a.y -= ny * push; b.x += nx * push; b.y += ny * push;
          keepPlayerOnPitch(a); keepPlayerOnPitch(b);
        }
      }
    }
    const owner = getPlayer(ball.ownerId);
    if (owner) {
      for (const opponent of opponents(owner.team)) {
        if (distance(owner, opponent) < 40 && opponent.team === TEAM.red && Math.random() < .012) {
          ball.ownerId = opponent.id;
          ball.lastTouch = opponent.team;
          state.redTouches += 1;
          showToast("被紅隊碰到了，快搶回來！", 900);
          break;
        }
      }
    }
  }

  function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i -= 1) {
      const particle = particles[i];
      particle.life -= dt;
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= Math.pow(.08, dt);
      particle.vy *= Math.pow(.08, dt);
      particle.size *= Math.pow(.4, dt);
      if (particle.life <= 0) particles.splice(i, 1);
    }
  }

  function spawnKickParticles(x, y, color, count) {
    for (let i = 0; i < count; i += 1) particles.push({ x, y, vx: random(-100, 100), vy: random(-100, 100), life: random(.3, .7), size: random(2, 5), color });
  }

  function spawnGoalParticles(x, y, color) {
    for (let i = 0; i < 64; i += 1) {
      const angle = random(-Math.PI, Math.PI);
      const speed = random(90, 440);
      particles.push({ x, y, vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, life: random(.8, 1.9), size: random(3, 8), color: i % 3 ? color : "#fff4bb" });
    }
  }

  function updateUi(force = false) {
    const now = performance.now();
    if (!force && now - state.lastUiUpdate < 70) return;
    state.lastUiUpdate = now;
    ui.playerScore.textContent = String(state.playerScore);
    ui.cpuScore.textContent = String(state.cpuScore);
    const seconds = Math.ceil(state.timeLeft);
    ui.matchTime.textContent = state.mode === "penalty"
      ? `${Math.min(state.penaltyRound + 1, 5)} / 5`
      : `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
    ui.skillBar.style.width = `${state.skill}%`;
    ui.skillValue.textContent = `${Math.round(state.skill)}%`;
    ui.xpBar.style.width = `${clamp(54 + state.playerScore * 8, 0, 100)}%`;
    ui.shots.textContent = String(state.shots);
    ui.passes.textContent = String(state.passes);
    ui.possession.textContent = `${state.possessionBlue}%`;
    ui.combo.textContent = `x${state.combo}`;
  }

  function loop(timestamp) {
    if (!state.active) { draw(); return; }
    const dt = clamp((timestamp - state.lastFrame) / 1000, 0, .04);
    state.lastFrame = timestamp;
    update(dt);
    draw();
    requestAnimationFrame(loop);
  }

  function resizeCanvas() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const targetWidth = Math.max(1, Math.round(rect.width * dpr));
    const targetHeight = Math.max(1, Math.round(rect.height * dpr));
    if (canvas.width !== targetWidth || canvas.height !== targetHeight) {
      canvas.width = targetWidth;
      canvas.height = targetHeight;
    }
  }

  function draw() {
    resizeCanvas();
    const scaleX = canvas.width / WORLD.width;
    const scaleY = canvas.height / WORLD.height;
    ctx.save();
    ctx.scale(scaleX, scaleY);
    drawStadium();
    drawPitch();
    drawGoals();
    if (state.mode === "penalty") drawPenaltyScene();
    else {
      drawAimGuide();
      for (const player of players.slice().sort((a, b) => a.y - b.y)) drawPlayer(player);
    }
    if (state.mode === "quick" && state.moveTargetActive) drawMoveTarget();
    drawBall();
    drawParticles();
    ctx.restore();
  }

  function drawPenaltyScene() {
    const shooter = userPlayer();
    const keeper = getPlayer("red-keeper");
    drawPlayer(shooter);
    if (state.penaltyShotActive && goalkeeperDive.complete && goalkeeperDive.naturalWidth > 0) drawGoalkeeperDive(keeper);
    else drawPlayer(keeper);
    const targetY = state.penaltyShotActive
      ? state.penaltyShotTarget.y
      : clamp(WORLD.height / 2 + state.penaltyAim * 112, WORLD.goalTop + 18, WORLD.goalBottom - 18);
    const targetX = WORLD.right + 18;
    if (!state.penaltyShotActive) {
      ctx.save();
      ctx.setLineDash([10, 9]); ctx.lineWidth = 4; ctx.strokeStyle = "rgba(255,223,115,.84)";
      ctx.beginPath(); ctx.moveTo(ball.x, ball.y); ctx.lineTo(targetX, targetY); ctx.stroke();
      ctx.setLineDash([]); ctx.fillStyle = "rgba(255,226,117,.12)"; ctx.beginPath(); ctx.arc(targetX, targetY, 20 + Math.sin(performance.now() / 190) * 2, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = "rgba(255,226,117,.9)"; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(targetX, targetY, 17, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(targetX - 9, targetY); ctx.lineTo(targetX + 9, targetY); ctx.moveTo(targetX, targetY - 9); ctx.lineTo(targetX, targetY + 9); ctx.stroke();
      ctx.restore();
    }
  }

  function drawMoveTarget() {
    const pulse = 1 + Math.sin(performance.now() / 165) * .12;
    ctx.save();
    ctx.fillStyle = "rgba(116,230,255,.12)";
    ctx.beginPath(); ctx.arc(state.moveTarget.x, state.moveTarget.y, 18 * pulse, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = "rgba(141,234,255,.9)"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(state.moveTarget.x, state.moveTarget.y, 14 * pulse, 0, Math.PI * 2); ctx.stroke();
    ctx.strokeStyle = "rgba(223,251,255,.9)"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(state.moveTarget.x - 7, state.moveTarget.y); ctx.lineTo(state.moveTarget.x + 7, state.moveTarget.y); ctx.moveTo(state.moveTarget.x, state.moveTarget.y - 7); ctx.lineTo(state.moveTarget.x, state.moveTarget.y + 7); ctx.stroke();
    ctx.restore();
  }

  function drawStadium() {
    if (matchBackground.complete && matchBackground.naturalWidth > 0) {
      ctx.drawImage(matchBackground, 0, 0, WORLD.width, WORLD.height);
      ctx.fillStyle = "rgba(4, 18, 43, .24)";
      ctx.fillRect(0, 0, WORLD.width, WORLD.height);
    } else {
      const sky = ctx.createLinearGradient(0, 0, 0, WORLD.height);
      sky.addColorStop(0, "#0b356a"); sky.addColorStop(.46, "#1f6fa5"); sky.addColorStop(.47, "#113e68"); sky.addColorStop(1, "#08234b");
      ctx.fillStyle = sky; ctx.fillRect(0, 0, WORLD.width, WORLD.height);
    }
    ctx.fillStyle = "rgba(255,255,255,.045)"; ctx.fillRect(0, 42, WORLD.width, 24); ctx.fillRect(0, WORLD.height - 65, WORLD.width, 22);
    for (const person of crowd) { ctx.globalAlpha = .5; ctx.fillStyle = person.color; ctx.beginPath(); ctx.arc(person.x, person.y, person.r, 0, Math.PI * 2); ctx.fill(); }
    ctx.globalAlpha = 1;
    ctx.fillStyle = "rgba(4, 16, 37, .36)"; ctx.fillRect(0, 43, WORLD.width, 9); ctx.fillRect(0, WORLD.height - 50, WORLD.width, 9);
    for (let x = 25; x < WORLD.width; x += 50) { ctx.fillStyle = "rgba(112, 210, 255, .2)"; ctx.fillRect(x, 46, 2, 8); ctx.fillRect(x + 20, WORLD.height - 55, 2, 8); }
  }

  function drawPitch() {
    const gradient = ctx.createLinearGradient(0, WORLD.top, 0, WORLD.bottom);
    gradient.addColorStop(0, "#2fa66b"); gradient.addColorStop(.55, "#168354"); gradient.addColorStop(1, "#0d633f");
    ctx.fillStyle = gradient; ctx.fillRect(WORLD.left, WORLD.top, WORLD.right - WORLD.left, WORLD.bottom - WORLD.top);
    ctx.save(); ctx.beginPath(); ctx.rect(WORLD.left, WORLD.top, WORLD.right - WORLD.left, WORLD.bottom - WORLD.top); ctx.clip();
    for (let x = WORLD.left; x < WORLD.right; x += 100) { ctx.fillStyle = (Math.floor((x - WORLD.left) / 100) % 2) ? "rgba(255,255,255,.032)" : "rgba(0,25,15,.035)"; ctx.fillRect(x, WORLD.top, 100, WORLD.bottom - WORLD.top); }
    for (let y = WORLD.top + 20; y < WORLD.bottom; y += 40) { ctx.strokeStyle = "rgba(255,255,255,.03)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(WORLD.left, y); ctx.lineTo(WORLD.right, y); ctx.stroke(); }
    ctx.restore();
    ctx.strokeStyle = "rgba(233, 255, 241, .86)"; ctx.lineWidth = 4; ctx.strokeRect(WORLD.left, WORLD.top, WORLD.right - WORLD.left, WORLD.bottom - WORLD.top);
    ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(WORLD.width / 2, WORLD.top); ctx.lineTo(WORLD.width / 2, WORLD.bottom); ctx.stroke();
    ctx.beginPath(); ctx.arc(WORLD.width / 2, WORLD.height / 2, 86, 0, Math.PI * 2); ctx.stroke(); ctx.fillStyle = "rgba(238,255,246,.9)"; ctx.beginPath(); ctx.arc(WORLD.width / 2, WORLD.height / 2, 4, 0, Math.PI * 2); ctx.fill();
    drawPenaltyArea(true); drawPenaltyArea(false);
    ctx.strokeStyle = "rgba(233,255,241,.58)"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(WORLD.left + 164, WORLD.height / 2, 70, -Math.PI / 2, Math.PI / 2); ctx.stroke(); ctx.beginPath(); ctx.arc(WORLD.right - 164, WORLD.height / 2, 70, Math.PI / 2, Math.PI * 1.5); ctx.stroke();
    ctx.fillStyle = "rgba(235,255,244,.78)"; ctx.beginPath(); ctx.arc(WORLD.left + 125, WORLD.height / 2, 3, 0, Math.PI * 2); ctx.fill(); ctx.beginPath(); ctx.arc(WORLD.right - 125, WORLD.height / 2, 3, 0, Math.PI * 2); ctx.fill();
  }

  function drawPenaltyArea(left) {
    const x = left ? WORLD.left : WORLD.right - 164;
    ctx.strokeRect(x, WORLD.height / 2 - 145, 164, 290);
    const smallX = left ? WORLD.left : WORLD.right - 74;
    ctx.strokeRect(smallX, WORLD.height / 2 - 76, 74, 152);
  }

  function drawGoals() {
    for (const left of [true, false]) {
      const x = left ? WORLD.left - 3 : WORLD.right + 3;
      const direction = left ? -1 : 1;
      ctx.save();
      ctx.strokeStyle = "rgba(230,246,255,.85)"; ctx.lineWidth = 6;
      ctx.beginPath(); ctx.moveTo(x, WORLD.goalTop); ctx.lineTo(x + direction * 45, WORLD.goalTop); ctx.lineTo(x + direction * 45, WORLD.goalBottom); ctx.lineTo(x, WORLD.goalBottom); ctx.stroke();
      ctx.strokeStyle = "rgba(216,241,255,.23)"; ctx.lineWidth = 2;
      for (let y = WORLD.goalTop + 14; y < WORLD.goalBottom; y += 18) { ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + direction * 45, y); ctx.stroke(); }
      for (let xx = x + direction * 12; Math.abs(xx - x) <= 45; xx += direction * 12) { ctx.beginPath(); ctx.moveTo(xx, WORLD.goalTop); ctx.lineTo(xx, WORLD.goalBottom); ctx.stroke(); }
      ctx.restore();
    }
  }

  function drawAimGuide() {
    if (!state.shootCharging) return;
    const player = userPlayer();
    const elapsed = clamp((performance.now() - state.shootStartedAt) / 1000, 0, 1);
    const direction = normalize(Math.cos(player.facing), Math.sin(player.facing));
    ctx.save();
    ctx.setLineDash([12, 11]); ctx.lineWidth = 5; ctx.strokeStyle = `rgba(255, 227, 111, ${.45 + elapsed * .45})`;
    ctx.beginPath(); ctx.moveTo(player.x + direction.x * 32, player.y + direction.y * 32); ctx.lineTo(player.x + direction.x * (180 + elapsed * 350), player.y + direction.y * (180 + elapsed * 350)); ctx.stroke();
    ctx.setLineDash([]); ctx.fillStyle = "rgba(255,220,94,.88)"; ctx.beginPath(); ctx.arc(player.x + direction.x * (62 + elapsed * 58), player.y + direction.y * (62 + elapsed * 58), 6 + elapsed * 6, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
  }

  function drawPlayer(player) {
    const isUser = player.controlled;
    const owner = ball.ownerId === player.id;
    const bob = Math.sin(performance.now() / 260 + player.pulse) * (owner ? 1.9 : .8);
    const x = player.x; const y = player.y + bob;
    ctx.save();
    ctx.globalAlpha = .35; ctx.fillStyle = "#05271f"; ctx.beginPath(); ctx.ellipse(x, y + 27, 33, 11, 0, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
    if (isUser) {
      ctx.strokeStyle = "rgba(255,226,102,.95)"; ctx.lineWidth = 3; ctx.setLineDash([5, 5]); ctx.beginPath(); ctx.arc(x, y + 3, 38 + Math.sin(performance.now()/170) * 2, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = "#fff0a4"; roundedRect(x - 20, y - 51, 40, 17, 8); ctx.fill(); ctx.fillStyle = "#31548c"; ctx.font = "900 11px Inter, sans-serif"; ctx.textAlign = "center"; ctx.fillText("1P", x, y - 39);
    }
    if (player.kind === "captain" && generatedPlayers.captain.complete) drawGeneratedPlayer(generatedPlayers.captain, x, y, owner);
    else if (player.kind === "mascot" && mascot.complete) drawMascotPlayer(x, y, owner);
    else if (generatedPlayers[player.kind] && generatedPlayers[player.kind].complete) drawGeneratedPlayer(generatedPlayers[player.kind], x, y, owner);
    else drawVectorPlayer(player, x, y, owner);
    ctx.fillStyle = isUser ? "#eaf8ff" : "rgba(227,242,255,.8)"; ctx.font = "700 11px Inter, 'Noto Sans TC', sans-serif"; ctx.textAlign = "center"; ctx.fillText(player.name, x, y + 46);
    ctx.restore();
  }

  function drawMascotPlayer(x, y, owner) {
    ctx.save();
    const size = owner ? 98 : 88;
    if (owner) { ctx.shadowColor = "rgba(105,220,255,.95)"; ctx.shadowBlur = 22; }
    ctx.drawImage(mascot, x - size / 2, y - size * .95, size, size * 1.12);
    ctx.restore();
  }

  function drawGeneratedPlayer(image, x, y, owner) {
    // Preserve generated portrait proportions so ears, hair, tails and shoes
    // remain readable at the same time as the match sprite stays compact.
    const maxWidth = owner ? 102 : 92;
    const maxHeight = owner ? 132 : 118;
    const scale = Math.min(maxWidth / image.naturalWidth, maxHeight / image.naturalHeight);
    const width = image.naturalWidth * scale;
    const height = image.naturalHeight * scale;
    ctx.drawImage(image, x - width / 2, y - height * .86, width, height);
  }

  function drawGoalkeeperDive(keeper) {
    const bob = Math.sin(performance.now() / 250) * .8;
    ctx.save();
    ctx.globalAlpha = .42; ctx.fillStyle = "#05271f"; ctx.beginPath(); ctx.ellipse(keeper.x, keeper.y + 27, 43, 12, 0, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
    ctx.drawImage(goalkeeperDive, keeper.x - 66, keeper.y - 63 + bob, 132, 88);
    ctx.restore();
  }

  function drawVectorPlayer(player, x, y, owner) {
    const palette = player.team === TEAM.blue
      ? (player.kind === "calico" ? { body: "#e99659", shirt: "#134c90", trim: "#ffdb79", ear: "#ffb18d" } : { body: "#f4f6ff", shirt: "#e7eaf5", trim: "#7cb8f7", ear: "#ffc3c9" })
      : { body: "#a96d55", shirt: "#9b304e", trim: "#ffab6f", ear: "#e89e87" };
    if (owner) { ctx.shadowColor = player.team === TEAM.blue ? "rgba(91,215,255,.9)" : "rgba(255,118,100,.85)"; ctx.shadowBlur = 17; }
    ctx.fillStyle = palette.shirt; ctx.beginPath(); ctx.ellipse(x, y + 9, 24, 26, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = palette.trim; ctx.fillRect(x - 3, y - 11, 6, 31);
    ctx.fillStyle = palette.body; ctx.beginPath(); ctx.arc(x, y - 14, 22, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = palette.ear; ctx.beginPath(); ctx.moveTo(x - 18, y - 26); ctx.lineTo(x - 14, y - 47); ctx.lineTo(x - 2, y - 32); ctx.closePath(); ctx.fill(); ctx.beginPath(); ctx.moveTo(x + 18, y - 26); ctx.lineTo(x + 14, y - 47); ctx.lineTo(x + 2, y - 32); ctx.closePath(); ctx.fill();
    ctx.fillStyle = "#1a2140"; ctx.beginPath(); ctx.arc(x - 8, y - 15, 3.5, 0, Math.PI * 2); ctx.arc(x + 8, y - 15, 3.5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#f6b3b3"; ctx.beginPath(); ctx.arc(x, y - 6, 3, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,.95)"; ctx.font = "900 12px Inter, sans-serif"; ctx.textAlign = "center"; ctx.fillText(player.number, x, y + 13);
  }

  function drawBall() {
    ctx.save();
    ctx.globalAlpha = .28; ctx.fillStyle = "#05291e"; ctx.beginPath(); ctx.ellipse(ball.x + 4, ball.y + 12, 18, 7, 0, 0, Math.PI * 2); ctx.fill(); ctx.globalAlpha = 1;
    const owner = getPlayer(ball.ownerId);
    if (owner) { ctx.fillStyle = owner.team === TEAM.blue ? "rgba(112,224,255,.24)" : "rgba(255,126,101,.25)"; ctx.beginPath(); ctx.arc(ball.x, ball.y, 29, 0, Math.PI * 2); ctx.fill(); }
    ctx.fillStyle = "#fbfdff"; ctx.strokeStyle = "#172847"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(ball.x, ball.y, ball.r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#182a4b"; ctx.beginPath(); ctx.arc(ball.x, ball.y, 5, 0, Math.PI * 2); ctx.fill();
    for (let i = 0; i < 5; i += 1) { const angle = i * Math.PI * 2 / 5 + .28; ctx.beginPath(); ctx.moveTo(ball.x + Math.cos(angle) * 5, ball.y + Math.sin(angle) * 5); ctx.lineTo(ball.x + Math.cos(angle) * 11, ball.y + Math.sin(angle) * 11); ctx.stroke(); }
    ctx.restore();
  }

  function drawParticles() {
    for (const particle of particles) { ctx.globalAlpha = clamp(particle.life, 0, 1); ctx.fillStyle = particle.color; ctx.beginPath(); ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2); ctx.fill(); }
    ctx.globalAlpha = 1;
  }

  function roundedRect(x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + width, y, x + width, y + height, r); ctx.arcTo(x + width, y + height, x, y + height, r); ctx.arcTo(x, y + height, x, y, r); ctx.arcTo(x, y, x + width, y, r); ctx.closePath();
  }

  function canvasPoint(event) {
    const rect = canvas.getBoundingClientRect();
    return { x: (event.clientX - rect.left) * WORLD.width / rect.width, y: (event.clientY - rect.top) * WORLD.height / rect.height };
  }

  function setupJoystick() {
    const base = ui.joystick;
    const updateJoystick = (event) => {
      const rect = base.getBoundingClientRect();
      const radius = Math.min(rect.width, rect.height) * .39;
      const dx = event.clientX - (rect.left + rect.width / 2);
      const dy = event.clientY - (rect.top + rect.height / 2);
      const vector = normalize(dx, dy);
      const amount = clamp(Math.hypot(dx, dy) / radius, 0, 1);
      state.joystick.x = vector.x * amount;
      state.joystick.y = vector.y * amount;
      ui.joystickKnob.style.transform = `translate(calc(-50% + ${state.joystick.x * radius}px), calc(-50% + ${state.joystick.y * radius}px))`;
    };
    const endJoystick = (event) => {
      if (event && state.joystick.pointerId !== event.pointerId) return;
      state.joystick.active = false; state.joystick.pointerId = null; state.joystick.x = 0; state.joystick.y = 0;
      ui.joystickKnob.style.transform = "translate(-50%, -50%)";
    };
    base.addEventListener("pointerdown", (event) => { event.preventDefault(); state.joystick.active = true; state.joystick.pointerId = event.pointerId; base.setPointerCapture(event.pointerId); updateJoystick(event); });
    base.addEventListener("pointermove", (event) => { if (state.joystick.active && event.pointerId === state.joystick.pointerId) updateJoystick(event); });
    base.addEventListener("pointerup", endJoystick); base.addEventListener("pointercancel", endJoystick); base.addEventListener("lostpointercapture", endJoystick);
  }

  function setupActionButtons() {
    document.querySelectorAll("[data-action]").forEach((button) => {
      const action = button.dataset.action;
      button.addEventListener("pointerdown", (event) => {
        event.preventDefault(); button.classList.add("is-held"); button.setPointerCapture(event.pointerId);
        if (action === "shoot") beginShoot(); else if (action === "pass") passBall(); else if (action === "dash") dash(); else if (action === "tackle") tackle(); else if (action === "skill") useSkill();
      });
      const release = (event) => { event.preventDefault(); button.classList.remove("is-held"); if (action === "shoot") finishShoot(); };
      button.addEventListener("pointerup", release); button.addEventListener("pointercancel", release); button.addEventListener("lostpointercapture", release);
    });
  }

  function setupKeyboard() {
    window.addEventListener("keydown", (event) => {
      const key = event.key.toLowerCase();
      if (["arrowleft", "arrowright", "arrowup", "arrowdown", " "].includes(key)) event.preventDefault();
      if (key === "escape") { if (!ui.helpModal.hidden) hideModal(ui.helpModal); else if (state.active) togglePause(); return; }
      if (state.active && state.mode === "penalty") {
        if (["a", "arrowleft"].includes(key)) { state.penaltyAim = clamp(state.penaltyAim - .12, -1, 1); return; }
        if (["d", "arrowright"].includes(key)) { state.penaltyAim = clamp(state.penaltyAim + .12, -1, 1); return; }
        if (["w", "arrowup"].includes(key)) { state.penaltyAim = clamp(state.penaltyAim - .12, -1, 1); return; }
        if (["s", "arrowdown"].includes(key)) { state.penaltyAim = clamp(state.penaltyAim + .12, -1, 1); return; }
      }
      if (state.keys.has(key)) return;
      state.keys.add(key);
      if (key === " ") beginShoot();
      if (key === "e") passBall();
      if (key === "shift") dash();
      if (key === "q") tackle();
      if (key === "r") useSkill();
    });
    window.addEventListener("keyup", (event) => { const key = event.key.toLowerCase(); state.keys.delete(key); if (key === " ") finishShoot(); });
    window.addEventListener("blur", () => { state.keys.clear(); if (state.shootCharging) finishShoot(); });
  }

  function setupUi() {
    ui.start.addEventListener("click", () => startMatch(state.selectedMode));
    ui.guideStart.addEventListener("click", () => { hideModal(ui.helpModal); startMatch(); });
    ui.help.addEventListener("click", () => showModal(ui.helpModal));
    ui.brand.addEventListener("click", quitToMenu);
    ui.pause.addEventListener("click", () => togglePause());
    ui.resume.addEventListener("click", () => togglePause(false));
    ui.quit.addEventListener("click", quitToMenu);
    ui.pauseQuit.addEventListener("click", quitToMenu);
    ui.goalContinue.addEventListener("click", continueAfterGoal);
    document.querySelectorAll("[data-close-modal]").forEach((button) => button.addEventListener("click", () => hideModal(document.getElementById(button.dataset.closeModal))));
    document.querySelectorAll(".roster-item[data-player-id]").forEach((button) => button.addEventListener("click", () => selectPlayer(button.dataset.playerId)));
    document.querySelectorAll(".mode-card").forEach((button) => button.addEventListener("click", () => {
      const selectedMode = button.dataset.mode;
      if (selectedMode !== "quick" && selectedMode !== "penalty") {
        showToast(selectedMode === "tournament" ? "錦標賽正在準備中，先來一場快速賽吧！" : "故事模式正在製作中，敬請期待！", 1700);
        return;
      }
      state.selectedMode = selectedMode === "penalty" ? "penalty" : "quick";
      document.querySelectorAll(".mode-card").forEach((item) => item.classList.remove("selected"));
      button.classList.add("selected");
      ui.start.innerHTML = state.selectedMode === "penalty" ? '<span class="button-icon">🎯</span> 開始點球挑戰' : '<span class="button-icon">⚽</span> 開始 3v3 快速賽';
      showToast(state.selectedMode === "penalty" ? "已選擇點球挑戰，按上方按鈕開始。" : "已選擇快速賽，準備開球！", 1300);
    }));
    setupJoystick(); setupActionButtons(); setupKeyboard();
    window.addEventListener("resize", resizeCanvas);
    canvas.addEventListener("pointerdown", (event) => {
      if (!state.active || state.paused) return;
      event.preventDefault();
      const point = canvasPoint(event);
      if (state.mode === "penalty") {
        state.penaltyAim = clamp((point.y - WORLD.height / 2) / 112, -1, 1);
        return;
      }
      setMoveTarget(point);
    });
    canvas.addEventListener("pointermove", (event) => {
      if (!state.active || state.paused || state.mode !== "quick" || !(event.buttons & 1)) return;
      event.preventDefault();
      setMoveTarget(canvasPoint(event));
    });
    updateCaptainCard();
    updateRosterSelection();
    draw();
  }

  setupUi();
})();
