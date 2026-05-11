/* ================================================================
   CONFIGURABLE FSM — script.js v3
   BCS-307 Digital Systems · Full scenario coverage + 5-btn panel
   ================================================================ */

/* ─────────────────────────────────────────────
   TAB NAVIGATION
───────────────────────────────────────────── */
function switchTab(tabId) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  const tab = document.getElementById('tab-' + tabId);
  const btn = document.querySelector(`[data-tab="${tabId}"]`);
  if (tab) tab.classList.add('active');
  if (btn) btn.classList.add('active');
  document.getElementById('main-nav').classList.remove('open');
  window.scrollTo({ top: 0, behavior: 'smooth' });
  const fsmTabs = ['traffic','vending','elevator','serial'];
  if (fsmTabs.includes(tabId)) setTimeout(() => startFSMAnimation(tabId), 80);
}

document.querySelectorAll('.nav-btn').forEach(btn => {
  btn.addEventListener('click', () => switchTab(btn.dataset.tab));
});
document.getElementById('hamburger').addEventListener('click', () => {
  document.getElementById('main-nav').classList.toggle('open');
});

function toggleQA(el) {
  const answer = el.nextElementSibling;
  const open = el.classList.contains('open');
  el.classList.toggle('open', !open);
  answer.style.display = open ? 'none' : 'block';
}

/* ─────────────────────────────────────────────
   WAVEFORM DATA
───────────────────────────────────────────── */
const WAVEFORM_DATA = {
  traffic: {
    title: 'Traffic Light FSM — GHDL/VCD Simulation',
    totalCycles: 24,
    signals: [
      { name:'clk',          type:'clock', cycles:24 },
      { name:'reset',        type:'bit',   values:[1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'event_code',   type:'bus',
        values:['0','0','2','0','0','0','4','0','0','0','4','0','0','0','1','0','0','0','4','0','0','4','0','0'],
        labels:['—','—','car','—','—','—','tmr','—','—','—','tmr','—','—','—','ped_GRN','—','—','—','tmr','—','—','tmr','—','—'] },
      { name:'fsm_busy',     type:'bit',   values:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,1,0,0] },
      { name:'state_code',   type:'bus',
        values:['0','0','0','1','1','1','1','2','2','2','2','3','3','3','3','4','4','4','4','5','5','5','1','1'],
        labels:['IDLE','IDLE','IDLE','RED','RED','RED','RED','GRN','GRN','GRN','GRN','YEL','YEL','YEL','YEL','PW','PW','PW','PW','PC','PC','PC','RED','RED'] },
      { name:'red_led',      type:'bit',   values:[0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1] },
      { name:'green_led',    type:'bit',   values:[0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'yellow_led',   type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0] },
      { name:'ped_signal',   type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0] },
      { name:'output_valid', type:'bit',   values:[0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,1,0,0] },
      { name:'timer_start',  type:'bit',   values:[0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,0] },
    ]
  },
  vending: {
    title: 'Vending Machine FSM — GHDL/VCD Simulation',
    totalCycles: 22,
    signals: [
      { name:'clk',           type:'clock', cycles:22 },
      { name:'reset',         type:'bit',   values:[1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0] },
      { name:'coin_insert',   type:'bit',   values:[0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0] },
      { name:'selection_btn', type:'bus',
        values:['0','0','0','0','2','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0'],
        labels:['—','—','—','—','B','—','—','—','—','—','—','—','—','—','—','—','—','—','—','—','—','—'] },
      { name:'cancel_btn',    type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1] },
      { name:'dispense_done', type:'bit',   values:[0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'change_done',   type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0] },
      { name:'event_code',    type:'bus',
        values:['0','0','1','0','2','0','0','0','0','16','0','0','64','0','0','0','0','0','0','0','1','32'],
        labels:['—','—','coin','—','sel','—','—','—','—','disp_dn','—','—','chg_dn','—','—','—','—','—','—','—','coin','CANCEL'] },
      { name:'fsm_busy',      type:'bit',   values:[0,0,1,0,1,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,1,1] },
      { name:'state_code',    type:'bus',
        values:['0','0','0','2','2','1','1','1','3','3','4','4','4','0','0','0','0','0','0','0','0','0'],
        labels:['IDLE','IDLE','IDLE','COLL','COLL','SEL','SEL','SEL','DISP','DISP','CHG','CHG','CHG','IDLE','IDLE','IDLE','IDLE','IDLE','IDLE','IDLE','COLL','IDLE'] },
      { name:'dispense_motor',type:'bit',   values:[0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'change_return', type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,1] },
      { name:'output_valid',  type:'bit',   values:[0,0,0,1,0,1,0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,1] },
    ]
  },
  elevator: {
    title: 'Elevator FSM — GHDL/VCD Simulation',
    totalCycles: 26,
    signals: [
      { name:'clk',           type:'clock', cycles:26 },
      { name:'reset',         type:'bit',   values:[1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'floor_req',     type:'bus',
        values:['1','1','5','5','5','5','5','5','5','5','0','0','0','1','1','1','1','1','1','0','0','0','0','0','0','0'],
        labels:['F1','F1','→F5','→F5','→F5','→F5','→F5','→F5','→F5','→F5','—','—','—','→F1','→F1','→F1','→F1','→F1','→F1','—','—','—','—','—','—','—'] },
      { name:'emergency_btn', type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0] },
      { name:'event_code',    type:'bus',
        values:['0','0','1','0','0','0','0','0','4','0','8','0','0','2','0','0','0','0','4','0','8','64','0','0','0','0'],
        labels:['—','—','go↑','—','—','—','—','—','arr','—','clr','—','—','go↓','—','—','—','—','arr','—','clr','EMRG','—','—','—','—'] },
      { name:'fsm_busy',      type:'bit',   values:[0,0,1,0,0,0,0,0,1,0,1,0,0,1,0,0,0,0,1,0,1,1,0,0,0,0] },
      { name:'state_code',    type:'bus',
        values:['0','0','0','1','1','1','1','1','1','3','3','4','0','0','2','2','2','2','2','3','4','0','0','0','0','0'],
        labels:['IDLE','IDLE','IDLE','MV↑','MV↑','MV↑','MV↑','MV↑','MV↑','D.OPN','D.OPN','D.CLS','IDLE','IDLE','MV↓','MV↓','MV↓','MV↓','MV↓','D.OPN','D.CLS','IDLE!','IDLE','IDLE','IDLE','IDLE'] },
      { name:'motor_up',      type:'bit',   values:[0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'motor_down',    type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0] },
      { name:'door_open',     type:'bit',   values:[0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0] },
      { name:'floor_display', type:'bus',
        values:['1','1','1','2','3','4','5','5','5','5','5','5','5','5','4','3','2','1','1','1','1','1','1','1','1','1'],
        labels:['F1','F1','F1','F2','F3','F4','F5','F5','F5','F5','F5','F5','F5','F5','F4','F3','F2','F1','F1','F1','F1','F1','F1','F1','F1','F1'] },
      { name:'alarm_buzzer',  type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0] },
      { name:'output_valid',  type:'bit',   values:[0,0,0,1,0,0,0,0,0,1,0,1,0,0,0,0,0,0,1,0,1,1,0,0,0,0] },
    ]
  },
  serial: {
    title: 'Serial Comm FSM — GHDL/VCD Simulation',
    totalCycles: 26,
    signals: [
      { name:'clk',          type:'clock', cycles:26 },
      { name:'reset',        type:'bit',   values:[1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'rx_valid',     type:'bit',   values:[0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,0,0,0] },
      { name:'event_code',   type:'bus',
        values:['0','0','256','0','256','0','256','0','256','0','256','0','256','0','256','0','256','0','256','0','256','0','512','0','0','0'],
        labels:['—','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','rx↑','—','tx_rdy','—','—','—'] },
      { name:'rx_data[0]',   type:'bus',
        values:['0','0','1','1','0','0','1','1','0','0','1','1','0','0','1','1','0','0','1','1','0','0','0','0','0','0'],
        labels:['0','0','1','','0','','1','','0','','1','','0','','1','','0','','1','','0','','','','',''] },
      { name:'state_code',   type:'bus',
        values:['0','0','0','1','1','2','2','3','3','4','4','5','5','6','6','7','7','8','8','9','9','10','11','11','0','0'],
        labels:['IDLE','IDLE','IDLE','START','START','B0','B0','B1','B1','B2','B2','B3','B3','B4','B4','B5','B5','B6','B6','B7','B7','STOP','DONE','DONE','IDLE','IDLE'] },
      { name:'rx_parity_ok', type:'bit',   values:[0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0] },
      { name:'tx_enable',    type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0] },
      { name:'parity_err',   type:'bit',   values:[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] },
      { name:'fsm_busy',     type:'bit',   values:[0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,0,0] },      { name:'output_valid', type:'bit',   values:[0,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1,0,0,0] },
    ]
  }
};

function selectWaveform(name, buttonEl) {
  const container = buttonEl ? buttonEl.closest('.waveform-container') : null;
  if (container) {
    container.querySelectorAll('.wf-btn').forEach(b => b.classList.remove('active'));
    buttonEl.classList.add('active');
    renderWaveformInContainer(name, container.querySelector('.waveform-display'));
  } else {
    renderWaveformInContainer(name, document.getElementById('waveform-display'));
  }
}

function renderWaveform(name) {
  renderWaveformInContainer(name, document.getElementById('waveform-display'));
}

