// rmpp setup UI. Talks to the Go side through Wails: window.go.main.App.<Method>() and runtime events
// "step" (message key, detail) and "log" (a line of tablet output).
(function () {
  "use strict";
  const T = {
    en: {
      title: "rmpp setup", other: "한국어",
      connect: "Connect to the tablet",
      connect_help: "Turn on developer mode on the tablet and connect it with USB (or use its Wi-Fi address).",
      address: "Tablet address", password: "Root password",
      password_help: "Shown on the tablet: Settings › General › Help › About › Copyrights and licenses. Needed once; then a key is used.",
      connect_btn: "Connect", connecting: "Connecting…", connected: "Connected", need_pw: "Enter the root password once.",
      choose: "Choose mods", progress: "Progress", details: "Details",
      restore_note: "The reMarkable OS was updated: the mods' system files need restoring.", restore_btn: "Restore",
      install_btn: "Install ticked", remove_btn: "Remove unticked installed",
      restart_note: "The tablet's screen restarts once or twice while installing.",
      installed: "installed", default: "recommended", loading: "Loading the list of mods…",
      footer: "After a reMarkable OS update, open this app again and press Restore.",
      confirm_remove: "Remove these from the tablet?\n\n",
      nothing: "Nothing selected.", nothing_to_remove: "Untick installed mods to remove them.",
      step_vellum: "Installing Vellum (the package manager)", step_repo: "Adding the rmpp package repository",
      step_installing: "Installing", step_release: "Installing from the GitHub release:",
      step_reenable: "Restoring system files after an OS update", step_removing: "Removing",
      step_done: "Done.", failed: "Failed:", skipped: "Skipped (no description):",
      advanced: "Advanced", key_file: "SSH key", browse: "Browse…", port: "SSH port",
      key_help: "Empty: the app's own key (made on first use, also used by the install scripts). Another key must have no passphrase.",
      pw_only: "Log in with the password every time (add no key to the tablet)",
      via_key: "with key", via_pw: "with password",
      manual: "installed by hand", manual_tip: "Its files are on the tablet but not as a Vellum package; installing it here puts it under Vellum.",
      no_vellum: "Vellum (the package manager) is not on the tablet yet: installing sets it up first.",
    },
    ko: {
      title: "rmpp 설치", other: "English",
      connect: "태블릿 연결",
      connect_help: "태블릿에서 개발자 모드를 켜고 USB로 연결하세요 (또는 Wi-Fi 주소).",
      address: "태블릿 주소", password: "root 비밀번호",
      password_help: "태블릿의 설정 › 일반 › 도움말 › 정보 › 저작권 및 라이선스에 있습니다. 처음 한 번만 필요하고, 이후에는 키를 씁니다.",
      connect_btn: "연결", connecting: "연결하는 중…", connected: "연결됨", need_pw: "root 비밀번호를 한 번 입력하세요.",
      choose: "설치할 항목", progress: "진행 상황", details: "자세히",
      restore_note: "reMarkable OS가 업데이트되어 mod의 시스템 파일을 복구해야 합니다.", restore_btn: "복구",
      install_btn: "체크한 항목 설치", remove_btn: "체크 해제한 설치 항목 제거",
      restart_note: "설치하는 동안 태블릿 화면이 한두 번 다시 시작됩니다.",
      installed: "설치됨", default: "추천", loading: "mod 목록을 받는 중…",
      footer: "reMarkable OS를 업데이트한 뒤에는 이 앱을 다시 열고 복구를 누르세요.",
      confirm_remove: "태블릿에서 제거할까요?\n\n",
      nothing: "선택한 항목이 없습니다.", nothing_to_remove: "제거하려면 설치된 항목의 체크를 해제하세요.",
      step_vellum: "Vellum(패키지 관리자)을 설치합니다", step_repo: "rmpp 패키지 저장소를 추가합니다",
      step_installing: "설치합니다", step_release: "GitHub 릴리스에서 설치합니다:",
      step_reenable: "OS 업데이트 뒤의 시스템 파일을 복구합니다", step_removing: "제거합니다",
      step_done: "완료.", failed: "실패:", skipped: "설명을 받지 못해 건너뜀:",
      advanced: "고급", key_file: "SSH 키", browse: "찾아보기…", port: "SSH 포트",
      key_help: "비워 두면 앱의 키를 씁니다 (처음에 만들어지고, 설치 스크립트도 같은 키를 씁니다). 다른 키는 암호(passphrase)가 없어야 합니다.",
      pw_only: "매번 비밀번호로 로그인 (태블릿에 키를 등록하지 않음)",
      via_key: "키로 연결", via_pw: "비밀번호로 연결",
      manual: "직접 설치됨", manual_tip: "파일은 태블릿에 있지만 Vellum 패키지가 아닙니다. 여기서 설치하면 Vellum이 관리합니다.",
      no_vellum: "태블릿에 아직 Vellum(패키지 관리자)이 없습니다. 설치할 때 먼저 설치됩니다.",
    },
  };
  let lang = (navigator.language || "en").toLowerCase().startsWith("ko") ? "ko" : "en";
  try { lang = localStorage.getItem("lang") || lang; } catch (e) {}
  const t = k => (T[lang] && T[lang][k]) || T.en[k] || k;
  const $ = id => document.getElementById(id);
  const go = () => window.go.main.App;

  let mods = [], installed = new Set(), manual = new Set(), selected = new Set(), busy = false;
  let conn = null;                                   // last successful Connect result (for the status line)

  // Advanced settings are remembered on this computer.
  const ADV = ["keyPath", "port"];
  try {
    for (const id of ADV) $(id).value = localStorage.getItem("adv." + id) || "";
    $("pwOnly").checked = localStorage.getItem("adv.pwOnly") === "1";
    if (ADV.some(id => $(id).value) || $("pwOnly").checked) $("advanced").open = true;
  } catch (e) {}
  function saveAdvanced() {
    try {
      for (const id of ADV) localStorage.setItem("adv." + id, $(id).value.trim());
      localStorage.setItem("adv.pwOnly", $("pwOnly").checked ? "1" : "");
    } catch (e) {}
  }
  function options() {
    const port = parseInt($("port").value, 10);
    return { keyPath: $("keyPath").value.trim(), port: port > 0 && port < 65536 ? port : 0, passwordOnly: $("pwOnly").checked };
  }

  function connLine() {
    if (!conn) return;
    const how = conn.auth === "password" ? t("via_pw") : t("via_key") + (conn.keyPath ? " (" + conn.keyPath + ")" : "");
    $("connState").className = "state ok";
    $("connState").textContent = [t("connected"), conn.host, conn.model, how].filter(Boolean).join(" · ");
  }

  function applyLang() {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-t]").forEach(el => { el.textContent = t(el.dataset.t); });
    $("lang").textContent = t("other");
    document.title = t("title");
    connLine();
    renderMods();
  }
  $("lang").onclick = () => {
    lang = lang === "ko" ? "en" : "ko";
    try { localStorage.setItem("lang", lang); } catch (e) {}
    applyLang();
  };
  $("repoLink").onclick = e => { e.preventDefault(); window.runtime.BrowserOpenURL("https://github.com/lorancecall/rmpp-packages"); };

  function showError(e) {
    const el = $("error");
    if (!e) { el.hidden = true; return; }
    el.textContent = t("failed") + " " + (e && e.message ? e.message : String(e));
    el.hidden = false;
  }
  function setBusy(b) {
    busy = b;
    ["btnConnect", "btnInstall", "btnRemove", "btnRestore"].forEach(id => { $(id).disabled = b; });
    document.querySelectorAll(".mods input").forEach(i => { i.disabled = b; });
  }

  // ---- mod list: one row per mod, its add-ons indented under it
  function renderMods() {
    const ul = $("mods");
    ul.replaceChildren();
    for (const m of mods) {
      const li = document.createElement("li");
      if (m.parent) li.className = "addon";
      const label = document.createElement("label");
      const cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = selected.has(m.id);
      cb.disabled = busy;
      cb.onchange = () => {
        if (cb.checked) {
          selected.add(m.id);
          if (m.parent) selected.add(m.parent);          // an add-on needs its mod
        } else {
          selected.delete(m.id);
          if (!m.parent) mods.filter(a => a.parent === m.id).forEach(a => selected.delete(a.id));
        }
        renderMods();
      };
      const name = document.createElement("span");
      name.className = "name";
      name.textContent = (m.label || m.id).replace(/^└\s*/, "");
      const short = document.createElement("span");
      short.className = "short";
      short.textContent = (m.short && (m.short[lang] || m.short.en)) || "";
      label.append(cb, name, short);
      if (installed.has(m.id)) label.append(tag(t("installed"), true));
      else if (manual.has(m.id)) { const s = tag(t("manual"), true); s.title = t("manual_tip"); label.append(s); }
      else if (m.default) label.append(tag(t("default"), false));
      li.append(label);
      const d = m.detail && (m.detail[lang] || m.detail.en);
      if (d && !m.parent) {
        const p = document.createElement("div");
        p.className = "detail";
        p.textContent = d.split("|").join(" ");
        li.append(p);
      }
      ul.append(li);
    }
  }
  function tag(text, on) {
    const s = document.createElement("span");
    s.className = "tag" + (on ? " on" : "");
    s.textContent = text;
    return s;
  }

  // ---- progress
  function stepLine(key, detail) {
    const ol = $("steps");
    const last = ol.lastElementChild;
    if (last) last.className = "done";
    const li = document.createElement("li");
    li.textContent = t("step_" + key) + (detail ? " " + detail : "");
    if (key === "done") li.className = "done";
    ol.append(li);
  }
  function logLine(line) {
    const pre = $("log");
    pre.textContent += line + "\n";
    pre.scrollTop = pre.scrollHeight;
  }
  function startProgress() {
    $("progress").hidden = false;
    $("steps").replaceChildren();
    $("log").textContent = "";
    showError(null);
  }

  // ---- actions
  async function connect() {
    showError(null);
    setBusy(true);
    $("connState").className = "state";
    $("connState").textContent = t("connecting");
    saveAdvanced();
    const o = options();
    try {
      const r = await go().Connect($("host").value, $("pw").value, o);
      if (r.needPassword) {
        $("pwrow").hidden = false; $("pwhelp").hidden = false;
        $("connState").textContent = t("need_pw");
        $("pw").focus();
        return;
      }
      if (!o.passwordOnly) $("pw").value = "";        // password-only logins need it again next time
      $("pwrow").hidden = !o.passwordOnly; $("pwhelp").hidden = true;
      conn = { host: $("host").value.trim() || "10.11.99.1", model: r.model, auth: r.auth, keyPath: r.keyPath };
      connLine();
      applyStatus(r);
      $("choose").hidden = false;
    } catch (e) {
      $("connState").textContent = "";
      showError(e);
    } finally {
      setBusy(false);
    }
  }
  function applyStatus(r) {
    installed = new Set(r.installed || []);
    manual = new Set(r.manual || []);
    selected = new Set([...installed, ...mods.filter(m => m.default).map(m => m.id)]);
    $("restore").hidden = !r.needsRestore;
    $("novellum").hidden = !!r.vellum;
    renderMods();
  }
  async function refresh() {
    try { applyStatus(await go().Refresh()); } catch (e) { showError(e); }
  }
  async function run(fn) {
    startProgress();
    setBusy(true);
    try { await fn(); } catch (e) { showError(e); } finally { setBusy(false); await refresh(); }
  }

  $("btnConnect").onclick = connect;
  $("btnKey").onclick = async () => {
    try { const p = await go().PickKeyFile(); if (p) { $("keyPath").value = p; saveAdvanced(); } } catch (e) { showError(e); }
  };
  $("pwOnly").onchange = () => {
    $("keyPath").disabled = $("btnKey").disabled = $("pwOnly").checked;
    if ($("pwOnly").checked) { $("pwrow").hidden = false; $("pwhelp").hidden = false; }
  };
  $("pwOnly").onchange();
  go().DefaultKeyPath().then(p => { $("keyPath").placeholder = p; }).catch(() => {});
  $("host").onkeydown = e => { if (e.key === "Enter") connect(); };
  $("pw").onkeydown = e => { if (e.key === "Enter") connect(); };
  $("btnInstall").onclick = () => {
    // only what is not installed yet (installed rows stay ticked so unticking can mean "remove")
    const ids = mods.filter(m => selected.has(m.id) && !installed.has(m.id)).map(m => m.id);
    if (!ids.length) { showError(t("nothing")); return; }
    run(() => go().Install(ids));
  };
  $("btnRemove").onclick = () => {
    const ids = mods.filter(m => installed.has(m.id) && !selected.has(m.id)).map(m => m.id);
    if (!ids.length) { showError(t("nothing_to_remove")); return; }
    const names = ids.map(id => (mods.find(m => m.id === id) || {}).id).join("\n");
    if (!window.confirm(t("confirm_remove") + names)) return;
    run(() => go().Remove(ids));
  };
  $("btnRestore").onclick = () => run(() => go().Restore());

  window.runtime.EventsOn("step", stepLine);
  window.runtime.EventsOn("log", logLine);

  applyLang();
  $("connState").textContent = t("loading");
  go().Catalog().then(r => {
    mods = r.mods || [];
    selected = new Set(mods.filter(m => m.default).map(m => m.id));
    $("connState").textContent = "";
    if (r.warnings && r.warnings.length) {
      $("warnings").textContent = t("skipped") + " " + r.warnings.join("; ");
      $("warnings").hidden = false;
    }
    renderMods();
  }).catch(e => { $("connState").textContent = ""; showError(e); });
})();
