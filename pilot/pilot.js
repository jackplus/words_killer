"use strict";

const app = document.querySelector("#app");
const notice = document.querySelector("#notice");
const environment = document.querySelector("#environment");
const localDate = new Intl.DateTimeFormat("sv-SE", { timeZone: "Asia/Taipei", dateStyle: "short" });
const localTime = new Intl.DateTimeFormat("zh-TW", { timeZone: "Asia/Taipei", dateStyle: "short", timeStyle: "short" });
const roundHeaders = ["participant_id", "round_id", "first_question_at", "summary_seen_at", "terminal_state"];
const probeHeaders = ["participant_id", "word_id", "submitted_at", "correct", "protocol_status"];
const practiceTypes = ["meaning", "meaning", "term", "audio", "term", "audio"];
const BREAK_MS = 2 * 60 * 1000;

let packet;
let signature;
let progress;
let screen = "host";
let roundIndex = 0;
let audio;
let breakTimer;

function element(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "on") {
      for (const [event, handler] of Object.entries(value)) node.addEventListener(event, handler);
    } else if (value === true) {
      node.setAttribute(key, "");
    } else if (value !== false && value !== undefined) {
      node.setAttribute(key, value);
    }
  }
  node.append(...children.filter(child => child !== null && child !== undefined));
  return node;
}

function button(label, handler, style = "", disabled = false) {
  return element("button", { type: "button", class: style, disabled, on: { click: handler } }, label);
}

function message(text = "") {
  notice.textContent = text;
}

function moveTo(destination) {
  if (audio) audio.pause();
  clearTimeout(breakTimer);
  screen = destination;
  message();
  render();
  app.focus();
}

function filePicker(label, read, disabled = false) {
  return element("label", { class: "file-button" }, label,
    element("input", {
      type: "file", accept: ".json,application/json", "aria-label": label, disabled,
      on: {
        change: async event => {
          const file = event.target.files[0];
          if (!file) return;
          try {
            read(JSON.parse(await file.text()));
            moveTo("host");
          } catch (error) {
            message(error.message);
          } finally {
            event.target.value = "";
          }
        }
      }
    }));
}

function validOptions(values, answer) {
  return Array.isArray(values) && values.length === 4 && new Set(values).size === 4
    && values.every(value => typeof value === "string" && value.length > 0) && values.includes(answer);
}

function readPacket(data) {
  const idFormat = /^[A-Za-z0-9][A-Za-z0-9_-]{1,95}$/;
  const day0 = new Date(data?.day0 + "T00:00:00Z");
  if (!/^P(0[1-9]|1[0-2])$/.test(data?.participant_id) || !["AB", "BA"].includes(data.order)
      || !/^\d{4}-\d\d-\d\d$/.test(data.day0) || !Number.isFinite(day0.valueOf())
      || new Date(day0.valueOf() + 86400000).toISOString().slice(0, 10) !== data.day1
      || typeof data.rehearsal !== "boolean" || data.rounds?.length !== 2
      || data.rounds.map(round => round.arm).join("") !== data.order) {
    throw new Error("题包格式不完整，请从分组工具重新生成。");
  }
  const wordIDs = new Set();
  for (const round of data.rounds) {
    if (!idFormat.test(round.round_id) || round.items?.length !== 6
        || !Array.isArray(round.pair_options) || round.pair_options.length !== 4
        || new Set(round.pair_options).size !== 4
        || round.pair_options.some(value => typeof value !== "string" || !value)) {
      throw new Error("每轮需要 6 个词及 4 个题块释义。");
    }
    for (const [index, item] of round.items.entries()) {
      const due = new Date(item.due_at);
      if (!idFormat.test(item.id) || wordIDs.has(item.id) || !item.term || !item.meaning
          || !Number.isFinite(due.valueOf()) || localDate.format(due) !== data.day1
          || !validOptions(item.meaning_options, item.meaning) || !validOptions(item.term_options, item.term)
          || !validOptions(item.d1_options, item.term)
          || (index < 2 && !round.pair_options.includes(item.meaning))
          || (practiceTypes[index] === "audio" && !item.audio?.startsWith("data:audio/wav;base64,"))) {
        throw new Error("题包有重复词、无效日期、缺少选项或离线发音。");
      }
      wordIDs.add(item.id);
    }
  }
  if (new Set(data.rounds.map(round => round.round_id)).size !== 2
      || data.probe_order?.length !== 12 || new Set(data.probe_order).size !== 12
      || !data.probe_order.every(id => wordIDs.has(id))) {
    throw new Error("次日测评应与两轮的 12 个词一一对应。");
  }
  const nextSignature = fingerprint(data);
  const nextProgress = {
    version: 1, participant: data.participant_id, signature: nextSignature,
    rounds: {}, probes: {}, flagged: {}, steps: 0, revision: 0
  };
  try {
    const saved = localStorage.getItem(storageKey(data, nextSignature));
    if (saved) Object.assign(nextProgress, checkedCheckpoint(JSON.parse(saved), data, nextSignature));
  } catch {
    // File URLs can have browser-specific storage rules. Explicit checkpoints also work.
  }
  packet = data;
  signature = nextSignature;
  progress = nextProgress;
  environment.textContent = data.rehearsal ? "模拟演练 · 禁止混入真人数据" : "离线试用";
}

