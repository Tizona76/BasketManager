/* BM_TEMP_MOBILE_DIAG_BEGIN js */
(function () {
  "use strict";

  if (window.__BM_MOBILE_WEB_DIAG_V1__) return;
  window.__BM_MOBILE_WEB_DIAG_V1__ = true;

  const VERSION = "bm-mobile-web-diag-v2-flight-recorder";
  const MAX_TIMELINE = 900;
  const MAX_TOUCH_EVENTS = 220;
  const MAX_HISTORY = 260;
  const CAUSAL_STORAGE_KEY = "bm_mobile_diag_causal_v1";
  const MAX_CAUSAL_EVENTS = 80;
  const MAX_CAUSAL_BOOTS = 8;
  const sessionId = makeSessionId();
  const documentBootId = makeDocumentBootId();
  const startedAt = new Date();
  const causalState = initCausalState();
  let seq = 0;
  let panelVisible = false;
  let paused = false;
  let rawVisible = false;
  let expertMode = false;
  let lastSnapshot = null;
  let lastCanvasRect = null;
  let firstCanvasSeenAt = null;
  let firstNonZeroCanvasAt = null;
  let firstResizeAt = null;
  let firstVisualViewportResizeAt = null;
  let firstTouchAt = null;
  let firstPinchAt = null;
  let firstDragAt = null;
  let resizeCount = 0;
  let visualViewportCount = 0;
  let orientationCount = 0;
  let activeTouches = 0;
  let lastEvent = "script-load";
  let frameWatchUntil = performance.now() + 2000;
  let lastFrameSample = 0;
  let slowFrames = 0;
  let lastFrameTime = performance.now();
  let secretLongPressTimer = null;
  let secretLongPressStart = null;
  let secretLongPressActive = false;
  const SECRET_LONG_PRESS_ZONE_PX = 150;
  const SECRET_LONG_PRESS_MS = 3000;
  const SECRET_LONG_PRESS_MOVE_TOLERANCE_PX = 12;
  let currentTouchGesture = null;
  let currentPointer = null;
  let webglListenersInstalled = false;
  let godotStatusSeen = false;
  let godotStatusWasHidden = false;
  const pendingCrossOriginLimitations = [];
  const observers = [];
  const timers = [];
  const mediaWatchers = [];

  const report = {
    diagnostic_version: VERSION,
    session_metadata: {
      session_id: sessionId,
      document_boot_id: documentBootId,
      document_boot_count: causalState.boot_count,
      previous_session_id: causalState.previous_session_id,
      previous_boot: causalState.previous_boot,
      started_local: startedAt.toString(),
      started_iso_utc: startedAt.toISOString(),
      time_origin: performance.timeOrigin || null,
      privacy: "No network transmission, no cookies, no localStorage, no IndexedDB, no game save reads. SessionStorage is used only for bounded causal boot markers.",
    },
    environment: collectEnvironment(),
    initial_snapshot: null,
    timeline: [],
    viewport_changes: [],
    canvas_changes: [],
    touch_gestures: [],
    scroll_attempts: [],
    orientation_changes: [],
    visibility_changes: [],
    performance_summary: {},
    errors: [],
    cross_origin_limitations: pendingCrossOriginLimitations,
    automatic_findings: [],
    health_scores: {},
    synthesis: "",
    comparison: null,
    histories: {
      innerWidth: [],
      innerHeight: [],
      visualViewport: [],
      canvasRect: [],
      godotViewport: [],
      safeAreas: [],
      orientation: [],
      scale: [],
      dpr: [],
      cssViewportUnits: [],
      deltas: [],
    },
    manual_markers: [],
    final_snapshot: null,
    causal_diagnostic: {
      document_boot_id: documentBootId,
      boot_count: causalState.boot_count,
      previous_session_id: causalState.previous_session_id,
      previous_boot: causalState.previous_boot,
      current_signature: causalState.initial_signature,
      session_storage_available: causalState.available,
      storage_key: CAUSAL_STORAGE_KEY,
      bounded_events: MAX_CAUSAL_EVENTS,
    },
    privacy_statement: {
      no_network: true,
      no_cookies: true,
      no_localStorage: true,
      no_indexedDB: true,
      sessionStorage_only: true,
      no_save_reads: true,
      local_memory_and_sessionStorage_only: true,
    },
  };

  persistCausalEvent("script_boot", {
    session_id: sessionId,
    document_boot_id: documentBootId,
    boot_count: causalState.boot_count,
    previous_boot: causalState.previous_boot,
    signature: causalState.initial_signature,
  });
  installErrorHandlers();
  ensureSafeAreaProbe();
  snapshot("script-load", true);
  scheduleStartupSnapshots();
  installListeners();
  installCanvasObserversWhenReady();

  if (diagRequested()) showPanel("auto-url");
  logEvent("diagnostic-ready", { activation: activationState() });

  function makeSessionId() {
    const part = Math.random().toString(36).slice(2, 8);
    return "bm-diag-" + Date.now().toString(36) + "-" + part;
  }

  function makeDocumentBootId() {
    const part = Math.random().toString(36).slice(2, 8);
    return "doc-" + Date.now().toString(36) + "-" + part;
  }

  function initCausalState() {
    const fallback = {
      available: false,
      boot_count: 1,
      previous_session_id: null,
      previous_boot: null,
      initial_signature: "NO_RESTART_DETECTED",
    };
    try {
      if (!window.sessionStorage) return fallback;
      const raw = sessionStorage.getItem(CAUSAL_STORAGE_KEY);
      const store = raw ? JSON.parse(raw) : {};
      const boots = Array.isArray(store.boots) ? store.boots : [];
      const previous = boots.length ? boots[boots.length - 1] : null;
      const bootCount = Number(store.boot_count || 0) + 1;
      const flightSessionId = store.flight_session_id || sessionId;
      const current = {
        document_boot_id: documentBootId,
        session_id: sessionId,
        flight_session_id: flightSessionId,
        boot_count: bootCount,
        started_iso_utc: startedAt.toISOString(),
        started_perf_origin: performance.timeOrigin || null,
        url: location.href.split("#")[0],
        clean_exit: false,
        last_exit_event: null,
        last_event: "script_boot",
        last_signature: "NO_RESTART_DETECTED",
        webgl_context_lost_seen: false,
        js_error_seen: false,
        promise_rejection_seen: false,
      };
      const next = Object.assign({}, store, {
        flight_session_id: flightSessionId,
        boot_count: bootCount,
        current_document_boot_id: documentBootId,
        previous_session_id: previous ? previous.session_id : null,
        boots: boots.concat([current]).slice(-MAX_CAUSAL_BOOTS),
        events: (Array.isArray(store.events) ? store.events : []).slice(-MAX_CAUSAL_EVENTS),
      });
      sessionStorage.setItem(CAUSAL_STORAGE_KEY, JSON.stringify(next));
      return {
        available: true,
        boot_count: bootCount,
        previous_session_id: previous ? previous.session_id : null,
        previous_boot: previous,
        initial_signature: classifyBoot(previous),
      };
    } catch (e) {
      return Object.assign({}, fallback, { error: e.name || "Error" });
    }
  }

  function classifyBoot(previous) {
    if (!previous) return "NO_RESTART_DETECTED";
    if (previous.last_exit_event === "pageshow" && previous.pageshow_persisted === true) return "BFCache_RESTORE";
    if (previous.webgl_context_lost_seen) return "WEBGL_CONTEXT_LOST_BEFORE_RESTART";
    if (previous.clean_exit) return "NEW_DOCUMENT_AFTER_CLEAN_PAGEHIDE";
    return "NEW_DOCUMENT_AFTER_ABRUPT_TERMINATION";
  }

  function persistCausalEvent(type, data) {
    try {
      if (!window.sessionStorage) return;
      const raw = sessionStorage.getItem(CAUSAL_STORAGE_KEY);
      const store = raw ? JSON.parse(raw) : {};
      const events = Array.isArray(store.events) ? store.events : [];
      const ev = {
        type,
        document_boot_id: documentBootId,
        session_id: sessionId,
        utc_time: new Date().toISOString(),
        perf_now: round(performance.now()),
        data: data || {},
      };
      events.push(ev);
      store.events = events.slice(-MAX_CAUSAL_EVENTS);
      store.current_document_boot_id = documentBootId;
      if (Array.isArray(store.boots) && store.boots.length) {
        const current = store.boots[store.boots.length - 1];
        if (current && current.document_boot_id === documentBootId) {
          current.last_event = type;
          if (type === "pagehide" || type === "beforeunload") {
            current.clean_exit = true;
            current.last_exit_event = type;
            if (data && data.persisted !== undefined) current.pagehide_persisted = data.persisted;
          }
          if (type === "pageshow" && data && data.persisted !== undefined) current.pageshow_persisted = data.persisted;
          if (type === "webglcontextlost") current.webgl_context_lost_seen = true;
          if (type === "js-error") current.js_error_seen = true;
          if (type === "promise-rejection") current.promise_rejection_seen = true;
          if (type === "same-document-godot-status-reappeared") current.last_signature = "SAME_DOCUMENT_GODOT_RESTART";
        }
      }
      sessionStorage.setItem(CAUSAL_STORAGE_KEY, JSON.stringify(store));
    } catch (e) {
      // Diagnostic storage is best-effort only.
    }
  }

  function nowEvent(type, data) {
    return {
      seq: ++seq,
      type,
      local_time: new Date().toString(),
      utc_time: new Date().toISOString(),
      perf_now: round(performance.now()),
      data: data || {},
    };
  }

  function logEvent(type, data) {
    if (paused && type !== "paused" && type !== "resumed" && type !== "manual-marker") return null;
    lastEvent = type;
    const ev = nowEvent(type, data || {});
    report.timeline.push(ev);
    if (report.timeline.length > MAX_TIMELINE) {
      report.timeline.splice(0, report.timeline.length - MAX_TIMELINE);
      addFinding("INFORMATION", "timeline-limit", "Timeline limit reached; oldest non-critical events were dropped.");
    }
    persistCausalEvent(type, data || {});
    refreshPanel();
    return ev;
  }

  function recordHistory(name, value, reason) {
    if (!report.histories[name]) report.histories[name] = [];
    const prev = report.histories[name][report.histories[name].length - 1];
    const encoded = stableStringify(value);
    if (prev && prev.encoded === encoded) return;
    report.histories[name].push({
      seq: seq + 1,
      reason,
      perf_now: round(performance.now()),
      utc_time: new Date().toISOString(),
      value,
      encoded,
    });
    if (report.histories[name].length > MAX_HISTORY) report.histories[name].shift();
  }

  function stableStringify(value) {
    return safe(() => JSON.stringify(value, Object.keys(flattenForKeys(value)).sort()), JSON.stringify(value));
  }

  function flattenForKeys(value, out) {
    out = out || {};
    if (!value || typeof value !== "object") return out;
    Object.keys(value).forEach((k) => {
      out[k] = true;
      if (value[k] && typeof value[k] === "object") flattenForKeys(value[k], out);
    });
    return out;
  }

  function round(v) {
    return typeof v === "number" && isFinite(v) ? Math.round(v * 100) / 100 : v;
  }

  function compactRect(rect) {
    if (!rect) return null;
    return {
      x: round(rect.x), y: round(rect.y), top: round(rect.top), right: round(rect.right),
      bottom: round(rect.bottom), left: round(rect.left), width: round(rect.width), height: round(rect.height),
    };
  }

  function safe(fn, fallback) {
    try { return fn(); } catch (e) { return fallback === undefined ? { error: e.name || "Error" } : fallback; }
  }

  function getCss(el, props) {
    return safe(() => {
      if (!el) return null;
      const cs = getComputedStyle(el);
      const out = {};
      props.forEach((p) => { out[p] = cs.getPropertyValue(p); });
      return out;
    }, null);
  }

  function collectEnvironment() {
    const uaData = navigator.userAgentData || null;
    const brands = uaData && uaData.brands ? uaData.brands.map((b) => ({ brand: b.brand, version: b.version })) : null;
    const url = new URL(location.href);
    return {
      navigator: {
        userAgent: navigator.userAgent,
        platform: navigator.platform,
        vendor: navigator.vendor,
        appVersion: navigator.appVersion,
        userAgentData: uaData ? {
          brands,
          mobile: uaData.mobile,
          platform: uaData.platform,
        } : "unsupported",
        maxTouchPoints: navigator.maxTouchPoints,
        hardwareConcurrency: navigator.hardwareConcurrency,
        deviceMemory: navigator.deviceMemory || "unsupported",
        language: navigator.language,
        languages: Array.from(navigator.languages || []),
        standalone: navigator.standalone === undefined ? "unsupported" : navigator.standalone,
        onLine: navigator.onLine,
      },
      location: {
        origin: location.origin,
        pathname: location.pathname,
        diagnostic_query_present: url.searchParams.get("bm_diag") === "1",
        diagnostic_hash_present: location.hash.indexOf("bm_diag=1") >= 0,
      },
      document: {
        compatMode: document.compatMode,
        characterSet: document.characterSet,
        referrer_origin: safe(() => document.referrer ? new URL(document.referrer).origin : "", ""),
        meta_viewport: metaViewport(),
      },
      screen: screenInfo(),
      media: mediaInfo(),
      iframe: iframeInfo(),
      godot_config: godotConfigInfo(),
      connection: connectionInfo(),
      browser_family: browserFamily(),
      technical_fingerprint: technicalFingerprint(),
      comparison_hint: {
        intended_groups: ["Safari iPhone", "Chrome iPhone", "Safari Mac", "Chrome Mac", "iframe itch.io", "direct"],
        compare_fields: ["environment.browser_family", "environment.technical_fingerprint", "histories", "health_scores", "automatic_findings", "synthesis"],
      },
    };
  }

  function screenInfo() {
    return {
      width: screen.width,
      height: screen.height,
      availWidth: screen.availWidth,
      availHeight: screen.availHeight,
      colorDepth: screen.colorDepth,
      pixelDepth: screen.pixelDepth,
      devicePixelRatio: window.devicePixelRatio,
      orientation: screen.orientation ? { type: screen.orientation.type, angle: screen.orientation.angle } : "unsupported",
    };
  }

  function mediaInfo() {
    const queries = [
      "(orientation: portrait)", "(orientation: landscape)", "(pointer: coarse)", "(pointer: fine)",
      "(hover: hover)", "(hover: none)", "(any-pointer: coarse)", "(display-mode: standalone)",
      "(prefers-reduced-motion: reduce)", "(prefers-color-scheme: dark)",
    ];
    const out = {};
    queries.forEach((q) => { out[q] = safe(() => matchMedia(q).matches, "unsupported"); });
    return out;
  }

  function connectionInfo() {
    const c = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    if (!c) return "unsupported";
    return { effectiveType: c.effectiveType, downlink: c.downlink, rtt: c.rtt, saveData: c.saveData };
  }

  function metaViewport() {
    const m = document.querySelector("meta[name=viewport]");
    if (!m) return { present: false };
    const content = m.getAttribute("content") || "";
    return {
      present: true,
      content,
      viewport_fit_cover: /viewport-fit\s*=\s*cover/i.test(content),
      user_scalable: matchOption(content, "user-scalable"),
      initial_scale: matchOption(content, "initial-scale"),
      minimum_scale: matchOption(content, "minimum-scale"),
      maximum_scale: matchOption(content, "maximum-scale"),
    };
  }

  function matchOption(content, key) {
    const m = content.match(new RegExp(key + "\\s*=\\s*([^,]+)", "i"));
    return m ? m[1].trim() : "";
  }

  function iframeInfo() {
    const out = {
      is_top: window === window.top,
      is_parent: window === window.parent,
      frame_access: "not-attempted",
    };
    try {
      const frame = window.frameElement;
      if (frame) {
        out.frame_access = "accessible";
        out.frame_tag = frame.tagName;
        out.frame_rect = compactRect(frame.getBoundingClientRect());
        out.frame_attrs = {
          width: frame.getAttribute("width"),
          height: frame.getAttribute("height"),
          allow: frame.getAttribute("allow"),
          sandbox: frame.getAttribute("sandbox"),
          scrolling: frame.getAttribute("scrolling"),
          style: frame.getAttribute("style"),
        };
      } else {
        out.frame_access = "none";
      }
    } catch (e) {
      out.frame_access = "cross-origin-blocked";
      out.error = e.name;
      pendingCrossOriginLimitations.push(nowEvent("frameElement-blocked", { error: e.name }));
    }
    try {
      out.parent_origin = window.parent && window.parent.location ? window.parent.location.origin : "";
    } catch (e) {
      out.parent_origin = "cross-origin-blocked";
      pendingCrossOriginLimitations.push(nowEvent("parent-origin-blocked", { error: e.name }));
    }
    return out;
  }

  function godotConfigInfo() {
    return safe(() => {
      const cfg = window.GODOT_CONFIG || window.GodotConfig || null;
      if (!cfg) return "not-exposed";
      return {
        canvasResizePolicy: cfg.canvasResizePolicy,
        focusCanvas: cfg.focusCanvas,
        executable: cfg.executable,
        mainPack: cfg.mainPack,
        args: Array.isArray(cfg.args) ? cfg.args.slice(0, 8) : undefined,
      };
    }, "unavailable");
  }

  function browserFamily() {
    const ua = navigator.userAgent;
    const vendor = navigator.vendor || "";
    const ios = /iPhone|iPad|iPod/i.test(ua);
    if (/CriOS/i.test(ua)) return ios ? "Chrome iOS" : "Chrome";
    if (/FxiOS/i.test(ua)) return ios ? "Firefox iOS" : "Firefox";
    if (/EdgiOS|Edg\//i.test(ua)) return ios ? "Edge iOS" : "Edge";
    if (/Safari/i.test(ua) && /Apple/i.test(vendor)) return ios ? "Safari iOS" : "Safari";
    return ios ? "iOS WebKit other" : "Unknown/other";
  }

  function technicalFingerprint() {
    return [
      browserFamily(),
      /Mobi|iPhone|Android/i.test(navigator.userAgent) ? "Mobile" : "Desktop",
      screen.width + "x" + screen.height,
      "dpr" + window.devicePixelRatio,
      "touch" + navigator.maxTouchPoints,
      (matchMedia("(orientation: portrait)").matches ? "portrait" : "landscape"),
      (window === window.top ? "top" : "iframe"),
      VERSION,
    ].join("|");
  }

  function viewportUnits() {
    const units = ["100vh", "100dvh", "100svh", "100lvh", "100%", "-webkit-fill-available"];
    const host = document.createElement("div");
    host.setAttribute("aria-hidden", "true");
    host.style.cssText = "position:absolute;left:-9999px;top:-9999px;width:1px;visibility:hidden;pointer-events:none;";
    document.documentElement.appendChild(host);
    const out = {};
    units.forEach((u) => {
      const el = document.createElement("div");
      el.style.height = u;
      host.appendChild(el);
      out[u] = {
        supported: safe(() => CSS.supports("height", u), "unknown"),
        px: round(el.getBoundingClientRect().height),
      };
    });
    host.remove();
    return out;
  }

  function ensureSafeAreaProbe() {
    if (document.getElementById("bm-mobile-diag-safe-probe")) return;
    const el = document.createElement("div");
    el.id = "bm-mobile-diag-safe-probe";
    el.setAttribute("aria-hidden", "true");
    el.style.cssText = "position:fixed;left:-9999px;top:-9999px;width:0;height:0;pointer-events:none;visibility:hidden;padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left);";
    document.documentElement.appendChild(el);
  }

  function safeAreas() {
    const el = document.getElementById("bm-mobile-diag-safe-probe");
    const cs = el ? getComputedStyle(el) : null;
    return cs ? {
      top: cs.paddingTop, right: cs.paddingRight, bottom: cs.paddingBottom, left: cs.paddingLeft,
    } : "unavailable";
  }

  function findCanvas() {
    const canvases = Array.from(document.querySelectorAll("canvas"));
    const primary = canvases.find((c) => c.id && /canvas|godot/i.test(c.id)) || canvases[0] || null;
    return { primary, canvases };
  }

  function canvasInfo() {
    const found = findCanvas();
    const c = found.primary;
    if (!c) return { count: found.canvases.length, present: false };
    const rect = compactRect(c.getBoundingClientRect());
    const styles = getCss(c, ["position", "top", "left", "right", "bottom", "width", "height", "transform", "transform-origin", "touch-action", "pointer-events", "display", "visibility", "z-index", "max-width", "max-height", "object-fit"]);
    const vv = window.visualViewport;
    const visible = visibleIntersection(rect, vv ? { left: vv.offsetLeft, top: vv.offsetTop, right: vv.offsetLeft + vv.width, bottom: vv.offsetTop + vv.height, width: vv.width, height: vv.height } : { left: 0, top: 0, right: innerWidth, bottom: innerHeight, width: innerWidth, height: innerHeight });
    return {
      count: found.canvases.length,
      present: true,
      id: c.id || "",
      width_attr: c.width,
      height_attr: c.height,
      clientWidth: c.clientWidth,
      clientHeight: c.clientHeight,
      offsetWidth: c.offsetWidth,
      offsetHeight: c.offsetHeight,
      rect,
      styles,
      backing_to_css_ratio: {
        x: c.clientWidth ? round(c.width / c.clientWidth) : null,
        y: c.clientHeight ? round(c.height / c.clientHeight) : null,
      },
      dpr: window.devicePixelRatio,
      activeElement: document.activeElement ? document.activeElement.tagName + (document.activeElement.id ? "#" + document.activeElement.id : "") : "",
      tabindex: c.getAttribute("tabindex"),
      overflow: canvasOverflow(rect),
      visible_percent: visible.percent,
      visible_rect: visible.rect,
      godot_viewport_observation: godotViewportObservation(c, rect),
    };
  }

  function godotViewportObservation(canvas, rect) {
    const cfg = godotConfigInfo();
    const exposed = safe(() => ({
      has_Godot: typeof window.Godot !== "undefined",
      has_Engine: typeof window.Engine !== "undefined",
      has_GODOT_CONFIG: !!window.GODOT_CONFIG,
      has_DisplayServer: typeof window.DisplayServer !== "undefined",
      has_Window: typeof window.Window !== "undefined",
      has_Viewport: typeof window.Viewport !== "undefined",
    }), {});
    return {
      method: "non-invasive-web-observation",
      note: "Godot internal DisplayServer/Viewport APIs are usually not exposed to exported HTML. Values below are inferred from canvas/config only.",
      exposed_globals: exposed,
      config: cfg,
      canvas_css_size: rect ? { width: rect.width, height: rect.height } : null,
      canvas_backing_size: canvas ? { width: canvas.width, height: canvas.height } : null,
      content_scale_estimate: canvas && rect && rect.width && rect.height ? {
        x: round(canvas.width / rect.width),
        y: round(canvas.height / rect.height),
        dpr: window.devicePixelRatio,
      } : null,
    };
  }

  function visibleIntersection(rect, view) {
    if (!rect || !view) return { percent: null, rect: null };
    const left = Math.max(rect.left, view.left);
    const top = Math.max(rect.top, view.top);
    const right = Math.min(rect.right, view.right);
    const bottom = Math.min(rect.bottom, view.bottom);
    const width = Math.max(0, right - left);
    const height = Math.max(0, bottom - top);
    const area = Math.max(0, rect.width * rect.height);
    return { percent: area ? round((width * height / area) * 100) : null, rect: { left: round(left), top: round(top), right: round(right), bottom: round(bottom), width: round(width), height: round(height) } };
  }

  function canvasOverflow(rect) {
    if (!rect) return null;
    const vv = window.visualViewport;
    const top = vv ? vv.offsetTop : 0;
    const left = vv ? vv.offsetLeft : 0;
    const right = left + (vv ? vv.width : innerWidth);
    const bottom = top + (vv ? vv.height : innerHeight);
    return {
      top: round(top - rect.top),
      bottom: round(rect.bottom - bottom),
      left: round(left - rect.left),
      right: round(rect.right - right),
    };
  }

  function snapshot(reason, full) {
    const htmlEl = document.documentElement;
    const body = document.body;
    const se = document.scrollingElement || htmlEl;
    const vv = window.visualViewport;
    const snap = {
      reason,
      time: round(performance.now()),
      viewport: {
        innerWidth, innerHeight, outerWidth, outerHeight,
        doc_clientWidth: htmlEl.clientWidth,
        doc_clientHeight: htmlEl.clientHeight,
        doc_scrollWidth: htmlEl.scrollWidth,
        doc_scrollHeight: htmlEl.scrollHeight,
        body_clientWidth: body ? body.clientWidth : null,
        body_clientHeight: body ? body.clientHeight : null,
        body_scrollWidth: body ? body.scrollWidth : null,
        body_scrollHeight: body ? body.scrollHeight : null,
        scrollX, scrollY,
        scrollingElement: se ? { scrollTop: se.scrollTop, scrollLeft: se.scrollLeft, scrollHeight: se.scrollHeight, clientHeight: se.clientHeight } : null,
      },
      visualViewport: vv ? {
        width: round(vv.width), height: round(vv.height), offsetTop: round(vv.offsetTop), offsetLeft: round(vv.offsetLeft),
        pageTop: round(vv.pageTop), pageLeft: round(vv.pageLeft), scale: round(vv.scale),
        delta_inner_height: round(innerHeight - vv.height),
      } : "unsupported",
      styles: {
        html: getCss(htmlEl, ["overflow", "overflow-x", "overflow-y", "touch-action", "position", "width", "height", "min-height", "max-height"]),
        body: getCss(body, ["overflow", "overflow-x", "overflow-y", "touch-action", "position", "width", "height", "min-height", "max-height"]),
      },
      canvas: canvasInfo(),
      safe_areas: safeAreas(),
      units: full ? viewportUnits() : undefined,
      deltas: null,
      fullscreen: {
        enabled: document.fullscreenEnabled,
        element: !!document.fullscreenElement,
        webkitFullscreenElement: !!document.webkitFullscreenElement,
      },
      visibility: document.visibilityState,
      focus: document.hasFocus(),
      orientation: screen.orientation ? { type: screen.orientation.type, angle: screen.orientation.angle } : "unsupported",
      touch: { activeTouches, lastEvent },
    };
    snap.deltas = computeDeltas(snap);
    recordHistories(snap, reason);
    if (!report.initial_snapshot) report.initial_snapshot = snap;
    report.final_snapshot = snap;
    const compactChange = diffImportant(lastSnapshot, snap);
    if (full || compactChange.changed) logEvent("snapshot:" + reason, full ? snap : compactChange.data);
    evaluateFindings(snap);
    report.health_scores = computeHealthScores(snap);
    report.synthesis = buildSynthesis();
    trackCanvasChange(snap);
    lastSnapshot = snap;
    refreshPanel();
    return snap;
  }

  function recordHistories(snap, reason) {
    recordHistory("innerWidth", snap.viewport.innerWidth, reason);
    recordHistory("innerHeight", snap.viewport.innerHeight, reason);
    recordHistory("visualViewport", snap.visualViewport, reason);
    recordHistory("canvasRect", snap.canvas && snap.canvas.rect ? snap.canvas.rect : "missing", reason);
    recordHistory("godotViewport", snap.canvas && snap.canvas.godot_viewport_observation ? snap.canvas.godot_viewport_observation : "missing", reason);
    recordHistory("safeAreas", snap.safe_areas, reason);
    recordHistory("orientation", snap.orientation, reason);
    recordHistory("scale", typeof snap.visualViewport === "object" ? snap.visualViewport.scale : "unsupported", reason);
    recordHistory("dpr", window.devicePixelRatio, reason);
    if (snap.units) recordHistory("cssViewportUnits", snap.units, reason);
    recordHistory("deltas", snap.deltas, reason);
  }

  function computeDeltas(snap) {
    const vv = snap.visualViewport;
    const canvas = snap.canvas || {};
    const rect = canvas.rect || null;
    const units = snap.units || {};
    const out = {
      inner_minus_visual_height: metricDelta(typeof vv === "object" ? snap.viewport.innerHeight - vv.height : null, 12, 40, "px"),
      inner_minus_visual_width: metricDelta(typeof vv === "object" ? snap.viewport.innerWidth - vv.width : null, 12, 40, "px"),
      canvas_bottom_overflow: metricDelta(rect && canvas.overflow ? canvas.overflow.bottom : null, 4, 24, "px"),
      canvas_top_gap_vs_visualviewport: metricDelta(rect && typeof vv === "object" ? rect.top - vv.offsetTop : null, 4, 20, "px"),
      canvas_visible_missing_percent: metricDelta(canvas.visible_percent === null || canvas.visible_percent === undefined ? null : 100 - canvas.visible_percent, 1, 5, "%"),
      dpr_minus_backing_ratio_x: metricDelta(canvas.backing_to_css_ratio && canvas.backing_to_css_ratio.x ? canvas.backing_to_css_ratio.x - window.devicePixelRatio : null, 0.15, 0.5, "ratio"),
      vh_minus_visual_height: metricDelta(units["100vh"] && typeof vv === "object" ? units["100vh"].px - vv.height : null, 12, 40, "px"),
      dvh_minus_visual_height: metricDelta(units["100dvh"] && typeof vv === "object" ? units["100dvh"].px - vv.height : null, 8, 24, "px"),
    };
    return out;
  }

  function metricDelta(value, orange, red, unit) {
    if (value === null || value === undefined || value === "unsupported" || !isFinite(value)) {
      return { value: null, unit, severity: "unknown" };
    }
    const abs = Math.abs(value);
    return {
      value: round(value),
      abs: round(abs),
      unit,
      severity: abs >= red ? "red" : abs >= orange ? "orange" : "green",
    };
  }

  function diffImportant(prev, next) {
    if (!prev) return { changed: true, data: next };
    const fields = {
      inner: next.viewport.innerWidth + "x" + next.viewport.innerHeight,
      vv: typeof next.visualViewport === "object" ? next.visualViewport.width + "x" + next.visualViewport.height + "@" + next.visualViewport.scale + "+" + next.visualViewport.offsetTop : "unsupported",
      scroll: next.viewport.scrollX + "," + next.viewport.scrollY,
      canvas: next.canvas && next.canvas.rect ? JSON.stringify(next.canvas.rect) : "none",
      orientation: JSON.stringify(next.orientation),
    };
    const prevFields = {
      inner: prev.viewport.innerWidth + "x" + prev.viewport.innerHeight,
      vv: typeof prev.visualViewport === "object" ? prev.visualViewport.width + "x" + prev.visualViewport.height + "@" + prev.visualViewport.scale + "+" + prev.visualViewport.offsetTop : "unsupported",
      scroll: prev.viewport.scrollX + "," + prev.viewport.scrollY,
      canvas: prev.canvas && prev.canvas.rect ? JSON.stringify(prev.canvas.rect) : "none",
      orientation: JSON.stringify(prev.orientation),
    };
    const changed = {};
    Object.keys(fields).forEach((k) => { if (fields[k] !== prevFields[k]) changed[k] = { before: prevFields[k], after: fields[k] }; });
    return { changed: Object.keys(changed).length > 0, data: changed };
  }

  function trackCanvasChange(snap) {
    const rect = snap.canvas && snap.canvas.rect ? JSON.stringify(snap.canvas.rect) : "";
    if (snap.canvas && snap.canvas.present && firstCanvasSeenAt === null) firstCanvasSeenAt = performance.now();
    if (snap.canvas && snap.canvas.rect && snap.canvas.rect.width > 0 && snap.canvas.rect.height > 0 && firstNonZeroCanvasAt === null) firstNonZeroCanvasAt = performance.now();
    if (rect && rect !== lastCanvasRect) {
      report.canvas_changes.push(nowEvent("canvas-rect-change", snap.canvas));
      lastCanvasRect = rect;
    }
  }

  function addFinding(level, code, message) {
    const key = level + "|" + code + "|" + message;
    if (report.automatic_findings.some((f) => f.key === key)) return;
    report.automatic_findings.push({ key, level, code, message, at: new Date().toISOString(), perf_now: round(performance.now()) });
  }

  function evaluateFindings(snap) {
    const vv = snap.visualViewport;
    const c = snap.canvas;
    if (typeof vv === "object" && Math.abs(snap.viewport.innerHeight - vv.height) > 40) {
      addFinding("INDICE FORT", "inner-vs-visual-height", "innerHeight differs materially from visualViewport.height in this session.");
    }
    if (c && c.rect && c.overflow && c.overflow.bottom > 10) {
      addFinding("PROUVÉ PAR MESURE DE CETTE SESSION", "canvas-bottom-overflow", "Canvas bottom extends below the current visible viewport.");
    }
    if (c && c.rect && c.visible_percent !== null && c.visible_percent < 98) {
      addFinding("PROUVÉ PAR MESURE DE CETTE SESSION", "canvas-not-fully-visible", "The measured canvas is not fully visible in the current viewport.");
    }
    if (c && c.rect && typeof vv === "object" && Math.abs(c.rect.top - vv.offsetTop) > 4) {
      addFinding("INDICE FORT", "canvas-offset-vs-visualviewport", "Canvas top differs from visualViewport.offsetTop.");
    }
    if (report.cross_origin_limitations.length > 0) {
      addFinding("NON MESURABLE DANS CE CONTEXTE", "cross-origin-parent", "Some iframe parent details are blocked by browser cross-origin policy.");
    }
    const units = snap.units || {};
    if (units["100dvh"] && typeof vv === "object" && Math.abs(units["100dvh"].px - vv.height) < Math.abs((units["100vh"] || {}).px - vv.height)) {
      addFinding("INFORMATION", "dvh-closer-to-visualviewport", "Measured 100dvh is closer to visualViewport.height than 100vh.");
    }
    if (snap.safe_areas && typeof snap.safe_areas === "object") {
      const bottom = parseFloat(snap.safe_areas.bottom) || 0;
      if (bottom > 0 && c && c.overflow && c.overflow.bottom > -bottom) {
        addFinding("INDICE FORT", "safe-area-may-matter", "A non-zero safe-area bottom was measured while the canvas is close to or beyond the visible bottom.");
      }
    }
    if (firstCanvasSeenAt !== null && firstNonZeroCanvasAt !== null && firstNonZeroCanvasAt - firstCanvasSeenAt > 500) {
      addFinding("INDICE FORT", "late-first-canvas-size", "Canvas existed for more than 500 ms before a non-zero size was observed.");
    }
  }

  function computeHealthScores(snap) {
    const findings = report.automatic_findings;
    const score = (name, relatedCodes) => {
      let value = 100;
      relatedCodes.forEach((code) => {
        findings.filter((f) => f.code === code).forEach((f) => {
          if (f.level.indexOf("PROUVÉ") === 0) value -= 35;
          else if (f.level === "INDICE FORT") value -= 22;
          else if (f.level === "HYPOTHÈSE") value -= 12;
        });
      });
      return { score: Math.max(0, value), status: value >= 85 ? "green" : value >= 60 ? "orange" : "red" };
    };
    return {
      Viewport: score("Viewport", ["inner-vs-visual-height", "dvh-closer-to-visualviewport"]),
      Canvas: score("Canvas", ["canvas-bottom-overflow", "canvas-not-fully-visible", "canvas-offset-vs-visualviewport", "late-first-canvas-size"]),
      "Safe Areas": score("Safe Areas", ["safe-area-may-matter"]),
      Touch: score("Touch", ["drag-on-canvas-no-scroll"]),
      Scroll: score("Scroll", ["drag-on-canvas-no-scroll"]),
      Pinch: score("Pinch", ["pinch-no-visual-scale-change"]),
      Iframe: score("Iframe", ["cross-origin-parent"]),
      Godot: score("Godot", ["godot-internal-not-exposed"]),
      Performance: { score: Math.max(0, 100 - slowFrames * 4), status: slowFrames > 8 ? "red" : slowFrames > 3 ? "orange" : "green" },
      VisualViewport: typeof snap.visualViewport === "object" ? score("VisualViewport", ["inner-vs-visual-height"]) : { score: 40, status: "orange" },
    };
  }

  function buildSynthesis() {
    const proven = report.automatic_findings.filter((f) => f.level.indexOf("PROUVÉ") === 0).map((f) => f.code);
    const strong = report.automatic_findings.filter((f) => f.level === "INDICE FORT").map((f) => f.code);
    const parts = [];
    if (proven.length) parts.push("Mesures prouvées dans cette session: " + proven.join(", ") + ".");
    if (strong.length) parts.push("Indices forts à comparer entre navigateurs: " + strong.join(", ") + ".");
    if (!parts.length) parts.push("Aucune anomalie majeure n'est prouvée pour l'instant; comparer les rapports Safari iPhone, Chrome iPhone et Desktop.");
    parts.push("Cette synthèse se limite aux valeurs mesurées localement et ne désigne pas Safari, itch.io ou Godot comme cause sans comparaison.");
    return parts.join(" ");
  }

  function scheduleStartupSnapshots() {
    [50, 100, 250, 500, 1000, 2000, 5000, 10000].forEach((ms) => {
      timers.push(setTimeout(() => snapshot("t+" + ms + "ms", ms <= 500), ms));
    });
    requestAnimationFrame(frameLoop);
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", () => snapshot("DOMContentLoaded", true), { once: true, passive: true });
    }
    window.addEventListener("load", () => snapshot("load", true), { once: true, passive: true });
  }

  function frameLoop(t) {
    const dt = t - lastFrameTime;
    if (dt > 50) slowFrames++;
    lastFrameTime = t;
    if (performance.now() < frameWatchUntil) {
      if (t - lastFrameSample > 120) {
        lastFrameSample = t;
        snapshot("raf-startup", false);
      }
      requestAnimationFrame(frameLoop);
    }
  }

  function installListeners() {
    window.addEventListener("resize", () => { if (firstResizeAt === null) firstResizeAt = performance.now(); resizeCount++; report.viewport_changes.push(nowEvent("window-resize", snapshot("window-resize", false))); }, { passive: true });
    window.addEventListener("orientationchange", () => { orientationCount++; report.orientation_changes.push(nowEvent("orientationchange", snapshot("orientationchange", true))); }, { passive: true });
    if (screen.orientation && screen.orientation.addEventListener) {
      screen.orientation.addEventListener("change", () => { orientationCount++; report.orientation_changes.push(nowEvent("screen-orientation-change", snapshot("screen-orientation-change", true))); });
    }
    if (window.visualViewport) {
      visualViewport.addEventListener("resize", () => { if (firstVisualViewportResizeAt === null) firstVisualViewportResizeAt = performance.now(); visualViewportCount++; report.viewport_changes.push(nowEvent("visualViewport-resize", snapshot("visualViewport-resize", false))); }, { passive: true });
      visualViewport.addEventListener("scroll", () => { visualViewportCount++; report.viewport_changes.push(nowEvent("visualViewport-scroll", snapshot("visualViewport-scroll", false))); }, { passive: true });
    }
    ["focus", "blur", "online", "offline"].forEach((type) => window.addEventListener(type, () => logEvent(type, snapshot(type, false)), { passive: true }));
    ["visibilitychange", "pageshow", "pagehide", "freeze", "resume", "fullscreenchange", "webkitfullscreenchange"].forEach((type) => {
      window.addEventListener(type, (ev) => {
        const data = snapshot(type, type === "pageshow" || type === "pagehide");
        data.persisted = ev.persisted === undefined ? null : ev.persisted;
        persistCausalEvent(type, { persisted: data.persisted, visibilityState: document.visibilityState });
        report.visibility_changes.push(nowEvent(type, data));
      }, { passive: true });
    });
    window.addEventListener("beforeunload", () => persistCausalEvent("beforeunload", { visibilityState: document.visibilityState }), { passive: true });
    document.addEventListener("keydown", (ev) => {
      if (ev.ctrlKey && ev.shiftKey && String(ev.key).toLowerCase() === "d") showPanel("keyboard");
    }, { passive: true, capture: true });
    ["touchstart", "touchmove", "touchend", "touchcancel"].forEach((type) => document.addEventListener(type, handleTouch, { passive: true, capture: true }));
    ["pointerdown", "pointermove", "pointerup", "pointercancel", "pointerleave"].forEach((type) => document.addEventListener(type, handlePointer, { passive: true, capture: true }));
    window.addEventListener("wheel", (ev) => logEvent("wheel", { target: targetKind(ev.target), deltaX: round(ev.deltaX), deltaY: round(ev.deltaY), cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented }), { passive: true, capture: true });
    window.addEventListener("scroll", () => logEvent("scroll", { scrollX, scrollY, seTop: document.scrollingElement ? document.scrollingElement.scrollTop : null }), { passive: true });
    monitorMedia("(orientation: portrait)");
    monitorMedia("(orientation: landscape)");
    installPerformanceObservers();
  }

  function monitorMedia(query) {
    const m = matchMedia(query);
    const fn = () => logEvent("media-change", { query, matches: m.matches, snapshot: snapshot("media-" + query, false) });
    if (m.addEventListener) m.addEventListener("change", fn);
    else if (m.addListener) m.addListener(fn);
    mediaWatchers.push([m, fn]);
  }

  function targetKind(t) {
    if (!t) return "unknown";
    if (t.closest && t.closest("#bm-mobile-diag-root")) return "diagnostic-panel";
    if (t.tagName === "CANVAS") return "canvas";
    return String(t.tagName || "other").toLowerCase();
  }

  function touchPoint(t) {
    return { x: round(t.clientX), y: round(t.clientY) };
  }

  function dist(a, b) {
    const dx = a.clientX - b.clientX;
    const dy = a.clientY - b.clientY;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function handleTouch(ev) {
    activeTouches = ev.touches ? ev.touches.length : 0;
    const kind = targetKind(ev.target);
    if (firstTouchAt === null) firstTouchAt = performance.now();
    handleSecretLongPress(ev);
    if (ev.type === "touchstart") {
      currentTouchGesture = {
        start_time: performance.now(),
        start_scrollY: scrollY,
        start_vv_pageTop: window.visualViewport ? visualViewport.pageTop : null,
        target: kind,
        touches_start: ev.touches.length,
        start: ev.touches[0] ? touchPoint(ev.touches[0]) : null,
        max_dx: 0,
        max_dy: 0,
        pinch_start_distance: ev.touches.length >= 2 ? round(dist(ev.touches[0], ev.touches[1])) : null,
        pinch_end_distance: null,
        cancelable_seen: !!ev.cancelable,
        defaultPrevented_seen: !!ev.defaultPrevented,
        move_count: 0,
      };
    } else if (ev.type === "touchmove" && currentTouchGesture) {
      currentTouchGesture.move_count++;
      currentTouchGesture.cancelable_seen = currentTouchGesture.cancelable_seen || !!ev.cancelable;
      currentTouchGesture.defaultPrevented_seen = currentTouchGesture.defaultPrevented_seen || !!ev.defaultPrevented;
      if (ev.touches[0] && currentTouchGesture.start) {
        currentTouchGesture.max_dx = Math.max(currentTouchGesture.max_dx, Math.abs(ev.touches[0].clientX - currentTouchGesture.start.x));
        currentTouchGesture.max_dy = Math.max(currentTouchGesture.max_dy, Math.abs(ev.touches[0].clientY - currentTouchGesture.start.y));
      }
      if (ev.touches.length >= 2) currentTouchGesture.pinch_end_distance = round(dist(ev.touches[0], ev.touches[1]));
      if (ev.touches.length >= 2 && firstPinchAt === null) firstPinchAt = performance.now();
    } else if ((ev.type === "touchend" || ev.type === "touchcancel") && currentTouchGesture) {
      const g = currentTouchGesture;
      g.end_time = performance.now();
      g.duration_ms = round(g.end_time - g.start_time);
      g.end_scrollY = scrollY;
      g.end_vv_pageTop = window.visualViewport ? visualViewport.pageTop : null;
      g.direction = g.max_dy > g.max_dx ? "vertical" : g.max_dx > g.max_dy ? "horizontal" : "tap/none";
      g.pinch_ratio = g.pinch_start_distance && g.pinch_end_distance ? round(g.pinch_end_distance / g.pinch_start_distance) : null;
      g.visualViewport_scale = window.visualViewport ? round(visualViewport.scale) : "unsupported";
      report.touch_gestures.push(g);
      if (report.touch_gestures.length > MAX_TOUCH_EVENTS) report.touch_gestures.shift();
      if (g.direction === "vertical") {
        if (firstDragAt === null) firstDragAt = performance.now();
        const moved = Math.abs((g.end_scrollY || 0) - (g.start_scrollY || 0)) > 2 || Math.abs((g.end_vv_pageTop || 0) - (g.start_vv_pageTop || 0)) > 2;
        const attempt = Object.assign({ visible_scroll_changed: moved }, g);
        report.scroll_attempts.push(nowEvent("scroll-attempt", attempt));
        if (g.target === "canvas" && !moved) addFinding("PROUVÉ PAR MESURE DE CETTE SESSION", "drag-on-canvas-no-scroll", "Vertical drag started on canvas without visible page or visualViewport scroll.");
      }
      if (g.pinch_ratio && Math.abs(g.pinch_ratio - 1) > 0.08 && window.visualViewport && Math.abs(visualViewport.scale - 1) < 0.02) {
        addFinding("INDICE FORT", "pinch-no-visual-scale-change", "A two-finger pinch distance changed, but visualViewport.scale did not materially change.");
      }
      logEvent("touch-gesture", g);
      currentTouchGesture = null;
    }
    logEvent(ev.type, { touches: activeTouches, changedTouches: ev.changedTouches ? ev.changedTouches.length : 0, target: kind, cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented, eventPhase: ev.eventPhase });
  }

  function handleSecretLongPress(ev) {
    if (ev.type === "touchstart") {
      cancelSecretLongPress();
      const t = ev.touches && ev.touches[0];
      if (!t || ev.touches.length !== 1 || !isInSecretLongPressZone(t)) return;
      secretLongPressActive = true;
      secretLongPressStart = { x: t.clientX, y: t.clientY };
      secretLongPressTimer = window.setTimeout(() => {
        if (!secretLongPressActive) return;
        cancelSecretLongPress();
        showPanel("secret-long-press");
      }, SECRET_LONG_PRESS_MS);
      return;
    }

    if (!secretLongPressActive) return;
    if (!ev.touches || ev.touches.length !== 1) {
      cancelSecretLongPress();
      return;
    }

    const t = ev.touches[0];
    if (ev.type === "touchmove") {
      const dx = Math.abs(t.clientX - secretLongPressStart.x);
      const dy = Math.abs(t.clientY - secretLongPressStart.y);
      if (!isInSecretLongPressZone(t) || dx > SECRET_LONG_PRESS_MOVE_TOLERANCE_PX || dy > SECRET_LONG_PRESS_MOVE_TOLERANCE_PX) cancelSecretLongPress();
    } else if (ev.type === "touchend" || ev.type === "touchcancel") {
      cancelSecretLongPress();
    }
  }

  function isInSecretLongPressZone(t) {
    return t.clientX >= 0 && t.clientY >= 0 && t.clientX <= SECRET_LONG_PRESS_ZONE_PX && t.clientY <= SECRET_LONG_PRESS_ZONE_PX;
  }

  function cancelSecretLongPress() {
    if (secretLongPressTimer !== null) window.clearTimeout(secretLongPressTimer);
    secretLongPressTimer = null;
    secretLongPressStart = null;
    secretLongPressActive = false;
  }

  function handleSecretLongPressPointer(ev) {
    if (ev.pointerType && ev.pointerType !== "touch") return;
    if (ev.type === "pointerdown") {
      cancelSecretLongPress();
      if (!isInSecretLongPressZone(ev)) return;
      secretLongPressActive = true;
      secretLongPressStart = { x: ev.clientX, y: ev.clientY };
      secretLongPressTimer = window.setTimeout(() => {
        if (!secretLongPressActive) return;
        cancelSecretLongPress();
        showPanel("secret-long-press");
      }, SECRET_LONG_PRESS_MS);
      return;
    }

    if (!secretLongPressActive) return;
    if (ev.type === "pointermove") {
      const dx = Math.abs(ev.clientX - secretLongPressStart.x);
      const dy = Math.abs(ev.clientY - secretLongPressStart.y);
      if (!isInSecretLongPressZone(ev) || dx > SECRET_LONG_PRESS_MOVE_TOLERANCE_PX || dy > SECRET_LONG_PRESS_MOVE_TOLERANCE_PX) cancelSecretLongPress();
    } else if (ev.type === "pointerup" || ev.type === "pointercancel" || ev.type === "pointerleave") {
      cancelSecretLongPress();
    }
  }

  function handlePointer(ev) {
    handleSecretLongPressPointer(ev);
    if (ev.type === "pointerdown") currentPointer = { pointerType: ev.pointerType, startX: ev.clientX, startY: ev.clientY, target: targetKind(ev.target), start: performance.now() };
    if ((ev.type === "pointerup" || ev.type === "pointercancel") && currentPointer) {
      currentPointer.dx = round(ev.clientX - currentPointer.startX);
      currentPointer.dy = round(ev.clientY - currentPointer.startY);
      currentPointer.duration_ms = round(performance.now() - currentPointer.start);
      logEvent("pointer-gesture", currentPointer);
      currentPointer = null;
    }
    logEvent(ev.type, { pointerType: ev.pointerType, target: targetKind(ev.target), cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented });
  }

  function installCanvasObserversWhenReady() {
    const tryInstall = () => {
      const c = findCanvas().primary;
      if (!c) return false;
      if (!webglListenersInstalled) {
        webglListenersInstalled = true;
        c.addEventListener("webglcontextlost", (ev) => {
          persistCausalEvent("webglcontextlost", { cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented });
          logEvent("webglcontextlost", { cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented });
        }, { passive: true });
        c.addEventListener("webglcontextrestored", (ev) => {
          persistCausalEvent("webglcontextrestored", { cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented });
          logEvent("webglcontextrestored", { cancelable: ev.cancelable, defaultPrevented: ev.defaultPrevented });
        }, { passive: true });
      }
      if (window.ResizeObserver) {
        const ro = new ResizeObserver(() => snapshot("ResizeObserver-canvas", false));
        ro.observe(c);
        if (c.parentElement) ro.observe(c.parentElement);
        observers.push(ro);
      }
      if (window.MutationObserver) {
        const mo = new MutationObserver(() => snapshot("MutationObserver-canvas", false));
        mo.observe(c, { attributes: true, attributeFilter: ["style", "class", "width", "height"] });
        if (c.parentElement) mo.observe(c.parentElement, { attributes: true, attributeFilter: ["style", "class"] });
        observers.push(mo);
      }
      logEvent("canvas-observers-installed", canvasInfo());
      return true;
    };
    if (tryInstall()) return;
    const interval = setInterval(() => { if (tryInstall()) clearInterval(interval); }, 100);
    timers.push(setTimeout(() => clearInterval(interval), 10000));
  }

  function installPerformanceObservers() {
    if (!window.PerformanceObserver) return;
    safe(() => {
      const po = new PerformanceObserver((list) => {
        list.getEntries().forEach((e) => {
          if (e.entryType === "longtask") logEvent("longtask", { duration: round(e.duration), startTime: round(e.startTime) });
        });
      });
      po.observe({ entryTypes: ["longtask"] });
      observers.push(po);
    });
    window.addEventListener("error", (ev) => report.errors.push(nowEvent("error", { message: ev.message, filename: safeName(ev.filename), lineno: ev.lineno, colno: ev.colno })), { passive: true });
    window.addEventListener("unhandledrejection", (ev) => report.errors.push(nowEvent("unhandledrejection", { reason: String(ev.reason && ev.reason.message ? ev.reason.message : ev.reason).slice(0, 240) })), { passive: true });
  }

  function installErrorHandlers() {
    window.addEventListener("error", (ev) => {
      persistCausalEvent("js-error", { message: ev.message, filename: safeName(ev.filename), lineno: ev.lineno, colno: ev.colno });
      report.errors.push(nowEvent("js-error", { message: ev.message, filename: safeName(ev.filename), lineno: ev.lineno, colno: ev.colno }));
      refreshPanel();
    }, { passive: true });
    window.addEventListener("unhandledrejection", (ev) => {
      persistCausalEvent("promise-rejection", { reason: String(ev.reason && ev.reason.message ? ev.reason.message : ev.reason).slice(0, 240) });
      report.errors.push(nowEvent("promise-rejection", { reason: String(ev.reason && ev.reason.message ? ev.reason.message : ev.reason).slice(0, 240) }));
      refreshPanel();
    }, { passive: true });
  }

  function safeName(url) {
    try {
      const u = new URL(url, location.href);
      return u.origin + "/" + u.pathname.split("/").pop();
    } catch (e) {
      return String(url || "").split("?")[0];
    }
  }

  function diagRequested() {
    return location.search.indexOf("bm_diag=1") >= 0 || location.hash.indexOf("bm_diag=1") >= 0;
  }

  function activationState() {
    return { url: diagRequested(), keyboard: "Ctrl+Shift+D", mobile: "3s long press top-left 150x150" };
  }

  function showPanel(reason) {
    panelVisible = true;
    let root = document.getElementById("bm-mobile-diag-root");
    if (!root) {
      root = document.createElement("div");
      root.id = "bm-mobile-diag-root";
      root.innerHTML = panelHtml();
      document.documentElement.appendChild(root);
      wirePanel(root);
    }
    root.classList.remove("bm-diag-hidden");
    logEvent("panel-open", { reason });
    snapshot("panel-open", true);
    refreshPanel();
  }

  function hidePanel() {
    panelVisible = false;
    const root = document.getElementById("bm-mobile-diag-root");
    if (root) root.classList.add("bm-diag-hidden");
    logEvent("panel-hide", {});
  }

  function panelHtml() {
    return '<div class="bm-diag-panel">' +
      '<div class="bm-diag-head"><span>BM Mobile Web Diagnostic</span><button data-action="hide">Hide</button></div>' +
      '<div class="bm-diag-body">' +
      '<div class="bm-diag-mode"><button data-action="mode">Mode: Standard</button><span id="bm-diag-health-strip"></span></div>' +
      '<div id="bm-diag-summary" class="bm-diag-grid"></div>' +
      '<div class="bm-diag-actions">' +
      '<button data-action="pause">Pause</button><button data-action="mark">Mark note</button><button data-action="copy-short">Copy short</button><button data-action="copy-summary-json">Copy summary JSON</button><button data-action="copy-json">Copy raw JSON</button><button data-action="download-json">Download JSON</button><button data-action="download-txt">Download TXT</button><button data-action="clear">Clear session</button><button data-action="raw">Show raw</button>' +
      '</div>' +
      '<textarea id="bm-diag-note" class="bm-diag-note" maxlength="180" placeholder="Short note"></textarea>' +
      '<div class="bm-diag-markers">' + markerButtons() + '</div>' +
      '<div class="bm-diag-section bm-diag-expert-only"><h3>Compare reports</h3><textarea id="bm-diag-compare-input" class="bm-diag-note" placeholder="Paste one or more diagnostic JSON reports here"></textarea><button data-action="compare">Compare pasted reports</button><div id="bm-diag-compare-result"></div></div>' +
      '<div class="bm-diag-section"><h3>Synthesis</h3><div id="bm-diag-synthesis" class="bm-diag-kv"></div></div>' +
      '<div class="bm-diag-section"><h3>Automatic findings</h3><div id="bm-diag-findings"></div></div>' +
      '<div class="bm-diag-section"><h3>Raw report</h3><pre id="bm-diag-raw" class="bm-diag-pre bm-diag-hidden"></pre></div>' +
      '</div></div>';
  }

  function markerButtons() {
    return ["Jeu trop haut observé", "Bas du jeu non visible", "Avant tentative de scroll", "Après tentative de scroll", "Avant pinch", "Après pinch", "Barre Safari visible", "Barre Safari masquée", "Avant rotation", "Après rotation", "Retour depuis arrière-plan", "Affichage correct", "Affichage incorrect"].map((m) => '<button data-marker="' + esc(m) + '">' + esc(m) + '</button>').join("");
  }

  function wirePanel(root) {
    root.addEventListener("click", (ev) => {
      const marker = ev.target.getAttribute && ev.target.getAttribute("data-marker");
      const action = ev.target.getAttribute && ev.target.getAttribute("data-action");
      if (marker) addManualMarker(marker);
      if (!action) return;
      if (action === "hide") hidePanel();
      if (action === "pause") togglePause(ev.target);
      if (action === "mode") toggleMode(ev.target);
      if (action === "mark") addManualMarker("Note libre");
      if (action === "copy-short") copyText(shortSummary());
      if (action === "copy-summary-json") copyText(JSON.stringify(summaryReport(), null, 2));
      if (action === "copy-json") copyText(JSON.stringify(finalReport(), null, 2));
      if (action === "download-json") download("json");
      if (action === "download-txt") download("txt");
      if (action === "clear") clearSession();
      if (action === "raw") toggleRaw(ev.target);
      if (action === "compare") comparePastedReports();
    });
  }

  function toggleMode(btn) {
    expertMode = !expertMode;
    btn.textContent = expertMode ? "Mode: Expert" : "Mode: Standard";
    const root = document.getElementById("bm-mobile-diag-root");
    if (root) root.classList.toggle("bm-diag-expert", expertMode);
    logEvent("mode-change", { expertMode });
    refreshPanel();
  }

  function addManualMarker(label) {
    const note = document.getElementById("bm-diag-note");
    const marker = nowEvent("manual-marker", { label, note: note ? note.value.slice(0, 180) : "", snapshot: snapshot("manual-marker", false) });
    report.manual_markers.push(marker);
    if (note) note.value = "";
    refreshPanel();
  }

  function togglePause(btn) {
    paused = !paused;
    btn.textContent = paused ? "Resume" : "Pause";
    logEvent(paused ? "paused" : "resumed", {});
  }

  function toggleRaw(btn) {
    rawVisible = !rawVisible;
    btn.textContent = rawVisible ? "Hide raw" : "Show raw";
    refreshPanel();
  }

  function clearSession() {
    report.timeline = [];
    report.touch_gestures = [];
    report.scroll_attempts = [];
    report.manual_markers = [];
    report.automatic_findings = [];
    report.errors = [];
    logEvent("session-cleared", {});
    snapshot("after-clear", true);
  }

  function refreshPanel() {
    if (!panelVisible) return;
    const s = document.getElementById("bm-diag-summary");
    if (!s) return;
    const snap = report.final_snapshot || snapshot("panel-refresh", false);
    const c = snap.canvas || {};
    const vv = snap.visualViewport || {};
    updateCausalSignature();
    const standardRows = [
      kv("Session", sessionId),
      kv("Causal", report.causal_diagnostic.current_signature),
      kv("Document boot", documentBootId + " #" + causalState.boot_count),
      kv("Browser", report.environment.browser_family),
      kv("Iframe", window === window.top ? "top-level" : "iframe"),
      kv("Orientation", JSON.stringify(snap.orientation)),
      kv("inner", snap.viewport.innerWidth + " x " + snap.viewport.innerHeight),
      kv("visualViewport", typeof vv === "object" ? vv.width + " x " + vv.height + " scale " + vv.scale : "unsupported"),
      kv("Canvas", c.present ? c.rect.width + " x " + c.rect.height + " top " + c.rect.top + " bottom " + c.rect.bottom : "missing"),
      kv("Visible canvas", c.visible_percent === null || c.visible_percent === undefined ? "n/a" : c.visible_percent + "%"),
      kv("Health", averageHealth() + "/100"),
      kv("Findings", report.automatic_findings.length + ", errors " + report.errors.length),
    ];
    const expertRows = [
      kv("Scroll", "Y " + scrollY + " / doc " + (document.scrollingElement ? document.scrollingElement.scrollHeight : "?")),
      kv("Events", "resize " + resizeCount + ", vv " + visualViewportCount + ", rot " + orientationCount),
      kv("Touch", activeTouches + " active, last " + lastEvent),
      kv("Deltas", compactDeltas(snap.deltas)),
      kv("Milestones", JSON.stringify(flightMilestones())),
      kv("Godot viewport", JSON.stringify(c.godot_viewport_observation || "missing")),
      kv("History sizes", Object.keys(report.histories).map((k) => k + ":" + report.histories[k].length).join(", ")),
      kv("Technical fingerprint", report.environment.technical_fingerprint),
      kv("Previous boot", JSON.stringify(report.causal_diagnostic.previous_boot || "none")),
    ];
    s.innerHTML = (expertMode ? standardRows.concat(expertRows) : standardRows).join("");
    const health = document.getElementById("bm-diag-health-strip");
    if (health) health.innerHTML = healthStrip();
    const synthesis = document.getElementById("bm-diag-synthesis");
    if (synthesis) synthesis.textContent = report.synthesis || "";
    const findings = document.getElementById("bm-diag-findings");
    if (findings) {
      findings.innerHTML = report.automatic_findings.length ? report.automatic_findings.map((f) => '<div class="bm-diag-warn"><b>' + esc(f.level) + " / " + esc(f.code) + "</b><br>" + esc(f.message) + "</div>").join("") : '<div class="bm-diag-kv">No findings yet.</div>';
    }
    const raw = document.getElementById("bm-diag-raw");
    if (raw) {
      raw.classList.toggle("bm-diag-hidden", !rawVisible);
      if (rawVisible) raw.textContent = JSON.stringify(finalReport(), null, 2);
    }
  }

  function compactDeltas(deltas) {
    if (!deltas) return "n/a";
    return Object.keys(deltas).map((k) => k + "=" + deltas[k].value + (deltas[k].unit || "") + "/" + deltas[k].severity).join("; ");
  }

  function averageHealth() {
    const scores = Object.values(report.health_scores || {}).map((s) => s.score).filter((n) => typeof n === "number");
    if (!scores.length) return "?";
    return Math.round(scores.reduce((a, b) => a + b, 0) / scores.length);
  }

  function healthStrip() {
    return Object.keys(report.health_scores || {}).map((k) => {
      const h = report.health_scores[k];
      return '<span class="bm-diag-health bm-diag-health-' + esc(h.status) + '">' + esc(k) + " " + esc(h.score) + "</span>";
    }).join("");
  }

  function flightMilestones() {
    return {
      script_load: 0,
      first_canvas_seen_ms: firstCanvasSeenAt === null ? null : round(firstCanvasSeenAt),
      first_non_zero_canvas_ms: firstNonZeroCanvasAt === null ? null : round(firstNonZeroCanvasAt),
      first_resize_ms: firstResizeAt === null ? null : round(firstResizeAt),
      first_visualViewport_resize_ms: firstVisualViewportResizeAt === null ? null : round(firstVisualViewportResizeAt),
      first_touch_ms: firstTouchAt === null ? null : round(firstTouchAt),
      first_drag_ms: firstDragAt === null ? null : round(firstDragAt),
      first_pinch_ms: firstPinchAt === null ? null : round(firstPinchAt),
    };
  }

  function kv(k, v) {
    return '<div class="bm-diag-kv"><b>' + esc(k) + "</b>" + esc(String(v)) + "</div>";
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }

  function finalReport() {
    report.final_snapshot = report.final_snapshot || snapshot("final-report", true);
    report.performance_summary = {
      slow_frames_startup: slowFrames,
      resize_count: resizeCount,
      visualViewport_event_count: visualViewportCount,
      orientation_count: orientationCount,
      timeline_events: report.timeline.length,
      touch_gestures: report.touch_gestures.length,
      navigation: safe(() => performance.getEntriesByType("navigation").map((e) => ({ type: e.type, domContentLoadedEventEnd: round(e.domContentLoadedEventEnd), loadEventEnd: round(e.loadEventEnd), duration: round(e.duration) })), []),
      resources_failed_note: "Resource payloads are not inspected; browser console remains authoritative for failed loads.",
    };
    updateCausalSignature();
    report.flight_recorder_milestones = flightMilestones();
    report.causal_diagnostic.storage_tail = readCausalTail();
    report.analysis_model = {
      levels: ["PROUVÉ PAR MESURE DE CETTE SESSION", "INDICE FORT", "HYPOTHÈSE", "NON MESURABLE DANS CE CONTEXTE", "INFORMATION"],
      rule: "Findings are limited to local measurements; cross-browser causality requires comparing multiple reports.",
    };
    return report;
  }

  function summaryReport() {
    const full = finalReport();
    return {
      diagnostic_version: full.diagnostic_version,
      session_metadata: full.session_metadata,
      environment: {
        browser_family: full.environment.browser_family,
        technical_fingerprint: full.environment.technical_fingerprint,
        iframe: full.environment.iframe,
        screen: full.environment.screen,
        media: full.environment.media,
      },
      final_snapshot: full.final_snapshot,
      deltas: full.final_snapshot ? full.final_snapshot.deltas : {},
      health_scores: full.health_scores,
      synthesis: full.synthesis,
      automatic_findings: full.automatic_findings,
      causal_diagnostic: full.causal_diagnostic,
      flight_recorder_milestones: full.flight_recorder_milestones,
      comparison: full.comparison,
      privacy_statement: full.privacy_statement,
    };
  }

  function shortSummary() {
    const snap = report.final_snapshot || snapshot("short-summary", true);
    return [
      "Basket Manager mobile diagnostic short report",
      "session=" + sessionId,
      "browser=" + report.environment.browser_family,
      "fingerprint=" + report.environment.technical_fingerprint,
      "iframe=" + (window === window.top ? "top-level" : "iframe"),
      "orientation=" + JSON.stringify(snap.orientation),
      "inner=" + snap.viewport.innerWidth + "x" + snap.viewport.innerHeight,
      "visualViewport=" + JSON.stringify(snap.visualViewport),
      "canvas=" + JSON.stringify(snap.canvas && snap.canvas.rect),
      "canvasVisiblePercent=" + (snap.canvas ? snap.canvas.visible_percent : "n/a"),
      "scrollY=" + scrollY,
      "causal=" + report.causal_diagnostic.current_signature,
      "documentBoot=" + documentBootId + " #" + causalState.boot_count,
      "previousBoot=" + JSON.stringify(report.causal_diagnostic.previous_boot || null),
      "findings=" + report.automatic_findings.map((f) => f.level + ":" + f.code).join(", "),
      "health=" + JSON.stringify(report.health_scores),
      "synthesis=" + report.synthesis,
      "privacy=no network/no cookies/no localStorage/no IndexedDB/no saves/sessionStorage causal markers only",
    ].join("\n");
  }

  function updateCausalSignature() {
    if (godotStatusWasHidden && document.getElementById("status")) {
      report.causal_diagnostic.current_signature = "SAME_DOCUMENT_GODOT_RESTART";
      persistCausalEvent("same-document-godot-status-reappeared", {});
    } else if (report.causal_diagnostic.current_signature !== "SAME_DOCUMENT_GODOT_RESTART") {
      report.causal_diagnostic.current_signature = causalState.initial_signature;
    }
    return report.causal_diagnostic.current_signature;
  }

  function readCausalTail() {
    try {
      if (!window.sessionStorage) return [];
      const raw = sessionStorage.getItem(CAUSAL_STORAGE_KEY);
      const store = raw ? JSON.parse(raw) : {};
      return {
        boot_count: store.boot_count || 0,
        current_document_boot_id: store.current_document_boot_id || null,
        previous_session_id: store.previous_session_id || null,
        boots: (Array.isArray(store.boots) ? store.boots : []).slice(-3),
        events: (Array.isArray(store.events) ? store.events : []).slice(-12),
      };
    } catch (e) {
      return { error: e.name || "Error" };
    }
  }

  function observeGodotStatus() {
    if (!window.MutationObserver) return;
    const scan = () => {
      const present = !!document.getElementById("status");
      if (present && godotStatusWasHidden) {
        persistCausalEvent("same-document-godot-status-reappeared", {});
        report.causal_diagnostic.current_signature = "SAME_DOCUMENT_GODOT_RESTART";
      }
      if (present) godotStatusSeen = true;
      if (!present && godotStatusSeen && !godotStatusWasHidden) {
        godotStatusWasHidden = true;
        persistCausalEvent("godot_status_removed", {});
      }
    };
    scan();
    const mo = new MutationObserver(scan);
    mo.observe(document.documentElement, { childList: true, subtree: true });
    observers.push(mo);
  }

  observeGodotStatus();

  function comparePastedReports() {
    const input = document.getElementById("bm-diag-compare-input");
    const out = document.getElementById("bm-diag-compare-result");
    const text = input ? input.value.trim() : "";
    const parsed = parseReports(text);
    if (!parsed.length) {
      if (out) out.innerHTML = '<div class="bm-diag-warn">No valid diagnostic JSON report found.</div>';
      return;
    }
    const current = finalReport();
    const result = compareReports([current].concat(parsed));
    report.comparison = result;
    if (out) out.innerHTML = '<pre class="bm-diag-pre">' + esc(JSON.stringify(result, null, 2)) + "</pre>";
    logEvent("reports-compared", { count: parsed.length + 1 });
    refreshPanel();
  }

  function parseReports(text) {
    const reports = [];
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) parsed.forEach((r) => { if (r && r.diagnostic_version) reports.push(r); });
      else if (parsed && parsed.diagnostic_version) reports.push(parsed);
      return reports;
    } catch (e) {
      const chunks = text.split(/\n(?=\s*\{)/);
      chunks.forEach((chunk) => {
        try {
          const r = JSON.parse(chunk);
          if (r && r.diagnostic_version) reports.push(r);
        } catch (_e) {}
      });
      return reports;
    }
  }

  function compareReports(reports) {
    const fields = [
      ["browser", (r) => r.environment && r.environment.browser_family],
      ["fingerprint", (r) => r.environment && r.environment.technical_fingerprint],
      ["iframe_top", (r) => r.environment && r.environment.iframe && r.environment.iframe.is_top],
      ["innerHeight", (r) => r.final_snapshot && r.final_snapshot.viewport && r.final_snapshot.viewport.innerHeight],
      ["visualViewportHeight", (r) => r.final_snapshot && typeof r.final_snapshot.visualViewport === "object" && r.final_snapshot.visualViewport.height],
      ["canvasVisiblePercent", (r) => r.final_snapshot && r.final_snapshot.canvas && r.final_snapshot.canvas.visible_percent],
      ["healthAverage", (r) => averageHealthFrom(r.health_scores)],
      ["findingCodes", (r) => (r.automatic_findings || []).map((f) => f.code).sort().join(",")],
    ];
    const rows = reports.map((r, i) => {
      const row = { index: i, session: r.session_metadata && r.session_metadata.session_id };
      fields.forEach(([name, fn]) => { row[name] = fn(r); });
      return row;
    });
    const differences = {};
    fields.forEach(([name]) => {
      const values = rows.map((r) => String(r[name]));
      differences[name] = Array.from(new Set(values)).length > 1 ? "different" : "same";
    });
    const browserSpecificFindings = {};
    reports.forEach((r) => {
      const browser = r.environment && r.environment.browser_family || "unknown";
      browserSpecificFindings[browser] = Array.from(new Set((r.automatic_findings || []).map((f) => f.code)));
    });
    return {
      compared_reports: reports.length,
      rows,
      differences,
      browser_specific_findings: browserSpecificFindings,
      conclusion_level: reports.length >= 2 ? "INDICE FORT" : "INFORMATION",
      note: "Comparison uses only pasted local reports. It highlights differences; it does not assign root cause without repeated measurements.",
    };
  }

  function averageHealthFrom(scores) {
    const values = Object.values(scores || {}).map((s) => s.score).filter((n) => typeof n === "number");
    return values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : null;
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => logEvent("copy-ok", { length: text.length })).catch(() => showRawFallback(text));
    } else {
      showRawFallback(text);
    }
  }

  function showRawFallback(text) {
    rawVisible = true;
    showPanel("copy-fallback");
    const raw = document.getElementById("bm-diag-raw");
    if (raw) {
      raw.classList.remove("bm-diag-hidden");
      raw.textContent = text;
      raw.focus();
    }
  }

  function download(kind) {
    const content = kind === "json" ? JSON.stringify(finalReport(), null, 2) : shortSummary() + "\n\nFindings:\n" + report.automatic_findings.map((f) => "- " + f.level + " " + f.code + ": " + f.message).join("\n");
    const blob = new Blob([content], { type: kind === "json" ? "application/json" : "text/plain" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename(kind);
    document.body.appendChild(a);
    a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500);
  }

  function filename(kind) {
    const stamp = new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
    const fam = report.environment.browser_family.replace(/[^A-Za-z0-9]+/g, "_");
    const orient = matchMedia("(orientation: portrait)").matches ? "portrait" : "landscape";
    return "bm-mobile-diag_" + stamp + "_" + fam + "_" + orient + "." + kind;
  }
})();
/* BM_TEMP_MOBILE_DIAG_END js */