function renderWaveformInContainer(name, container, highlightCycle) {
  if (!container) return;
  const data = WAVEFORM_DATA[name];
  if (!data) return;
  const N = data.totalCycles;
  const W = 100 / N;

  container.innerHTML = `<div class="wf-title">${data.title}</div>`;

  // Ruler row
  const ruler = document.createElement('div');
  ruler.className = 'wf-signal-row';
  let rulerTrack = '';
  for (let i = 0; i < N; i++) {
    const hl = (highlightCycle !== undefined && i === highlightCycle) ? 'background:rgba(0,245,255,0.12);' : '';
    rulerTrack += `<div class="wf-segment" style="left:${i*W}%;width:${W}%;${hl}border-right:1px solid rgba(71,85,105,0.2)"><span style="font-size:0.5rem;color:var(--text-muted);position:absolute;top:1px;left:2px">${i}</span></div>`;
  }
  ruler.innerHTML = `<div class="wf-signal-name" style="font-size:0.6rem;color:var(--text-muted)">CYCLE</div><div class="wf-signal-track" style="min-width:560px;position:relative">${rulerTrack}</div>`;
  container.appendChild(ruler);

  data.signals.forEach(sig => {
    const row = document.createElement('div');
    row.className = 'wf-signal-row';
    let track = '';

    if (sig.type === 'clock') {
      for (let i = 0; i < N; i++) {
        const l = i * W, hw = W / 2;
        const isCur = (highlightCycle !== undefined && i === highlightCycle);
        const glow = isCur ? 'filter:brightness(1.8);' : '';
        track += `<div class="wf-segment wf-clock-high" style="left:${l}%;width:${hw}%;${glow}"></div>`;
        track += `<div class="wf-segment wf-clock-low"  style="left:${l+hw}%;width:${hw}%;${glow}"></div>`;
      }
    } else if (sig.type === 'bit') {
      for (let i = 0; i < N; i++) {
        const isCur = (highlightCycle !== undefined && i === highlightCycle);
        const changed = i > 0 && sig.values[i] !== sig.values[i-1];
        const hl = isCur ? 'filter:brightness(2.2);box-shadow:0 0 6px rgba(0,245,255,0.6);' : '';
        const chMark = changed ? 'border-left:2px solid rgba(255,232,77,0.9);' : '';
        track += `<div class="wf-segment ${sig.values[i] ? 'wf-seg-high' : 'wf-seg-low'}" style="left:${i*W}%;width:${W}%;${hl}${chMark}"></div>`;
      }
    } else {
      let s = 0, cv = sig.values[0], cl = (sig.labels || sig.values)[0];
      for (let i = 1; i <= N; i++) {
        if (i === N || sig.values[i] !== cv) {
          const isCurSpan = (highlightCycle !== undefined && highlightCycle >= s && highlightCycle < i);
          const hl = isCurSpan ? 'filter:brightness(1.8);box-shadow:inset 0 0 8px rgba(0,245,255,0.25);' : '';
          const borderLeft = s > 0 ? 'border-left:2px solid rgba(255,232,77,0.7);' : '';
          track += `<div class="wf-segment wf-seg-bus" style="left:${s*W}%;width:${(i-s)*W}%;${hl}${borderLeft}"><span class="wf-seg-bus-label">${cl}</span></div>`;
          if (i < N) { cv = sig.values[i]; cl = (sig.labels || sig.values)[i]; s = i; }
        }
      }
    }

    // Cursor line with stronger glow
    if (highlightCycle !== undefined) {
      const cx = highlightCycle * W + W / 2;
      track += `<div style="position:absolute;left:${cx}%;top:0;width:2px;height:100%;background:rgba(0,245,255,0.9);pointer-events:none;z-index:5;box-shadow:0 0 10px rgba(0,245,255,1),0 0 20px rgba(0,245,255,0.5)"></div>`;
    }
    row.innerHTML = `<div class="wf-signal-name">${sig.name}</div><div class="wf-signal-track" style="min-width:560px;position:relative">${track}</div>`;
    container.appendChild(row);
  });

  // ── Auto-append legend at bottom of every waveform ──
  const legend = document.createElement('div');
  legend.className = 'wf-auto-legend';
  legend.innerHTML =
    `<span class="wf-leg-item"><span class="wf-dot clk"></span>Clock</span>` +
    `<span class="wf-leg-item"><span class="wf-dot high"></span>HIGH&nbsp;(1)</span>` +
    `<span class="wf-leg-item"><span class="wf-dot low"></span>LOW&nbsp;(0)</span>` +
    `<span class="wf-leg-item"><span class="wf-dot bus"></span>Bus&nbsp;value</span>` +
    `<span class="wf-leg-item wf-leg-cursor"><span class="wf-dot cursor"></span>Active&nbsp;cycle&nbsp;cursor</span>` +
    `<span class="wf-leg-item wf-leg-change"><span class="wf-dot change"></span>Signal&nbsp;transition</span>`;
  container.appendChild(legend);
}