function fingerprint(data) {
  let value = 2166136261;
  for (const character of JSON.stringify(data)) value = Math.imul(value ^ character.charCodeAt(0), 16777619);
  return (value >>> 0).toString(16);
}

function storageKey(data, hash) {
  return `words-killer-pilot-v1/${data.participant_id}/${hash}`;
}

function checkedCheckpoint(saved, data, hash) {
  const roundIDs = data.rounds.map(round => round.round_id);
  if (saved?.version !== 1 || saved.participant !== data.participant_id || saved.signature !== hash
      || !Number.isInteger(saved.steps) || saved.steps < 0
      || !Number.isInteger(saved.revision) || saved.revision < 0
      || !saved.rounds || !saved.probes || !saved.flagged
      || !Object.keys(saved.rounds).every(id => roundIDs.includes(id))
      || !Object.keys(saved.probes).concat(Object.keys(saved.flagged)).every(id => data.probe_order.includes(id))
      || !Object.values(saved.rounds).every(state =>
        ["active", "abandoned", "not_started", "completed"].includes(state.status)
        && ["first", "retry"].includes(state.stage) && ["answer", "feedback"].includes(state.view)
        && Number.isInteger(state.position) && state.position >= 0 && state.position < 6
        && state.answers && state.retries && Array.isArray(state.misses))) {
    throw new Error("进度备份与该题包不匹配或已损坏。");
  }
  return saved;
}

function readCheckpoint(saved) {
  const checked = checkedCheckpoint(saved, packet, signature);
  if (checked.revision < progress.revision || Object.entries(progress.probes).some(([id, row]) => {
    const next = checked.probes[id];
    return !next || probeHeaders.some(key => row[key] !== next[key]);
  })) {
    throw new Error("这份备份比本机记录旧或含不同的已提交首答。请使用最新进度。");
  }
  if (progress.revision > 0 && !window.confirm("用这份备份替换本页现有进度？")) return;
  progress = checked;
  save(false);
}

function save(incrementRevision = true) {
  if (incrementRevision) progress.revision += 1;
  try {
    localStorage.setItem(storageKey(packet, signature), JSON.stringify(progress));
  } catch {
    // The host can always download the checkpoint from memory.
  }
}

function recordTime(stage, index = 0) {
  progress.steps += 1;
  if (!packet.rehearsal) return new Date().toISOString();
  const base = stage === "probe" ? latestDue() : new Date(packet.day0 + "T14:00:00+08:00").valueOf() + index * 900000;
  return new Date(base + progress.steps * 100).toISOString();
}

function download(filename, text, mime) {
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const link = element("a", { href: url, download: filename });
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function csv(headers, rows) {
  function cell(value) {
    const text = String(value ?? "");
    return /["\r\n,]/.test(text) ? '"' + text.replaceAll('"', '""') + '"' : text;
  }
  return [headers, ...rows.map(row => headers.map(key => row[key]))].map(row => row.map(cell).join(",")).join("\r\n") + "\r\n";
}

function saveRounds() {
  const rows = packet.rounds.map(round => {
    const data = progress.rounds[round.round_id];
    return {
      participant_id: packet.participant_id, round_id: round.round_id,
      first_question_at: data?.first ?? "", summary_seen_at: data?.summary ?? "",
      terminal_state: data?.status === "completed" ? "completed" : data?.first ? "abandoned" : "not_started"
    };
  });
  download("rounds.csv", csv(roundHeaders, rows), "text/csv;charset=utf-8");
}

function saveProbes() {
  const rows = packet.probe_order.flatMap(id => {
    const row = progress.probes[id];
    if (row) return [row];
    return progress.flagged[id] ? [probeRow(id, progress.flagged[id], "", "prior_exposure")] : [];
  });
  download("probes.csv", csv(probeHeaders, rows), "text/csv;charset=utf-8");
}

function words() {
  return packet.rounds.flatMap(round => round.items);
}

function latestDue() {
  return Math.max(...words().map(item => Date.parse(item.due_at)));
}

function today() {
  return localDate.format(new Date());
}

function availableProbe() {
  return packet.rehearsal || (today() === packet.day1 && Date.now() >= latestDue());
}

function activeRound() {
  return packet.rounds[roundIndex];
}

function roundState() {
  return progress.rounds[activeRound().round_id];
}

function freshRound() {
  return { status: "active", first: "", summary: "", ended: "", stage: "first", position: 0, view: "answer", answers: {}, retries: {}, misses: [] };
}

function canStartRound(index) {
  if (!packet.rehearsal && today() !== packet.day0) return false;
  if (index === 0) return true;
  const previous = progress.rounds[packet.rounds[0].round_id];
  return Boolean(previous?.ended && (packet.rehearsal || Date.now() >= Date.parse(previous.ended) + BREAK_MS));
}

function scheduleHostRefresh(firstEnd) {
  if (packet.rehearsal) return;
  const now = Date.now();
  const d0 = Date.parse(packet.day0 + "T00:00:00+08:00");
  const d1 = Date.parse(packet.day1 + "T00:00:00+08:00");
  const next = Math.min(...[d0, d1, latestDue(), d1 + 86400000, Date.parse(firstEnd) + BREAK_MS]
    .filter(boundary => boundary > now));
  if (Number.isFinite(next)) breakTimer = setTimeout(render, Math.min(next - now + 25, 2147483647));
}

function openRound(index) {
  const round = packet.rounds[index];
  const existing = progress.rounds[round.round_id];
  if (!canStartRound(index) || (existing && existing.status !== "active")) return;
  roundIndex = index;
  if (!existing) {
    const state = freshRound();
    state.first = recordTime("round", index);
    progress.rounds[round.round_id] = state;
    save();
  }
  moveTo("round");
}

function endRound(index) {
  if (!canStartRound(index)) return;
  const round = packet.rounds[index];
  const state = progress.rounds[round.round_id] ?? freshRound();
  if (state.status !== "active") return;
  if (!window.confirm(state.first ? "结束本轮并记录为未完成？" : "将本轮登记为未开始？")) return;
  state.status = state.first ? "abandoned" : "not_started";
  state.ended = recordTime("round", index);
  progress.rounds[round.round_id] = state;
  save();
  moveTo("host");
}

function host() {
  clearTimeout(breakTimer);
  const intro = element("div", {},
    element("p", { class: "stamp" }, "主持人操作台"),
    element("h1", {}, packet ? `参与者 ${packet.participant_id}` : "导入参与者题包"),
    element("p", { class: "lead tabular" }, packet
      ? `D0 ${packet.day0}　·　D+1 ${packet.day1}　·　台北时间`
      : "打开分组工具生成的 participant.json，再开始当天任务。"),
    element("div", { class: "imports" },
      filePicker("导入参与者题包", readPacket),
      packet ? filePicker("导入进度", readCheckpoint) : null));
  if (!packet) return intro;

  const tracks = element("div", { class: "tracks" });
  for (const [index, round] of packet.rounds.entries()) {
    const state = progress.rounds[round.round_id];
    const finished = state && state.status !== "active";
    const allowed = canStartRound(index);
    tracks.append(element("section", { class: "track" },
      element("h2", {}, `D0 · 第 ${index + 1} 轮`),
      element("p", {}, state?.status === "completed" ? "已完成"
        : state?.status === "abandoned" ? "已结束 · 未完成"
        : state?.status === "not_started" ? "已登记 · 未开始"
        : state?.first ? "已暂停"
        : allowed ? "6 个词 · 含必要的错词补练" : index === 1 && (packet.rehearsal || today() === packet.day0) ? "第一轮结束并休息 2 分钟后开放" : "在 D0 当天开放"),
      finished ? null : button(state?.first ? "继续本轮" : `开始第 ${index + 1} 轮`, () => openRound(index), "primary", !allowed),
      finished ? null : button(state?.first ? "结束本轮" : "登记未开始", () => endRound(index), "quiet exit", !allowed)));
  }
  const pending = packet.probe_order.filter(id => !Object.hasOwn(progress.probes, id) && !progress.flagged[id]).length;
  const probeWindow = `开放时间 ${localTime.format(new Date(latestDue()))} · 截止当天午夜`;
  const probeStatus = element("p", {}, pending ? probeWindow : "已结束");
  const startProbe = button(Object.keys(progress.probes).length ? "继续次日测评" : "开始次日测评",
    () => moveTo("probe"), "primary", !availableProbe() || pending === 0);
  tracks.append(element("section", { class: "track" },
    element("h2", {}, "D+1 · 次日测评"), probeStatus, startProbe));
  const markers = element("div", { class: "moderator-list" });
  for (const word of words()) {
    markers.append(element("label", {},
      element("input", {
        type: "checkbox", checked: Boolean(progress.flagged[word.id]), disabled: Object.hasOwn(progress.probes, word.id),
        on: { change: event => {
          if (event.target.checked) progress.flagged[word.id] = recordTime("probe");
          else delete progress.flagged[word.id];
          save();
          const remaining = packet.probe_order.some(id => !Object.hasOwn(progress.probes, id) && !progress.flagged[id]);
          startProbe.disabled = !availableProbe() || !remaining;
          probeStatus.textContent = remaining ? probeWindow : "已结束";
        } }
      }), " ", word.term));
  }
  const firstEnd = progress.rounds[packet.rounds[0].round_id]?.ended;
  scheduleHostRefresh(firstEnd);
  intro.append(tracks,
    element("details", {}, element("summary", {}, "主持人 · 标记受干扰词"), markers),
    element("hr", { class: "rule" }),
    element("div", { class: "toolbar" },
      button("下载进度备份", () => download(`${packet.participant_id}-checkpoint.json`, JSON.stringify(progress), "application/json")),
      button("下载 rounds.csv", saveRounds),
      button("下载 probes.csv", saveProbes)));
  return intro;
}

function heading(title, label, value, maximum) {
  return element("div", {},
    element("div", { class: "progress" },
      element("span", { class: "phase tabular" }, label),
      element("progress", { value, max: maximum, "aria-label": label })),
    element("h1", {}, title));
}

function questionOptions(options, submit, label = "提交答案") {
  const panel = element("div", { class: "choices", role: "group", "aria-label": "选项" });
  let selected;
  const submitButton = button(label, () => submit(selected), "primary", true);
  options.forEach((option, index) => {
    const choice = button("", () => {
      selected = option;
      for (const sibling of panel.children) sibling.setAttribute("aria-pressed", String(sibling === choice));
      submitButton.disabled = false;
    }, "choice");
    choice.setAttribute("aria-pressed", "false");
    choice.append(element("span", { class: "letter", "aria-hidden": "true" }, "ABCD"[index]), option);
    panel.append(choice);
  });
  return { panel, actions: element("div", { class: "actions" }, submitButton) };
}

function appendRoundControls(panel) {
  panel.append(element("div", { class: "toolbar" },
    button("暂停并返回主持页", () => moveTo("host"), "quiet"),
    button("结束本轮", () => endRound(roundIndex), "quiet exit")));
}

function roundLabel(state) {
  if (state.stage === "retry") return `错词补练 ${state.position + 1} / ${state.misses.length}`;
  if (activeRound().arm === "B" && state.position < 2) return "第 1–2 题 / 6";
  return `第 ${state.position + 1} 题 / 6`;
}

function canAnswerRound() {
  if (screen === "round" && roundState()?.status === "active" && (packet.rehearsal || today() === packet.day0)) return true;
  message("本轮已结束或已过 D0，请返回主持页。");
  return false;
}

function pairQuestion(state) {
  const round = activeRound();
  const panel = heading("词义配对", roundLabel(state), 0, 6);
  panel.append(element("p", { class: "lead" }, "为两个词各选一条不同的释义，再一起提交。"));
  const pairs = element("div", { class: "pair-form" });
  const selectors = [];
  const submit = button("提交两个配对", () => {
    if (!canAnswerRound() || submit.disabled) return;
    for (const [index, item] of round.items.slice(0, 2).entries()) {
      state.answers[item.id] = selectors[index].value === item.meaning;
    }
    state.position = 1;
    saveFeedback(state);
  }, "primary", true);
  for (const item of round.items.slice(0, 2)) {
    const select = element("select", { "aria-label": `${item.term} 的释义`, on: { change: update } },
      element("option", { value: "" }, "选择释义"),
      ...round.pair_options.map(option => element("option", { value: option }, option)));
    selectors.push(select);
    pairs.append(element("label", { class: "pair-row" }, element("strong", { class: "term", lang: "en" }, item.term), select));
  }
  function update() {
    const [first, second] = selectors.map(select => select.value);
    submit.disabled = !first || !second || first === second;
  }
  panel.append(pairs, element("div", { class: "actions" }, submit));
  appendRoundControls(panel);
  return panel;
}

function currentItem(state) {
  return activeRound().items[state.stage === "retry" ? state.misses[state.position] : state.position];
}

function currentType(state) {
  return practiceTypes[state.stage === "retry" ? state.misses[state.position] : state.position];
}

function showAudio(item) {
  const player = new Audio(item.audio);
  audio = player;
  player.play().catch(() => message("无法播放离线音频，请主持人检查设备音量或暂停本轮。"));
}

function singleQuestion(state) {
  const item = currentItem(state);
  const type = currentType(state);
  const panel = heading({ meaning: "看词选义", term: "看义选词", audio: "听音选词" }[type],
    roundLabel(state), state.position, state.stage === "retry" ? state.misses.length : 6);
  const options = type === "meaning"
    ? (state.stage === "first" && state.position < 2 ? activeRound().pair_options : item.meaning_options)
    : item.term_options;
  const answers = state.stage === "retry" ? state.retries : state.answers;
  panel.append(type === "audio"
    ? element("div", { class: "prompt" }, button("播放读音", () => {
      if (audio) audio.pause();
      showAudio(item);
    }))
    : element("p", { class: type === "meaning" ? "prompt term" : "prompt", lang: type === "meaning" ? "en" : undefined },
      type === "meaning" ? item.term : item.meaning));
  const rotated = state.stage === "retry" ? options.slice(1).concat(options[0]) : options;
  const controls = questionOptions(rotated, selected => {
    if (!canAnswerRound() || state.view !== "answer" || Object.hasOwn(answers, item.id)) return;
    answers[item.id] = selected === (type === "meaning" ? item.meaning : item.term);
    if (state.stage === "first" && state.position === 0) {
      state.position = 1;
      save();
      moveTo("round");
    } else {
      saveFeedback(state);
    }
  });
  panel.append(controls.panel, controls.actions);
  appendRoundControls(panel);
  return panel;
}

function saveFeedback(state) {
  state.view = "feedback";
  save();
  moveTo("round");
}

function nextItem(state) {
  if (!canAnswerRound() || state.view !== "feedback") return;
  state.view = "answer";
  if (state.stage === "first" && state.position === 5) {
    state.misses = activeRound().items.flatMap((item, index) => state.answers[item.id] ? [] : [index]);
    if (state.misses.length) {
      state.stage = "retry";
      state.position = 0;
    } else {
      finishRound(state);
      return;
    }
  } else if (state.stage === "retry" && state.position === state.misses.length - 1) {
    finishRound(state);
    return;
  } else {
    state.position += 1;
  }
  save();
  moveTo("round");
}

function feedback(state) {
  const block = state.stage === "first" && state.position === 1;
  const items = block ? activeRound().items.slice(0, 2) : [currentItem(state)];
  const answers = state.stage === "retry" ? state.retries : state.answers;
  const panel = heading("答案反馈", roundLabel(state), state.position + 1, state.stage === "retry" ? state.misses.length : 6);
  panel.append(element("div", { class: "answers" }, ...items.map(item =>
    element("p", { class: answers[item.id] ? "answer" : "answer missed" },
      element("strong", {}, answers[item.id] ? "答对" : "答错"), " · ",
      element("span", { class: "term", lang: "en" }, item.term), " · ", item.meaning))),
  element("div", { class: "actions" }, button("继续", () => nextItem(state), "primary")));
  appendRoundControls(panel);
  return panel;
}

function finishRound(state) {
  const panel = summary(state);
  app.replaceChildren(panel);
  state.summary = recordTime("round", roundIndex);
  state.ended = state.summary;
  state.status = "completed";
  save();
  screen = "summary";
  app.focus();
}

function summary(state) {
  const first = Object.values(state.answers).filter(Boolean).length;
  const retried = Object.values(state.retries).filter(Boolean).length;
  return element("div", {},
    element("p", { class: "stamp" }, `D0 · 第 ${roundIndex + 1} 轮`),
    element("h1", {}, "本轮结算"),
    element("div", { class: "summary" },
      element("p", {}, "首答正确", element("strong", {}, `${first} / 6`)),
      state.misses.length ? element("p", {}, "补练正确", element("strong", {}, `${retried} / ${state.misses.length}`)) : null),
    roundIndex === 0 ? element("p", { class: "lead" }, "休息 2 分钟后开始第二轮。") : null,
    element("div", { class: "actions" }, button("返回主持页", () => moveTo("host"), "primary")));
}

function probeRow(id, timestamp, correct, status) {
  return { participant_id: packet.participant_id, word_id: id, submitted_at: timestamp, correct, protocol_status: status };
}

function probe() {
  if (!availableProbe()) {
    return element("div", {}, element("h1", {}, "次日测评尚未开放或已结束"),
      element("div", { class: "actions" }, button("返回主持页", () => moveTo("host"), "primary")));
  }
  const index = packet.probe_order.findIndex(id => !Object.hasOwn(progress.probes, id) && !progress.flagged[id]);
  if (index < 0) {
    return element("div", {},
      element("h1", {}, "次日测评已结束"),
      element("p", { class: "lead" }, "请把设备交回主持人。"),
      element("div", { class: "actions" }, button("返回主持页", () => moveTo("host"), "primary")));
  }
  const item = words().find(word => word.id === packet.probe_order[index]);
  const panel = heading("看义选词", `次日测评 ${index + 1} / 12`, index, 12);
  panel.append(element("p", { class: "prompt" }, item.meaning));
  function record(selected) {
    if (screen !== "probe" || Object.hasOwn(progress.probes, item.id) || progress.flagged[item.id]) return;
    if (!availableProbe()) {
      moveTo("probe");
      return;
    }
    const status = selected === null ? "rejected" : "valid";
    const correct = selected === null ? "" : Number(selected === item.term);
    progress.probes[item.id] = probeRow(item.id, recordTime("probe"), correct, status);
    save();
    moveTo("probe");
  }
  const controls = questionOptions(item.d1_options, record, "提交并继续");
  controls.actions.append(button("跳过本题", () => record(null), "quiet"));
  panel.append(controls.panel, controls.actions,
    element("div", { class: "toolbar" }, button("暂停并返回主持页", () => moveTo("host"), "quiet")));
  return panel;
}

function render() {
  if (screen === "probe") app.replaceChildren(probe());
  else if (screen === "round") {
    const state = roundState();
    const isPair = activeRound().arm === "B" && state.stage === "first" && state.position === 0;
    app.replaceChildren(state.view === "feedback" ? feedback(state) : isPair ? pairQuestion(state) : singleQuestion(state));
  } else {
    app.replaceChildren(host());
  }
}

render();