/* ─────────────────────────────────────────────
   FSM SEQUENCES — all states + edge cases
───────────────────────────────────────────── */
const FSM_SEQUENCES = {

  traffic: {
    states: [
      { name:'IDLE',      color:'#6b7280' },
      { name:'RED',       color:'#ff4f6e' },
      { name:'GREEN',     color:'#39ff8f' },
      { name:'YELLOW',    color:'#ffe84d' },
      { name:'PED_WAIT',  color:'#4fc3f7' },
      { name:'PED_CROSS', color:'#b57bff' },
    ],
    wfName: 'traffic',
    sequence: [
      { state:0, event:'power_on',      wfCycle:0,  desc:'Power on. FSM → IDLE. All lights off — intersection inactive.',
        out:{red:0,yel:0,grn:0,ped:0}, carPos:'off', pedVis:false, emergency:false },
      { state:1, event:'car_sensor',    wfCycle:3,  desc:'Car sensor triggered. FSM → RED. Red light ON — all vehicles must stop immediately.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:false, emergency:false },
      { state:2, event:'timer_expire',  wfCycle:7,  desc:'Red phase timer expired. FSM → GREEN. Green light ON — vehicles may proceed through intersection.',
        out:{red:0,yel:0,grn:1,ped:0}, carPos:'moving', pedVis:false, emergency:false },
      { state:3, event:'timer_expire',  wfCycle:11, desc:'Green phase timer expired. FSM → YELLOW. Warning signal — vehicles should begin stopping.',
        out:{red:0,yel:1,grn:0,ped:0}, carPos:'slowing', pedVis:false, emergency:false },
      { state:1, event:'timer_expire',  wfCycle:15, desc:'Yellow timer expired. FSM → RED again. Normal 3-phase cycle repeats continuously.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:false, emergency:false },
      { state:4, event:'ped_btn(RED)',  wfCycle:15, desc:'Pedestrian button pressed while RED. FSM → PED_WAIT. Red held, pedestrian crossing queued.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:true, emergency:false },
      { state:5, event:'timer_expire',  wfCycle:19, desc:'PED_WAIT timer expired. FSM → PED_CROSS. Walk signal ON — pedestrians crossing now. Red stays on for vehicles.',
        out:{red:1,yel:0,grn:0,ped:1}, carPos:'stopped', pedVis:true, emergency:false },
      // ── Step 9: GREEN → RED via pedestrian_btn ──
      { state:1, event:'ped_btn=1(GRN)', wfCycle:14, desc:'Pedestrian button pressed while GREEN. FSM → RED directly (GREEN→RED on ped_btn=1). Green ends immediately; vehicles stop.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:true, emergency:false },
      // ── Step 10: RED → PED_WAIT via pedestrian_btn ──
      { state:4, event:'ped_btn=1',      wfCycle:15, desc:'Now in RED. Pedestrian button again → PED_WAIT. Walk phase queued.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:true, emergency:false },
      // ── Step 11: PED_WAIT → PED_CROSS ──
      { state:5, event:'timer_done=1',   wfCycle:19, desc:'PED_WAIT timer expires → PED_CROSS. Walk signal ON. Ped crossing from GREEN→RED→PED_WAIT path verified.',
        out:{red:1,yel:0,grn:0,ped:1}, carPos:'stopped', pedVis:true, emergency:false },
      // ── Step 12: PED_CROSS → RED ──
      { state:1, event:'timer_done=1',   wfCycle:22, desc:'PED_CROSS timer expires → RED. Walk signal OFF. Back to normal red phase.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:false, emergency:false },
      { state:0, event:'emergency!',    wfCycle:0,  desc:'🚨 EMERGENCY VEHICLE approaching. ROM interrupt entry forces FSM → IDLE. All lights OFF immediately.',
        out:{red:0,yel:0,grn:0,ped:0}, carPos:'off', pedVis:false, emergency:true },
      { state:1, event:'clear+car',     wfCycle:3,  desc:'Emergency cleared. Car sensor fires. Normal operation resumes from RED phase.',
        out:{red:1,yel:0,grn:0,ped:0}, carPos:'stopped', pedVis:false, emergency:false },
    ]
  },

  vending: {
    states: [
      { name:'IDLE',     color:'#6b7280' },
      { name:'SELECT',   color:'#4fc3f7' },
      { name:'COLLECT',  color:'#ffe84d' },
      { name:'DISPENSE', color:'#39ff8f' },
      { name:'CHANGE',   color:'#b57bff' },
    ],
    wfName: 'vending',
    sequence: [
      { state:0, event:'power_on',       wfCycle:0,  desc:'Machine IDLE — display shows welcome screen. Waiting for customer to insert a coin.',
        screen:'WELCOME\nINSERT COIN', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:2, event:'coin_insert',    wfCycle:3,  desc:'FSM → COLLECT. First coin inserted. Machine counting coin value and updating balance display.',
        screen:'BALANCE\n0.50 AED', coins:1, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:2, event:'coin_insert_2',  wfCycle:3,  desc:'Still in COLLECT (HOLD). Second coin inserted. Balance increases. Machine stays in COLLECT until item price met.',
        screen:'BALANCE\n1.00 AED', coins:2, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:2, event:'insufficient',   wfCycle:3,  desc:'⚠ Insufficient balance for selected item. FSM stays COLLECT (hold_state=1 in ROM). Insert more coins.',
        screen:'INSERT\nMORE COINS', coins:2, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:2, event:'coin_insert_3',  wfCycle:3,  desc:'Third coin inserted. Balance now sufficient for item selection.',
        screen:'BALANCE\n1.50 AED', coins:3, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:1, event:'selection',      wfCycle:5,  desc:'FSM → SELECT. Balance sufficient. Item menu shown. Customer browses available products.',
        screen:'SELECT\nITEM 1-4', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:4, event:'item_empty',     wfCycle:10, desc:'⚠ Item EMPTY in stock! FSM skips DISPENSE → goes directly to CHANGE. Full refund issued automatically.',
        screen:'SORRY!\nOUT OF STOCK', coins:0, product:false, change:true, itemEmpty:true, cancelled:false, sel:0 },
      { state:0, event:'change_done',    wfCycle:13, desc:'Refund complete. FSM → IDLE. Out-of-stock edge case handled gracefully without crashing FSM.',
        screen:'REFUNDED\nTHANK YOU', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:2, event:'coin_insert',    wfCycle:3,  desc:'New customer. Coin inserted. FSM → COLLECT.',
        screen:'BALANCE\n1.50 AED', coins:2, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:1, event:'selection',      wfCycle:5,  desc:'FSM → SELECT. Menu shown. Customer selects item 2.',
        screen:'SELECT\nITEM 1-4', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:3, event:'sel_btn',        wfCycle:8,  desc:'Item 2 selected! FSM → DISPENSE. dispense_motor activated. Product released from tray.',
        screen:'DISPENSING\nPLEASE WAIT', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:1 },
      { state:4, event:'dispense_done',  wfCycle:10, desc:'dispense_done event fires. FSM → CHANGE. Product delivered. Calculating change amount.',
        screen:'CHANGE\nRETURNING ¢', coins:0, product:true, change:true, itemEmpty:false, cancelled:false, sel:1 },
      { state:0, event:'change_done',    wfCycle:13, desc:'Change fully returned. FSM → IDLE. Transaction complete! Customer collects product and change.',
        screen:'THANK YOU!\nENJOY 🥤', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:2, event:'coin_insert',    wfCycle:20, desc:'(Cancel path) New customer. Coin inserted. FSM → COLLECT.',
        screen:'BALANCE\n1.00 AED', coins:1, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
      { state:0, event:'CANCEL!',        wfCycle:21, desc:'🚫 CANCEL button pressed! VM_INTERRUPT_EVENT fires. FSM forced → IDLE. int_change_pulse asserts change_return.',
        screen:'CANCELLED\nREFUNDING', coins:0, product:false, change:true, itemEmpty:false, cancelled:true, sel:-1 },
      { state:0, event:'refund_done',    wfCycle:0,  desc:'Coins fully refunded via interrupt_return_detect logic. Machine idle. Interrupt pathway verified.',
        screen:'WELCOME\nINSERT COIN', coins:0, product:false, change:false, itemEmpty:false, cancelled:false, sel:-1 },
    ]
  },

  elevator: {
    states: [
      { name:'IDLE',       color:'#6b7280' },
      { name:'MOVE_UP',    color:'#4fc3f7' },
      { name:'MOVE_DOWN',  color:'#b57bff' },
      { name:'DOOR_OPEN',  color:'#39ff8f' },
      { name:'DOOR_CLOSE', color:'#ffe84d' },
    ],
    wfName: 'elevator',
    sequence: [
      { state:0, event:'power_on',     wfCycle:0,  desc:'Elevator IDLE at Floor 1. Motor off, doors closed. Waiting for floor request from call panel.',
        floor:1, doorOpen:false, dir:0, alarm:false, overload:false, queue:'—' },
      { state:1, event:'go_up(F5)',    wfCycle:3,  desc:'Floor 5 requested. FSM → MOVE_UP. motor_up asserted. Cabin begins ascending.',
        floor:1, doorOpen:false, dir:1, alarm:false, overload:false, queue:'F5' },
      { state:1, event:'moving',       wfCycle:4,  desc:'Ascending past Floor 2. floor_counter increments each clock cycle while in MOVE_UP.',
        floor:2, doorOpen:false, dir:1, alarm:false, overload:false, queue:'F5' },
      { state:1, event:'moving',       wfCycle:5,  desc:'Ascending past Floor 3.',
        floor:3, doorOpen:false, dir:1, alarm:false, overload:false, queue:'F5' },
      { state:1, event:'moving',       wfCycle:6,  desc:'Ascending past Floor 4.',
        floor:4, doorOpen:false, dir:1, alarm:false, overload:false, queue:'F5' },
      { state:3, event:'arrived(F5)',  wfCycle:9,  desc:'current_floor = target_floor. FSM → DOOR_OPEN. Motor off; door actuator opens. Passengers board.',
        floor:5, doorOpen:true, dir:0, alarm:false, overload:false, queue:'—' },
      { state:3, event:'door_sensor',  wfCycle:9,  desc:'⚠ Obstruction in doorway! door_sensor event fires HOLD entry. FSM stays DOOR_OPEN until clear.',
        floor:5, doorOpen:true, dir:0, alarm:false, overload:false, queue:'—' },
      { state:4, event:'door_clear',   wfCycle:11, desc:'Obstruction removed. door_clear event fires. FSM → DOOR_CLOSE. Door actuator closing.',
        floor:5, doorOpen:false, dir:0, alarm:false, overload:false, queue:'—' },
      { state:0, event:'auto',         wfCycle:12, desc:'Door fully closed (door_stable). FSM → IDLE automatically. Awaiting next request.',
        floor:5, doorOpen:false, dir:0, alarm:false, overload:false, queue:'—' },
      { state:2, event:'go_down(F1)',  wfCycle:14, desc:'Floor 1 requested. FSM → MOVE_DOWN. motor_down asserted. Cabin descending.',
        floor:5, doorOpen:false, dir:-1, alarm:false, overload:false, queue:'F1' },
      { state:2, event:'moving',       wfCycle:15, desc:'Descending past Floor 4.',
        floor:4, doorOpen:false, dir:-1, alarm:false, overload:false, queue:'F1' },
      { state:2, event:'moving',       wfCycle:16, desc:'Descending past Floor 3.',
        floor:3, doorOpen:false, dir:-1, alarm:false, overload:false, queue:'F1' },
      { state:2, event:'moving',       wfCycle:17, desc:'Descending past Floor 2.',
        floor:2, doorOpen:false, dir:-1, alarm:false, overload:false, queue:'F1' },
      { state:3, event:'arrived(F1)',  wfCycle:19, desc:'Arrived Floor 1. FSM → DOOR_OPEN. Passengers exit.',
        floor:1, doorOpen:true, dir:0, alarm:false, overload:false, queue:'—' },
      { state:3, event:'weight_sensor',wfCycle:19, desc:'⚠ OVERLOAD! weight_sensor event fires. alarm_buzzer asserted. FSM stays DOOR_OPEN — cannot close on overloaded car.',
        floor:1, doorOpen:true, dir:0, alarm:true, overload:true, queue:'—' },
      { state:4, event:'door_clear',   wfCycle:20, desc:'Overload resolved (passengers adjusted weight). FSM → DOOR_CLOSE. Alarm off.',
        floor:1, doorOpen:false, dir:0, alarm:false, overload:false, queue:'—' },
      { state:0, event:'auto',         wfCycle:0,  desc:'Door closed. FSM → IDLE at Floor 1. Normal operation restored.',
        floor:1, doorOpen:false, dir:0, alarm:false, overload:false, queue:'—' },
      { state:1, event:'go_up(F3)',    wfCycle:3,  desc:'New trip. Floor 3 requested. FSM → MOVE_UP.',
        floor:1, doorOpen:false, dir:1, alarm:false, overload:false, queue:'F3' },
      { state:1, event:'moving',       wfCycle:4,  desc:'Ascending past Floor 2.',
        floor:2, doorOpen:false, dir:1, alarm:false, overload:false, queue:'F3' },
      { state:0, event:'EMERGENCY!',   wfCycle:21, desc:'🚨 EMERGENCY stop button! EL_INTERRUPT_EVENT fires. FSM → IDLE immediately. Motor cut. alarm_buzzer ON.',
        floor:2, doorOpen:false, dir:0, alarm:true, overload:false, queue:'—' },
      { state:0, event:'emerg_clear',  wfCycle:0,  desc:'Emergency cleared. Cabin at Floor 2, safely stopped. Alarm off. Ready for normal operation.',
        floor:2, doorOpen:false, dir:0, alarm:false, overload:false, queue:'—' },
    ]
  },

  serial: {
    states: [
      {name:'SP_IDLE',     color:'#6b7280'},
      {name:'SP_START',    color:'#4fc3f7'},
      {name:'SP_BIT0',     color:'#b57bff'},
      {name:'SP_BIT1',     color:'#b57bff'},
      {name:'SP_BIT2',     color:'#b57bff'},
      {name:'SP_BIT3',     color:'#b57bff'},
      {name:'SP_BIT4',     color:'#b57bff'},
      {name:'SP_BIT5',     color:'#b57bff'},
      {name:'SP_BIT6',     color:'#b57bff'},
      {name:'SP_BIT7',     color:'#b57bff'},
      {name:'SP_STOP',     color:'#ffe84d'},
      {name:'SP_COMPLETE', color:'#39ff8f'},
    ],
    wfName: 'serial',
    sequence: [
      { state:0,  event:'idle',       wfCycle:0,  desc:'SP_IDLE — Monitoring rx_valid. No activity. Edge detector watching for rising edge of start bit.',
        ab:-1, bv:'-', bits:[], parityErr:false, done:false },
      { state:1,  event:'rx_valid↑',  wfCycle:3,  desc:'SP_START — Rising edge on rx_valid detected! Start bit confirmed. Frame reception begins. rx_latch cleared.',
        ab:-1, bv:'S', bits:[], parityErr:false, done:false },
      { state:2,  event:'rx_valid↑',  wfCycle:5,  desc:'SP_BIT0 — LSB sampled. rx_data[0]=1 → shifted into rx_latch. rx_latch = xxxxxxx1.',
        ab:0, bv:'1', bits:[1], parityErr:false, done:false },
      { state:3,  event:'rx_valid↑',  wfCycle:7,  desc:'SP_BIT1 — Bit 1 sampled = 0. rx_latch shifts right: 0xxxxxxx → xxxxxxx1 → 0xxxxxx1 → rx_latch = xxxxxx10.',
        ab:1, bv:'0', bits:[1,0], parityErr:false, done:false },
      { state:4,  event:'rx_valid↑',  wfCycle:9,  desc:'SP_BIT2 — Bit 2 sampled = 1. rx_latch = xxxxx101.',
        ab:2, bv:'1', bits:[1,0,1], parityErr:false, done:false },
      { state:5,  event:'rx_valid↑',  wfCycle:11, desc:'SP_BIT3 — Bit 3 sampled = 0. rx_latch = xxxx0101.',
        ab:3, bv:'0', bits:[1,0,1,0], parityErr:false, done:false },
      { state:6,  event:'rx_valid↑',  wfCycle:13, desc:'SP_BIT4 — Bit 4 sampled = 0. rx_latch = xxx00101.',
        ab:4, bv:'0', bits:[1,0,1,0,0], parityErr:false, done:false },
      { state:7,  event:'rx_valid↑',  wfCycle:15, desc:'SP_BIT5 — Bit 5 sampled = 1. rx_latch = xx100101.',
        ab:5, bv:'1', bits:[1,0,1,0,0,1], parityErr:false, done:false },
      { state:8,  event:'rx_valid↑',  wfCycle:17, desc:'SP_BIT6 — Bit 6 sampled = 0. rx_latch = x0100101.',
        ab:6, bv:'0', bits:[1,0,1,0,0,1,0], parityErr:false, done:false },
      { state:9,  event:'rx_valid↑',  wfCycle:19, desc:'SP_BIT7 — MSB sampled = 1. rx_latch = 10100101 = 0xA5. All 8 bits received LSB-first.',
        ab:7, bv:'1', bits:[1,0,1,0,0,1,0,1], parityErr:false, done:false },
      { state:10, event:'rx_valid↑',  wfCycle:21, desc:'SP_STOP — Stop bit HIGH received. XOR parity check: 1⊕0⊕1⊕0⊕0⊕1⊕0⊕1 = 0 → Even parity PASS.',
        ab:-1, bv:'1', bits:[1,0,1,0,0,1,0,1], parityErr:false, done:false },
      { state:11, event:'tx_ready↑',  wfCycle:22, desc:'SP_COMPLETE — Parity OK! rx_latch → tx_data. tx_enable asserted HIGH. Byte 0xA5 forwarded to transmitter.',
        ab:-1, bv:'✓', bits:[1,0,1,0,0,1,0,1], parityErr:false, done:true },
      { state:0,  event:'auto',       wfCycle:24, desc:'FSM → SP_IDLE. tx_enable clears. Ready for next serial frame. Frame throughput: 1 byte per 12 rx_valid edges.',
        ab:-1, bv:'-', bits:[], parityErr:false, done:false },
      // ── Parity error path ──
      { state:1,  event:'rx_valid↑',  wfCycle:3,  desc:'(Parity Error Demo) New frame. Start bit detected.',
        ab:-1, bv:'S', bits:[], parityErr:false, done:false },
      { state:2,  event:'rx_valid↑',  wfCycle:5,  desc:'BIT0 = 1 received.',
        ab:0, bv:'1', bits:[1], parityErr:false, done:false },
      { state:3,  event:'rx_valid↑',  wfCycle:7,  desc:'BIT1 = 1 received. (Bit error injected — will cause odd parity)',
        ab:1, bv:'1', bits:[1,1], parityErr:false, done:false },
      { state:4,  event:'rx_valid↑',  wfCycle:9,  desc:'BIT2 = 1 received.',
        ab:2, bv:'1', bits:[1,1,1], parityErr:false, done:false },
      { state:0,  event:'BAD_PARITY!',wfCycle:5,  desc:'🚨 PARITY ERROR! XOR(bits) = 1 (odd). SP_INTERRUPT_EVENT fires. FSM → IDLE. parity_err asserted HIGH for 1 cycle.',
        ab:-1, bv:'✗', bits:[1,1,1], parityErr:true, done:false },
      { state:0,  event:'idle',       wfCycle:0,  desc:'parity_err cleared. FSM back in SP_IDLE. Bad frame discarded. rx_data NOT forwarded. Waiting for clean frame.',
        ab:-1, bv:'-', bits:[], parityErr:false, done:false },
    ]
  }
};

/* ─────────────────────────────────────────────
   ANIMATION ENGINE
───────────────────────────────────────────── */
const A = {};

function initA(fsm) {
  A[fsm] = { step: 0, running: false, timer: null, speed: 1800 };
}

// ── Public button handlers ──
function fsmStart(fsm) {
  if (!A[fsm]) initA(fsm);
  _stopTimer(fsm);
  A[fsm].step = 0;
  A[fsm].running = true;
  _renderStep(fsm);
  _startTimer(fsm);
  _updateBtns(fsm);
}

function fsmPause(fsm) {
  if (!A[fsm]) return;
  _stopTimer(fsm);
  A[fsm].running = false;
  _updateBtns(fsm);
}

function fsmResume(fsm) {
  if (!A[fsm]) return;
  if (A[fsm].running) return;
  A[fsm].running = true;
  _startTimer(fsm);
  _updateBtns(fsm);
}

function fsmStep(fsm) {
  if (!A[fsm]) initA(fsm);
  _stopTimer(fsm);
  A[fsm].running = false;
  const seq = FSM_SEQUENCES[fsm].sequence;
  A[fsm].step = (A[fsm].step + 1) % seq.length;
  _renderStep(fsm);
  _updateBtns(fsm);
}

function fsmReset(fsm) {
  if (!A[fsm]) initA(fsm);
  _stopTimer(fsm);
  A[fsm].step = 0;
  A[fsm].running = false;
  _renderStep(fsm);
  _updateBtns(fsm);
}

function fsmSpeed(fsm, ms) {
  if (!A[fsm]) return;
  A[fsm].speed = parseInt(ms);
  if (A[fsm].running) { _stopTimer(fsm); _startTimer(fsm); }
}

function startFSMAnimation(fsm) {
  if (!A[fsm]) initA(fsm);
  if (A[fsm].running) return;
  A[fsm].step = 0;
  A[fsm].running = true;
  _renderStep(fsm);
  _startTimer(fsm);
  _updateBtns(fsm);
}

function _startTimer(fsm) {
  const seq = FSM_SEQUENCES[fsm].sequence;
  A[fsm].timer = setInterval(() => {
    A[fsm].step = (A[fsm].step + 1) % seq.length;
    _renderStep(fsm);
  }, A[fsm].speed);
}

function _stopTimer(fsm) {
  if (A[fsm] && A[fsm].timer) { clearInterval(A[fsm].timer); A[fsm].timer = null; }
}

function _updateBtns(fsm) {
  const r = A[fsm] && A[fsm].running;
  const pb = document.getElementById(`btn-pause-${fsm}`);
  const rb = document.getElementById(`btn-resume-${fsm}`);
  if (pb) { pb.disabled = !r; pb.classList.toggle('btn-inactive', !r); }
  if (rb) { rb.disabled =  r; rb.classList.toggle('btn-inactive',  r); }
}

/* ── Master render — syncs all 5 panels ── */
function _renderStep(fsm) {
  const fd    = FSM_SEQUENCES[fsm];
  const step  = fd.sequence[A[fsm].step];
  const si    = step.state;
  const info  = fd.states[si];
  const total = fd.sequence.length;
  const cur   = A[fsm].step;

  // 1 · State bar
  const nameEl = document.getElementById(`csb-state-${fsm}`);
  const descEl = document.getElementById(`csb-desc-${fsm}`);
  const stepEl = document.getElementById(`anim-step-${fsm}`);
  if (nameEl) { nameEl.textContent = info.name; nameEl.style.color = info.color; nameEl.style.textShadow = `0 0 18px ${info.color}cc`; }
  if (descEl) descEl.textContent = step.desc;
  if (stepEl) stepEl.textContent = `Step ${cur+1}/${total} · ${step.event}`;

  // 2 · SVG highlight
  _svgHighlight(fsm, si);

  // 3 · Scenario
  if (fsm === 'traffic')  _renderTraffic(step);
  if (fsm === 'vending')  _renderVending(step);
  if (fsm === 'elevator') _renderElevator(step);
  if (fsm === 'serial')   _renderSerial(step);

  // 4 · Scenario description
  const scEl = document.getElementById(`sc-desc-${fsm}`);
  if (scEl) scEl.innerHTML = `<strong style="color:${info.color};text-shadow:0 0 10px ${info.color}88">${info.name}:</strong> ${step.desc}`;

  // 5 · Waveform cursor sync
  const wfEl = document.getElementById(`wf-embed-${fsm}`);
  if (wfEl) renderWaveformInContainer(fd.wfName, wfEl, step.wfCycle);
}

function _svgHighlight(fsm, activeIdx) {
  const svg = document.getElementById(`fsm-svg-${fsm}`);
  if (!svg) return;
  svg.querySelectorAll('.state-circle').forEach((c, i) => {
    const col = FSM_SEQUENCES[fsm] && FSM_SEQUENCES[fsm].states[i] ? FSM_SEQUENCES[fsm].states[i].color : '#fff';
    if (i === activeIdx) {
      c.style.strokeWidth = '4.5'; c.style.stroke = col;
      c.style.filter = `drop-shadow(0 0 14px ${col}) drop-shadow(0 0 28px ${col}88)`;
      c.classList.add('active-state');
    } else {
      c.style.strokeWidth = '2'; c.style.filter = ''; c.style.stroke = '';
      c.classList.remove('active-state');
    }
  });
}

/* ─────────────────────────────────────────────
   SCENARIO RENDERERS
───────────────────────────────────────────── */

/* ── Traffic Light ── */
function _renderTraffic(step) {
  const o = step.out;
  const r = document.getElementById('tl-red');
  const y = document.getElementById('tl-yellow');
  const g = document.getElementById('tl-green');
  if (r) r.className = 'tl-light' + (o.red ? ' on-red'    : '');
  if (y) y.className = 'tl-light' + (o.yel ? ' on-yellow' : '');
  if (g) g.className = 'tl-light' + (o.grn ? ' on-green'  : '');

  const ped = document.getElementById('tl-ped');
  if (ped) {
    ped.style.opacity   = step.pedVis ? (o.ped ? '1' : '0.55') : '0.12';
    ped.classList.toggle('ped-walking', !!o.ped);
  }

  const car = document.getElementById('tl-car');
  if (car) {
    const pos = { off:'-18%', stopped:'18%', slowing:'42%', moving:'78%' };
    car.style.left    = pos[step.carPos] || '18%';
    car.style.opacity = step.carPos === 'off' ? '0' : '1';
  }

  const scene = document.getElementById('traffic-scene');
  if (scene) scene.classList.toggle('emergency-flash', !!step.emergency);

  // Ambulance
  const amb = document.getElementById('tl-ambulance');
  if (amb) {
    amb.style.display = step.emergency ? 'block' : 'none';
  }
}

/* ── Vending Machine ── */
function _renderVending(step) {
  const screen   = document.getElementById('vm-screen');
  const product  = document.getElementById('vm-product');
  const changeEl = document.getElementById('vm-change');
  const emptyBdg = document.getElementById('vm-empty-badge');
  const machine  = document.getElementById('vm-machine-box');
  const coinBar  = document.getElementById('vm-coin-bar');
  const items    = document.querySelectorAll('.vm-item-cell');

  if (screen)   screen.innerHTML = (step.screen || 'READY').replace('\n', '<br>');
  if (product)  { product.style.opacity = step.product ? '1' : '0'; product.style.transform = step.product ? 'translateY(0)' : 'translateY(-24px)'; }
  if (changeEl) { changeEl.style.opacity = step.change ? '1' : '0'; changeEl.style.transform = step.change ? 'translateY(0)' : 'translateY(-10px)'; }
  if (emptyBdg) emptyBdg.style.display = step.itemEmpty ? 'flex' : 'none';
  if (machine)  machine.classList.toggle('vm-cancelled', !!step.cancelled);

  // Coin stack visualiser
  if (coinBar) {
    coinBar.innerHTML = '';
    for (let i = 0; i < Math.min(step.coins || 0, 6); i++) {
      const c = document.createElement('div');
      c.className = 'vm-coin-chip';
      c.textContent = '¢';
      coinBar.appendChild(c);
    }
  }

  items.forEach((el, i) => {
    el.classList.remove('vm-selected', 'vm-dispensing', 'vm-empty-slot');
    if (step.sel === i) {
      if (step.itemEmpty) el.classList.add('vm-empty-slot');
      else if (step.product) el.classList.add('vm-dispensing');
      else el.classList.add('vm-selected');
    }
  });
}

/* ── Elevator ── */
function _renderElevator(step) {
  const NUM_FLOORS = 5;
  const FLOOR_H    = 44; // px per floor, matches CSS
  const car    = document.getElementById('elev-car');
  const door   = document.getElementById('elev-door');
  const floorN = document.getElementById('elev-floor-num');
  const status = document.getElementById('elev-status-icon');
  const alarm  = document.getElementById('elev-alarm');
  const queueEl= document.getElementById('elev-queue-val');

  if (car) {
    const bot = Math.round(((step.floor - 1) / (NUM_FLOORS - 1)) * (NUM_FLOORS - 1) * FLOOR_H);
    car.style.bottom = bot + 'px';
    const col = FSM_SEQUENCES.elevator.states[step.state] ? FSM_SEQUENCES.elevator.states[step.state].color : '#4fc3f7';
    car.style.borderColor = col;
    car.style.boxShadow   = `0 0 14px ${col}88`;
  }

  if (door) {
    const lPanel = door.querySelector('.door-left');
    const rPanel = door.querySelector('.door-right');
    if (lPanel) lPanel.style.width = step.doorOpen ? '0%' : '50%';
    if (rPanel) rPanel.style.width = step.doorOpen ? '0%' : '50%';
  }

  if (floorN) { floorN.textContent = step.floor; floorN.style.color = step.doorOpen ? '#39ff8f' : '#00f5ff'; }

  if (status) {
    if      (step.alarm)    { status.textContent = '🚨'; status.className = 'elev-status alarm-pulse'; }
    else if (step.overload) { status.textContent = '⚖️'; status.className = 'elev-status alarm-pulse'; }
    else if (step.dir > 0)  { status.textContent = '⬆';  status.className = 'elev-status moving-up';   }
    else if (step.dir < 0)  { status.textContent = '⬇';  status.className = 'elev-status moving-down'; }
    else if (step.doorOpen) { status.textContent = '🚪'; status.className = 'elev-status door-anim';   }
    else                    { status.textContent = '⏸';  status.className = 'elev-status';              }
  }
  if (alarm)  { alarm.style.opacity = step.alarm ? '1' : '0'; alarm.style.transform = step.alarm ? 'scale(1)' : 'scale(0.8)'; }
  if (queueEl) queueEl.textContent = step.queue || '—';
}

/* ── Serial Comm ── */
function _renderSerial(step) {
  const cells  = document.querySelectorAll('.serial-bit-cell');
  const errBdg = document.getElementById('serial-err-badge');
  const doneBdg= document.getElementById('serial-done-badge');
  const byteD  = document.getElementById('serial-byte-val');
  const dot    = document.getElementById('serial-dot');
  const canvas = document.getElementById('serial-wave-canvas');

  cells.forEach(c => { c.className = 'serial-bit-cell'; c.querySelector && (c.querySelector('.serial-bit-val').textContent = '-'); });

  if (step.parityErr) {
    cells.forEach(c => c.classList.add('error'));
    if (errBdg)  errBdg.style.display  = 'flex';
    if (doneBdg) doneBdg.style.display = 'none';
    if (byteD)   { byteD.textContent = 'ERR'; byteD.style.color = '#ff4f6e'; }
    return;
  }

  if (errBdg)  errBdg.style.display  = 'none';
  if (doneBdg) doneBdg.style.display = step.done ? 'flex' : 'none';

  // Fill received bits
  (step.bits || []).forEach((v, i) => {
    if (cells[i + 1]) { cells[i+1].className = 'serial-bit-cell received'; cells[i+1].querySelector('.serial-bit-val').textContent = v; }
  });

  // Active cell
  if (step.ab >= 0 && cells[step.ab + 1]) {
    cells[step.ab+1].className = 'serial-bit-cell active';
    cells[step.ab+1].querySelector('.serial-bit-val').textContent = step.bv;
  }
  if (step.state === 1  && cells[0])  cells[0].className  = 'serial-bit-cell active';
  if (step.state === 10 && cells[9])  cells[9].className  = 'serial-bit-cell active';
  if (step.state === 11 && cells[10]) cells[10].className = 'serial-bit-cell received';

  // Byte display
  if (byteD) {
    if (step.bits && step.bits.length === 8) {
      const byte = parseInt([...step.bits].reverse().join(''), 2);
      byteD.textContent = '0x' + byte.toString(16).toUpperCase().padStart(2,'0');
      byteD.style.color = step.done ? '#39ff8f' : '#b57bff';
    } else { byteD.textContent = '0x--'; byteD.style.color = '#4a5580'; }
  }

  // Data dot
  if (dot) {
    const stateN = Math.min(step.state, 12);
    const pct = (stateN / 12) * 94;
    dot.style.left = pct + '%';
    dot.style.background = step.done ? '#39ff8f' : '#00f5ff';
    dot.style.boxShadow  = `0 0 10px ${step.done ? '#39ff8f' : '#00f5ff'}`;
  }

  // Canvas waveform
  if (canvas) _drawSerialWave(canvas, step.bits || [], step.state);
}

function _drawSerialWave(canvas, bits, stateIdx) {
  const ctx = canvas.getContext('2d');
  const W = canvas.clientWidth || 260, H = canvas.clientHeight || 36;
  canvas.width = W; canvas.height = H;
  ctx.clearRect(0, 0, W, H);

  const total = 13;
  const bW = W / total;
  const hi = H * 0.1, lo = H * 0.7;

  // idle-hi, start-lo, 8 data bits, stop-hi, done-hi
  const wave = [1, 0, ...bits.slice(0,8), ...new Array(Math.max(0, 8 - bits.length)).fill(null), 1, 1];

  ctx.beginPath();
  ctx.strokeStyle = '#00f5ff';
  ctx.lineWidth = 2;
  ctx.shadowColor = '#00f5ff';
  ctx.shadowBlur = 5;
  let prevY = hi;
  wave.forEach((v, i) => {
    const x = i * bW;
    const y = v === 1 ? hi : v === 0 ? lo : (hi + lo) / 2;
    if (i === 0) { ctx.moveTo(x, y); prevY = y; return; }
    if (y !== prevY) { ctx.lineTo(x, prevY); ctx.lineTo(x, y); }
    else ctx.lineTo(x, y);
    ctx.lineTo(x + bW, y);
    prevY = y;
  });
  ctx.stroke();

  // Active cursor
  if (stateIdx >= 0 && stateIdx < total) {
    const cx = (stateIdx + 0.5) * bW;
    ctx.strokeStyle = 'rgba(0,245,255,0.55)';
    ctx.lineWidth = 1.5;
    ctx.shadowBlur = 0;
    ctx.setLineDash([4, 3]);
    ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, H); ctx.stroke();
    ctx.setLineDash([]);
  }
}

/* ─────────────────────────────────────────────
   INIT
───────────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  // Hero fade
  const hero = document.querySelector('.hero');
  if (hero) {
    hero.style.opacity = '0'; hero.style.transform = 'translateY(24px)';
    requestAnimationFrame(() => {
      hero.style.transition = 'opacity 0.7s ease, transform 0.7s ease';
      hero.style.opacity = '1'; hero.style.transform = 'translateY(0)';
    });
  }

  // Stagger cards
  document.querySelectorAll('.card, .app-card').forEach((c, i) => {
    c.style.opacity = '0'; c.style.transform = 'translateY(16px)';
    setTimeout(() => {
      c.style.transition = 'opacity 0.45s ease, transform 0.45s ease';
      c.style.opacity = '1'; c.style.transform = 'translateY(0)';
    }, 100 + i * 50);
  });

  // Init FSMs
  ['traffic','vending','elevator','serial'].forEach(fsm => { initA(fsm); _updateBtns(fsm); });

  // Standalone waveform tab
  renderWaveform('traffic');

  // Embedded waveforms (no cursor at init)
  ['traffic','vending','elevator','serial'].forEach(fsm => {
    const el = document.getElementById(`wf-embed-${fsm}`);
    if (el) renderWaveformInContainer(fsm, el);
  });
});/* ================================================================
   ADDITIONS v4
   - showWT() — walkthrough tab switcher
   - TB_CASES — testbench case data aligned to waveform data
   - initTBCases() — populates case selector in Waveform tab
   - Updated DOMContentLoaded init
   ================================================================ */

/* ─────────────────────────────────────────────
   WALKTHROUGH TAB SWITCHER
───────────────────────────────────────────── */
function showWT(fsm, caseKey) {
  // Deactivate all tabs and contents for this FSM
  const tabArea = document.querySelector(`#tab-${fsm} .walkthrough-tabs`);
  if (!tabArea) return;
  tabArea.querySelectorAll('.wt-tab').forEach(b => b.classList.remove('active'));
  // Find and activate the clicked tab
  tabArea.querySelectorAll('.wt-tab').forEach(b => {
    if (b.getAttribute('onclick') && b.getAttribute('onclick').includes(`'${caseKey}'`)) {
      b.classList.add('active');
    }
  });
  // Hide all content blocks, show the right one
  document.querySelectorAll(`#tab-${fsm} .walkthrough-content`).forEach(c => c.classList.add('hidden'));
  const target = document.getElementById(`wt-${fsm}-${caseKey}`);
  if (target) target.classList.remove('hidden');
}

/* ─────────────────────────────────────────────
   TESTBENCH CASES — aligned to WAVEFORM_DATA
   Each case references a wfCycleRange (start cycle) for cursor
───────────────────────────────────────────── */
const TB_CASES = {
  traffic: [
    { label: 'T1: Reset→IDLE',       desc: 'do_reset: All lights off. Checks all outputs = 0 after synchronous reset.', cycle: 0 },
    { label: 'T2–5: Car cycle',       desc: 'IDLE→RED (car_sensor) → GREEN (timer) → YELLOW (timer) → RED (timer). Normal 3-phase cycle.', cycle: 3 },
    { label: 'T6–7: Car ignored RED', desc: 'Already in RED, car_sensor fires again — HOLD entry: state stays RED. output_valid pulses but state unchanged.', cycle: 3 },
    { label: 'T12–15: Ped from GREEN',desc: 'GREEN + ped_btn=1 → RED directly (GREEN→RED). Then ped_btn from RED → PED_WAIT → PED_CROSS → RED.', cycle: 14 },
    { label: 'T16–19: Ped from RED',  desc: 'RED + pedestrian_btn → PED_WAIT → PED_CROSS (ped_signal ON) → RED.', cycle: 15 },
    { label: 'T20–23: Ped from IDLE', desc: 'IDLE + pedestrian_btn → RED → GREEN → YELLOW → RED. Ped button triggers initial red phase.', cycle: 0 },
    { label: 'T24–25: Reset active',  desc: 'FSM in GREEN, reset asserted mid-operation → returns to IDLE. All outputs clear.', cycle: 7 },
  ],
  vending: [
    { label: 'T1–6: Normal purchase', desc: 'IDLE → COLLECT (coin) → SELECT (item) → DISPENSE (motor ON) → CHANGE (change_return) → IDLE.', cycle: 3 },
    { label: 'T7–10: Cancel/refund',  desc: 'COLLECT + cancel_btn → INTERRUPT → IDLE. interrupt_return_detect fires change_return pulse. Seen_change_pulse=TRUE.', cycle: 20 },
  ],
  elevator: [
    { label: 'F1→F5 up trip',         desc: 'IDLE → MOVE_UP (motor_up) → F2..F5 → DOOR_OPEN → DOOR_CLOSE → IDLE.', cycle: 3 },
    { label: 'F5→F1 down trip',        desc: 'IDLE → MOVE_DOWN (motor_down) → F4..F1 → DOOR_OPEN → DOOR_CLOSE → IDLE.', cycle: 13 },
    { label: 'Emergency stop',         desc: 'MOVE_UP + emergency_btn → INTERRUPT → IDLE. alarm_buzzer HIGH. Motor cut immediately.', cycle: 21 },
  ],
  serial: [
    { label: 'Full frame 0xA5',        desc: 'IDLE → START → BIT0..7 → STOP → COMPLETE (tx_enable HIGH) → IDLE. 11 rx_valid pulses. Parity=0 (PASS).', cycle: 3 },
    { label: 'Bad parity error',       desc: 'Frame arrives with odd parity. At STOP state: SP_INTERRUPT_EVENT fires → IDLE. parity_err HIGH. Frame discarded.', cycle: 21 },
  ],
};

/* Current active FSM and case in waveform tab */
let _wfFSM = 'traffic';
let _wfCase = 0;

/* ─────────────────────────────────────────────
   INIT TB CASE BUTTONS
───────────────────────────────────────────── */
function initTBCases(fsmName) {
  _wfFSM = fsmName;
  _wfCase = 0;
  const cases = TB_CASES[fsmName] || [];
  const btnsEl = document.getElementById('tb-case-btns');
  if (!btnsEl) return;
  btnsEl.innerHTML = '';
  cases.forEach((c, i) => {
    const btn = document.createElement('button');
    btn.className = 'tb-case-btn' + (i === 0 ? ' active' : '');
    btn.textContent = c.label;
    btn.addEventListener('click', () => selectTBCase(fsmName, i, btn));
    btnsEl.appendChild(btn);
  });
  // Show first case description
  _updateTBDesc(fsmName, 0);
  renderWaveformInContainer(fsmName, document.getElementById('waveform-display'), cases[0] ? cases[0].cycle : undefined);
}

function selectTBCase(fsmName, idx, btnEl) {
  _wfFSM = fsmName;
  _wfCase = idx;
  // Update button active state
  const btnsEl = document.getElementById('tb-case-btns');
  if (btnsEl) btnsEl.querySelectorAll('.tb-case-btn').forEach(b => b.classList.remove('active'));
  if (btnEl) btnEl.classList.add('active');
  _updateTBDesc(fsmName, idx);
  const cases = TB_CASES[fsmName] || [];
  const cycle = cases[idx] ? cases[idx].cycle : undefined;
  renderWaveformInContainer(fsmName, document.getElementById('waveform-display'), cycle);
}

function _updateTBDesc(fsmName, idx) {
  const descEl = document.getElementById('tb-case-desc');
  if (!descEl) return;
  const cases = TB_CASES[fsmName] || [];
  descEl.textContent = cases[idx] ? cases[idx].desc : '';
}

/* ─────────────────────────────────────────────
   OVERRIDE selectWaveform to also init TB cases
───────────────────────────────────────────── */
const _origSelectWaveform = selectWaveform;
selectWaveform = function(name, buttonEl) {
  // Original button highlight + waveform render
  const container = buttonEl ? buttonEl.closest('.waveform-container') : null;
  if (container) {
    container.querySelectorAll('.wf-btn').forEach(b => b.classList.remove('active'));
    if (buttonEl) buttonEl.classList.add('active');
  }
  // Init TB cases for new FSM
  initTBCases(name);
};

document.addEventListener('DOMContentLoaded', () => {
  setTimeout(() => initTBCases('traffic'), 0);
});

/* ================================================================
   REAL VHDL SIMULATION FRONTEND  v4 — definitive fix
   ================================================================
   Root cause of page reload: ANY fetch() that rejects (network error,
   AbortController abort, CORS failure) while called from a script
   loaded via file:// can trigger a browser navigation in Chromium
   versions <112. Even with .catch(), the network stack fires first.

   Solution:
   - ZERO automatic fetching. No health check on load. No polling.
   - The badge is set to "Manual — click RUN VHDL" by default.
   - When button clicked: ONE fetch to /api/run. If it fails, we catch
     it as a plain Error and show the message. No AbortController used.
   - No async/await anywhere in the click-handler call chain.
   - The running guard (_sim.running) blocks all re-entry.
   ================================================================ */

const SIM_API = 'http://localhost:5000/api';

const SIM_FSM_META = {
  traffic:  { label:'Traffic Light',   config_id:'00', tb:'tb_traffic_light.vhd', vcd:'tb_traffic_light.vcd' },
  vending:  { label:'Vending Machine', config_id:'01', tb:'tb_vending.vhd',       vcd:'tb_vending.vcd'       },
  elevator: { label:'Elevator',        config_id:'10', tb:'tb_elevator.vhd',       vcd:'tb_elevator.vcd'      },
  serial:   { label:'Serial Comm',     config_id:'11', tb:'tb_serial.vhd',         vcd:'tb_serial.vcd'        },
  fsm_core: { label:'FSM Core',        config_id:'XX', tb:'tb_fsm.vhd',            vcd:'tb_fsm.vcd'           },
};

const SIM_STATE_COLORS = {
  TL_IDLE:'#6b7280', TL_RED:'#ff4f6e', TL_GREEN:'#39ff8f',
  TL_YELLOW:'#ffe84d', TL_PED_WAIT:'#4fc3f7', TL_PED_CROSS:'#b57bff',
  VM_IDLE:'#6b7280', VM_SELECT:'#4fc3f7', VM_COLLECT:'#ffe84d',
  VM_DISPENSE:'#39ff8f', VM_CHANGE:'#b57bff',
  EL_IDLE:'#6b7280', EL_MOVE_UP:'#4fc3f7', EL_MOVE_DOWN:'#b57bff',
  EL_DOOR_OPEN:'#39ff8f', EL_DOOR_CLOSE:'#ffe84d', EL_EMERGENCY:'#ff4f6e',
  SP_IDLE:'#6b7280', SP_START:'#4fc3f7', SP_COMPLETE:'#39ff8f', SP_STOP:'#ffe84d',
};

var _sim = {
  fsm:'traffic', runId:null, cycles:[], inspIdx:0,
  inspTimer:null, evtSrc:null, running:false, initDone:false,
};

/* ── Keep simulation tab active ── */
function _simKeepTab() {
  document.querySelectorAll('.tab').forEach(function(t){ t.classList.remove('active'); });
  document.querySelectorAll('.nav-btn').forEach(function(b){ b.classList.remove('active'); });
  var t=document.getElementById('tab-simulation'), b=document.querySelector('[data-tab="simulation"]');
  if(t) t.classList.add('active');
  if(b) b.classList.add('active');
}

/* ── One-time setup ── */
function _simSetup() {
  if (_sim.initDone) return;
  _sim.initDone = true;

  /* Restore tab from sessionStorage */
  try {
    var saved = sessionStorage.getItem('fsmActiveTab');
    if (saved) {
      var tt=document.getElementById('tab-'+saved), bb=document.querySelector('[data-tab="'+saved+'"]');
      if(tt && bb) {
        document.querySelectorAll('.tab').forEach(function(x){x.classList.remove('active');});
        document.querySelectorAll('.nav-btn').forEach(function(x){x.classList.remove('active');});
        tt.classList.add('active'); bb.classList.add('active');
      }
    }
  } catch(e){}

  /* Save tab on nav clicks */
  document.querySelectorAll('.nav-btn').forEach(function(btn){
    btn.addEventListener('click', function(){
      try{ sessionStorage.setItem('fsmActiveTab', btn.dataset.tab||'home'); }catch(e){}
    });
  });

  /* FSM selector buttons */
  document.querySelectorAll('.sim-fsm-btn').forEach(function(btn){
    btn.addEventListener('click', function(e){
      e.preventDefault(); e.stopPropagation();
      document.querySelectorAll('.sim-fsm-btn').forEach(function(b){b.classList.remove('active');});
      btn.classList.add('active');
      _sim.fsm = btn.dataset.fsm;
      _simInfoBar(btn.dataset.fsm);
    });
  });

  /* RUN VHDL button — synchronous handler only, no async, no fetch here */
  var runBtn = document.getElementById('sim-run-vhdl-btn');
  if (runBtn) {
    runBtn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      e.stopImmediatePropagation();
      if (_sim.running) return;             /* re-entry guard */
      try{ sessionStorage.setItem('fsmActiveTab','simulation'); }catch(ex){}
      _simKeepTab();
      _simLaunch();                         /* synchronous entry point */
    });
  }

  /* Set badge to manual mode — no auto fetch */
  var badge = document.getElementById('sim-backend-badge');
  if (badge) {
    badge.textContent = '⚡ Click RUN VHDL to connect';
    badge.className = 'sim-backend-badge';
  }

  _simInfoBar('traffic');
}

/* Boot */
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', _simSetup);
} else {
  _simSetup();
}

/* ── Info bar ── */
function _simInfoBar(key) {
  var m=SIM_FSM_META[key]; if(!m) return;
  function s(id,v){var el=document.getElementById(id);if(el)el.textContent=v;}
  s('sib-fsm',m.label); s('sib-cfg',m.config_id); s('sib-tb',m.tb); s('sib-vcd',m.vcd);
}

/* ── Console ── */
function _simLog(line, cls) {
  var con=document.getElementById('sim-console'); if(!con) return;
  var ph=con.querySelector('.sim-console-placeholder'); if(ph) ph.remove();
  var d=document.createElement('div');
  if(cls) { d.className=cls; } else {
    var lc=line.toLowerCase();
    if     (lc.indexOf('pass:')>=0)                                  d.className='sim-log-pass';
    else if(lc.indexOf('fail:')>=0||(lc.indexOf('error:')>=0&&lc.indexOf('simulation')<0)) d.className='sim-log-fail';
    else if(lc.indexOf('warning:')>=0)                               d.className='sim-log-warn';
    else if(lc.indexOf('==='  )>=0||lc.indexOf('---')>=0||lc.indexOf('  [')==0) d.className='sim-log-info';
    else if(lc.indexOf('  $' )==0)                                   d.className='sim-log-cmd';
  }
  d.textContent=line; con.appendChild(d); con.scrollTop=con.scrollHeight;
}

function simClearConsole() {
  var con=document.getElementById('sim-console');
  if(con) con.innerHTML='<div class="sim-console-placeholder">Console cleared. Click ▶ RUN VHDL to simulate.</div>';
  _simFooter(null);
}

function _simStatus(st) {
  var dot=document.getElementById('sim-status-dot'),
      txt=document.getElementById('sim-status-text'),
      btn=document.getElementById('sim-run-vhdl-btn'),
      badge=document.getElementById('sim-backend-badge');
  if(dot) dot.className='sim-status-dot '+st;
  if(txt) txt.textContent=st.charAt(0).toUpperCase()+st.slice(1);
  if(btn) {
    if(st==='running'){btn.textContent='⟳ Running…';btn.classList.add('running');btn.disabled=true;}
    else{btn.textContent='▶ RUN VHDL';btn.classList.remove('running');btn.disabled=false;}
  }
  if(badge && st==='running') { badge.textContent='🟡 Connecting…'; badge.className='sim-backend-badge'; }
  if(badge && st==='done')    { badge.textContent='🟢 Simulation complete'; badge.className='sim-backend-badge online'; }
  if(badge && st==='error')   { badge.textContent='🔴 Error — check console'; badge.className='sim-backend-badge offline'; }
}

function _simFooter(s) {
  var p=document.getElementById('sim-pass-count'),f=document.getElementById('sim-fail-count'),
      c=document.getElementById('sim-cycle-count'),d=document.getElementById('sim-vcd-dl-btn');
  if(!s){if(p)p.textContent='— passes';if(f)f.textContent='— fails';if(c)c.textContent='— cycles';if(d)d.disabled=true;return;}
  if(p)p.textContent=(s.passes||0)+' passes';
  if(f)f.textContent=(s.fails||0)+' fails';
  if(c)c.textContent=(s.cycle_count||0)+' cycles';
  if(d)d.disabled=(s.status!=='done');
}

/* ═══════════════════════════════════════════════════════════════
   LAUNCH — called synchronously from button click.
   Uses plain fetch().then().catch() — NO async/await, NO AbortController.
   All error paths go through _simFinish() which releases the guard.
═══════════════════════════════════════════════════════════════ */
function _simLaunch() {
  _sim.running = true;
  simClearConsole();
  _simStatus('running');
  _sim.cycles = []; _sim.runId = null;

  /* Close stale SSE */
  if(_sim.evtSrc){try{_sim.evtSrc.close();}catch(e){}_sim.evtSrc=null;}

  var label = (SIM_FSM_META[_sim.fsm]||{label:_sim.fsm}).label;
  _simLog('▶ RUN VHDL — ' + label, 'sim-log-header');
  _simLog('  Connecting to sim_server.py on localhost:5000…', 'sim-log-cmd');
  _simKeepTab();

  /* Single fetch — no AbortController, timeout handled by server */
  fetch(SIM_API + '/run', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({fsm: _sim.fsm}),
  })
  .then(function(resp) {
    return resp.json().then(function(data){ return {ok:resp.ok, data:data}; });
  })
  .then(function(rd) {
    if (!rd.ok || rd.data.error) {
      _simLog('✗ ' + (rd.data.error || 'Server returned error'), 'sim-log-fail');
      if (rd.data.hint) _simLog('  ' + rd.data.hint, 'sim-log-warn');
      _simFinish('error'); return;
    }
    _sim.runId = rd.data.run_id;
    _simLog('  Run ID: ' + _sim.runId, 'sim-log-cmd');
    _simKeepTab();
    _simOpenStream(_sim.runId);
  })
  .catch(function(err) {
    var msg = (err && err.message) ? err.message : 'Network error (is sim_server.py running?)';
    _simLog('✗ Cannot reach backend: ' + msg, 'sim-log-fail');
    _simLog('  Start the server:  cd configurable_fsm && python sim_server.py', 'sim-log-warn');
    _simFinish('error');
  });
}

/* Open SSE — plain callbacks, no async */
function _simOpenStream(runId) {
  var es = new EventSource(SIM_API + '/stream/' + runId);
  _sim.evtSrc = es;

  es.onmessage = function(e) {
    var msg; try{ msg=JSON.parse(e.data); }catch(_){ return; }
    _simKeepTab();
    if (msg.type === 'log') {
      _simLog(msg.line);
    } else if (msg.type === 'done') {
      try{es.close();}catch(_){} _sim.evtSrc=null;
      _simFooter(msg.summary);
      var st = (msg.summary && msg.summary.status==='done') ? 'done' : 'error';
      _simFinish(st);
      if (st==='done') _simGetResults(runId);
    }
  };

  es.onerror = function() {
    try{es.close();}catch(_){} _sim.evtSrc=null;
    _simLog('✗ Stream closed — check backend terminal', 'sim-log-warn');
    _simFinish('error');
  };
}

/* Always release the running lock here */
function _simFinish(st) {
  _sim.running = false;
  _simStatus(st||'error');
  _simKeepTab();
}

/* Fetch parsed cycle results */
function _simGetResults(runId) {
  fetch(SIM_API + '/results/' + runId)
  .then(function(r){ return r.json(); })
  .then(function(data){
    _sim.cycles = data.cycles || [];
    _simLog('\n  ✓ ' + _sim.cycles.length + ' real GHDL cycles loaded', 'sim-log-pass');
    _simInspInit();
    _simBuildTransLog();
    simRedrawWaveform();
    _simFooter({passes:data.passes,fails:data.fails,cycle_count:data.cycle_count,status:'done'});
  })
  .catch(function(err){
    _simLog('✗ Results error: '+(err&&err.message||'unknown'), 'sim-log-fail');
  });
}

/* VCD download — blob URL only, never navigates */
function simDownloadVCD() {
  if (!_sim.runId) return;
  fetch(SIM_API + '/vcd/' + _sim.runId)
  .then(function(r){ return r.text(); })
  .then(function(txt){
    var blob=new Blob([txt],{type:'text/plain'});
    var url=URL.createObjectURL(blob);
    var a=document.createElement('a');
    a.href=url; a.download='sim_'+_sim.runId+'.vcd'; a.style.display='none';
    document.body.appendChild(a); a.click();
    setTimeout(function(){URL.revokeObjectURL(url);document.body.removeChild(a);},1000);
  })
  .catch(function(err){ _simLog('✗ VCD download: '+(err&&err.message||'error'),'sim-log-fail'); });
}

/* ═══════════════════════════════════════════════════════════════
   CYCLE INSPECTOR
═══════════════════════════════════════════════════════════════ */
function _simInspInit() {
  _sim.inspIdx=0;
  var sl=document.getElementById('sim-cycle-slider');
  if(sl){sl.min=0;sl.max=Math.max(0,_sim.cycles.length-1);sl.value=0;}
  _simInspRender(0);
}
function simInspectorGoto(v){ var n=parseInt(v,10); _sim.inspIdx=n; _simInspRender(n); }
function simInspectorStep(d){
  var n=Math.max(0,Math.min(_sim.cycles.length-1,_sim.inspIdx+d));
  _sim.inspIdx=n;
  var sl=document.getElementById('sim-cycle-slider'); if(sl) sl.value=n;
  _simInspRender(n);
}
function simInspectorStart(){
  if(_sim.inspTimer) clearInterval(_sim.inspTimer);
  var sp=document.getElementById('sim-play-speed');
  var ms=sp?parseInt(sp.value,10):350;
  _sim.inspTimer=setInterval(function(){
    if(_sim.inspIdx>=_sim.cycles.length-1){clearInterval(_sim.inspTimer);_sim.inspTimer=null;return;}
    simInspectorStep(1);
  },ms);
}
function simInspectorPause(){ if(_sim.inspTimer){clearInterval(_sim.inspTimer);_sim.inspTimer=null;} }
function simInspectorReset(){
  simInspectorPause(); _sim.inspIdx=0;
  var sl=document.getElementById('sim-cycle-slider'); if(sl) sl.value=0;
  _simInspRender(0);
}
function _simInspRender(idx){
  if(!_sim.cycles.length) return;
  idx=Math.max(0,Math.min(idx,_sim.cycles.length-1));
  var c=_sim.cycles[idx];
  var ve=document.getElementById('sim-cycle-val');
  if(ve) ve.textContent=idx+' / '+(_sim.cycles.length-1);
  var color=SIM_STATE_COLORS[c.state_name]||'var(--cyan)';
  var cards=document.getElementById('sim-signal-cards'); if(!cards) return;
  cards.innerHTML='';
  var rows=[
    {n:'state_code',    v:c.state_raw+'  →  '+c.state_name, ch:c.state_changed, col:color},
    {n:'event_code',    v:c.event_code_hex+' ('+c.event_code_int+')', ch:c.event_code_int>0},
    {n:'config_addr',   v:c.config_addr_hex, ch:false},
    {n:'pipeline_stage',v:c.pipeline_stage, ch:!!c.fsm_busy},
    {n:'fsm_busy',      v:c.fsm_busy?'1 (pipeline active)':'0', ch:!!c.fsm_busy},
    {n:'output_valid',  v:c.output_valid?'1 (latched)':'0', ch:!!c.output_valid},
    {n:'timer_start',   v:c.timer_start?'1 ← timer restart':'0', ch:!!c.timer_start},
    {n:'reset',         v:c.reset?'1 ← RESET':'0', ch:!!c.reset},
  ];
  var outs=c.decoded_outputs||{};
  Object.keys(outs).forEach(function(k){ rows.push({n:k,v:outs[k]?'1':'0',ch:!!outs[k]}); });
  rows.forEach(function(r){
    var d=document.createElement('div');
    d.className='sim-signal-card'+(r.ch?' changed':'')+(r.n==='state_code'?' sc-high':'')+(c.reset?' sc-error':'');
    d.innerHTML='<span class="sim-signal-name">'+r.n+'</span>'+
      '<span class="sim-signal-val" style="color:'+(r.col||(r.ch?'var(--cyan)':'var(--txt-2)'))+'">'+(r.v||'')+'</span>';
    cards.appendChild(d);
  });
  var fmap={traffic:'traffic',vending:'vending',elevator:'elevator',serial:'serial'};
  if(fmap[_sim.fsm]) _svgHighlight(fmap[_sim.fsm],c.state_idx||0);
}
function _simBuildTransLog(){
  var log=document.getElementById('sim-trans-log'); if(!log) return;
  log.innerHTML='';
  var ts=_sim.cycles.filter(function(c){return c.state_changed;});
  if(!ts.length){log.innerHTML='<div class="sim-signal-placeholder">No transitions.</div>';return;}
  [_sim.cycles[0]].concat(ts).forEach(function(c){
    var col=SIM_STATE_COLORS[c.state_name]||'var(--cyan)';
    var d=document.createElement('div'); d.className='sim-trans-entry';
    d.innerHTML='<span class="sim-trans-cycle">Cycle '+c.cycle+' · '+c.time_ps+'ps</span>'+
      '<span class="sim-trans-arrow">→</span>'+
      '<span class="sim-trans-state" style="color:'+col+'">'+c.state_name+'</span>'+
      '<span style="font-size:.65rem;color:var(--txt-3);margin-left:auto">ev='+c.event_code_hex+'</span>';
    log.appendChild(d);
  });
  log.scrollTop=log.scrollHeight;
}

/* ═══════════════════════════════════════════════════════════════
   WAVEFORM
═══════════════════════════════════════════════════════════════ */
function simRedrawWaveform(){
  var con=document.getElementById('sim-waveform-live'); if(!con) return;
  if(!_sim.cycles.length){con.innerHTML='<div class="sim-wf-placeholder">Run simulation first.</div>';return;}
  function chk(id){var e=document.getElementById(id);return e?e.checked:true;}
  var showClk=chk('wf-chk-clk'),showSt=chk('wf-chk-state'),showEv=chk('wf-chk-event'),
      showBu=chk('wf-chk-busy'),showVa=chk('wf-chk-valid'),showOu=chk('wf-chk-out');
  var okeys=Object.keys((_sim.cycles[0]&&_sim.cycles[0].decoded_outputs)||{});
  var N=_sim.cycles.length,idx=_sim.inspIdx,W=100/N;
  con.innerHTML='';
  /* Ruler */
  var ruler=document.createElement('div'); ruler.className='wf-signal-row';
  var rt='';
  for(var i=0;i<N;i++) rt+='<div class="wf-segment" style="left:'+(i*W)+'%;width:'+W+'%;border-right:1px solid rgba(71,85,105,.2)"><span style="font-size:.5rem;color:var(--txt-3);position:absolute;top:1px;left:2px">'+i+'</span></div>';
  ruler.innerHTML='<div class="wf-signal-name" style="font-size:.6rem;color:var(--txt-3)">CYCLE</div><div class="wf-signal-track" style="min-width:560px;position:relative">'+rt+'</div>';
  con.appendChild(ruler);
  var rows=[];
  if(showClk) rows.push({l:'clk',t:'clock'});
  if(showSt)  rows.push({l:'state_code',t:'bus',fn:function(c){return c.state_name;}});
  if(showEv)  rows.push({l:'event_code',t:'bus',fn:function(c){return c.event_code_hex;}});
  if(showBu)  rows.push({l:'fsm_busy',t:'bit',fn:function(c){return c.fsm_busy?1:0;}});
  if(showVa)  rows.push({l:'output_valid',t:'bit',fn:function(c){return c.output_valid?1:0;}});
  if(showOu) okeys.forEach(function(k){ rows.push({l:k,t:'bit',fn:function(c){return(c.decoded_outputs&&c.decoded_outputs[k])?1:0;}}); });
  var cursor='<div style="position:absolute;left:'+(idx*W+W/2)+'%;top:0;width:2px;height:100%;background:rgba(0,245,255,.8);pointer-events:none;z-index:5"></div>';
  rows.forEach(function(row){
    var el=document.createElement('div'); el.className='wf-signal-row';
    var track='';
    if(row.t==='clock'){
      for(var i=0;i<N;i++){var l=i*W,hw=W/2;track+='<div class="wf-segment wf-clock-high" style="left:'+l+'%;width:'+hw+'%"></div><div class="wf-segment wf-clock-low" style="left:'+(l+hw)+'%;width:'+hw+'%"></div>';}
    } else if(row.t==='bit'){
      for(var i=0;i<N;i++) track+='<div class="wf-segment '+(row.fn(_sim.cycles[i])?'wf-seg-high':'wf-seg-low')+'" style="left:'+(i*W)+'%;width:'+W+'%"></div>';
    } else {
      var s=0,cv=row.fn(_sim.cycles[0]);
      for(var i=1;i<=N;i++){var nv=i<N?row.fn(_sim.cycles[i]):null;if(i===N||nv!==cv){track+='<div class="wf-segment wf-seg-bus" style="left:'+(s*W)+'%;width:'+((i-s)*W)+'%"><span class="wf-seg-bus-label">'+cv+'</span></div>';cv=nv;s=i;}}
    }
    el.innerHTML='<div class="wf-signal-name">'+row.l+'</div><div class="wf-signal-track" style="min-width:560px;position:relative">'+track+cursor+'</div>';
    con.appendChild(el);
  });
}

/* ── Public aliases ── */
window.simClearConsole   = simClearConsole;
window.simDownloadVCD    = simDownloadVCD;
window.simInspectorGoto  = simInspectorGoto;
window.simInspectorStart = simInspectorStart;
window.simInspectorPause = simInspectorPause;
window.simInspectorStep  = simInspectorStep;
window.simInspectorReset = simInspectorReset;
window.simRedrawWaveform = simRedrawWaveform;
window.simRunVHDL = function(e){ if(e){e.preventDefault();e.stopPropagation();} };