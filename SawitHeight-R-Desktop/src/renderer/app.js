const $ = (id) => document.getElementById(id);
const state = {
  running: false,
  currentRunDir: '',
  reportPath: '',
  summary: null,
  environmentReady: false,
  missingPackages: []
};

const stageOrder = ['validation','load','clean','density','ground','normalize','chm','zonal','export','complete'];
const pageTitles = {
  'data-page': 'Data Input',
  'parameter-page': 'Parameter Analisis',
  'process-page': 'Proses & Log',
  'result-page': 'Hasil Analisis'
};

function showAlert(message, type = 'info', timeout = 0) {
  const box = document.createElement('div');
  box.className = `alert ${type}`;
  const text = document.createElement('span');
  text.textContent = message;
  const close = document.createElement('button');
  close.className = 'ghost';
  close.textContent = '×';
  close.addEventListener('click', () => box.remove());
  box.append(text, close);
  $('alert-area').prepend(box);
  if (timeout) setTimeout(() => box.remove(), timeout);
}

function appendLog(message, level = 'info', timestamp = '') {
  const stamp = timestamp ? timestamp.replace('T', ' ').slice(0, 19) : new Date().toLocaleTimeString('id-ID');
  const prefix = level === 'error' ? '[ERROR]' : level === 'warning' ? '[WARN ]' : level === 'success' ? '[ OK  ]' : '[INFO ]';
  $('log-output').textContent += `\n${stamp} ${prefix} ${message}`;
  $('log-output').scrollTop = $('log-output').scrollHeight;
}

function switchPage(pageId) {
  document.querySelectorAll('.page').forEach((p) => p.classList.toggle('active', p.id === pageId));
  document.querySelectorAll('.nav-btn').forEach((b) => b.classList.toggle('active', b.dataset.page === pageId));
  $('page-title').textContent = pageTitles[pageId] || '';
}

function setRunning(running) {
  state.running = running;
  $('run-btn').disabled = running;
  $('validate-btn').disabled = running;
  $('check-env-btn').disabled = running;
  $('install-packages-btn').disabled = running || !state.missingPackages.length;
  $('cancel-btn').disabled = !running;
}

function setProgress(progress, label = '', stage = '') {
  const value = Math.max(0, Math.min(100, Number(progress) || 0));
  $('progress-fill').style.width = `${value}%`;
  $('progress-number').textContent = `${Math.round(value)}%`;
  if (label) $('stage-label').textContent = label;
  if (stage) updateStages(stage);
}

function updateStages(currentStage) {
  const currentIndex = stageOrder.indexOf(currentStage);
  document.querySelectorAll('#stage-list [data-stage]').forEach((el) => {
    const idx = stageOrder.indexOf(el.dataset.stage);
    el.classList.toggle('active', idx === currentIndex);
    el.classList.toggle('done', currentIndex > idx || currentStage === 'complete');
  });
}

function setRuntimeStatus(status, detail) {
  const pill = $('runtime-status');
  pill.className = `status-pill ${status}`;
  pill.textContent = status === 'ready' ? 'Siap' : status === 'missing' ? 'Package belum lengkap' : status === 'error' ? 'Error' : 'Belum diperiksa';
  $('runtime-version').textContent = detail || '';
}

function numeric(id) { return Number($(id).value); }
function checked(id) { return $(id).checked; }

function collectConfig() {
  return {
    inputs: {
      point_cloud: $('point-cloud').value.trim(),
      tree_points: $('tree-points').value.trim(),
      external_dtm: $('external-dtm').value.trim(),
      output_root: $('output-root').value.trim()
    },
    parameters: {
      fallback_epsg: numeric('fallback-epsg'),
      use_external_dtm: checked('use-external-dtm'),
      remove_duplicates: checked('remove-duplicates'),
      remove_noise: checked('remove-noise'),
      sor_k: numeric('sor-k'),
      sor_m: numeric('sor-m'),
      csf_slope_smooth: checked('csf-slope-smooth'),
      csf_cloth_resolution: numeric('csf-cloth-resolution'),
      csf_class_threshold: numeric('csf-class-threshold'),
      csf_rigidness: numeric('csf-rigidness'),
      chm_auto_resolution: checked('chm-auto-resolution'),
      chm_resolution: numeric('chm-resolution'),
      chm_min_auto_resolution: numeric('chm-min-auto-resolution'),
      buffer_m: numeric('buffer-m'),
      canopy_threshold_m: numeric('canopy-threshold-m'),
      height_break_1_m: numeric('height-break-1-m'),
      height_break_2_m: numeric('height-break-2-m'),
      tree_id_field: $('tree-id-field').value.trim(),
      threads: numeric('threads'),
      save_normalized_laz: checked('save-normalized-laz'),
      export_shapefile: checked('export-shapefile')
    }
  };
}

function applyConfig(config) {
  if (!config) return;
  const i = config.inputs || {};
  const p = config.parameters || {};
  const map = {
    'point-cloud': i.point_cloud,
    'tree-points': i.tree_points,
    'external-dtm': i.external_dtm,
    'output-root': i.output_root,
    'fallback-epsg': p.fallback_epsg,
    'tree-id-field': p.tree_id_field,
    'sor-k': p.sor_k,
    'sor-m': p.sor_m,
    'csf-cloth-resolution': p.csf_cloth_resolution,
    'csf-class-threshold': p.csf_class_threshold,
    'csf-rigidness': p.csf_rigidness,
    'chm-resolution': p.chm_resolution,
    'chm-min-auto-resolution': p.chm_min_auto_resolution,
    'buffer-m': p.buffer_m,
    'canopy-threshold-m': p.canopy_threshold_m,
    'height-break-1-m': p.height_break_1_m,
    'height-break-2-m': p.height_break_2_m,
    'threads': p.threads
  };
  Object.entries(map).forEach(([id, value]) => { if (value !== undefined && value !== null) $(id).value = value; });
  const bools = {
    'use-external-dtm': p.use_external_dtm,
    'remove-duplicates': p.remove_duplicates,
    'remove-noise': p.remove_noise,
    'csf-slope-smooth': p.csf_slope_smooth,
    'chm-auto-resolution': p.chm_auto_resolution,
    'save-normalized-laz': p.save_normalized_laz,
    'export-shapefile': p.export_shapefile
  };
  Object.entries(bools).forEach(([id, value]) => { if (typeof value === 'boolean') $(id).checked = value; });
  syncConditionalFields();
}

function syncConditionalFields() {
  const useDtm = checked('use-external-dtm');
  $('external-dtm').disabled = !useDtm;
  document.querySelector('[data-picker="external-dtm"]').disabled = !useDtm;
  $('chm-resolution').disabled = checked('chm-auto-resolution');
}

async function checkEnvironment() {
  setRunning(true);
  setRuntimeStatus('neutral', 'Memeriksa R dan package...');
  try {
    const result = await window.sawitHeight.checkEnvironment($('rscript-path').value.trim());
    $('rscript-path').value = result.rscriptPath;
  } catch (error) {
    setRuntimeStatus('error', error.message);
    showAlert(error.message, 'error');
  } finally {
    setRunning(false);
  }
}

async function validateInputs() {
  setRunning(true);
  switchPage('process-page');
  setProgress(0, 'Memulai validasi...', 'validation');
  appendLog('Validasi input dimulai.');
  try {
    const result = await window.sawitHeight.validateAnalysis({
      rscriptPath: $('rscript-path').value.trim(),
      config: collectConfig()
    });
    if (result.ok) showAlert('Validasi berhasil. Data siap diproses.', 'success', 6000);
    else (result.errors || ['Validasi gagal.']).forEach((e) => showAlert(e, 'error'));
  } catch (error) {
    showAlert(error.message, 'error');
  } finally {
    setRunning(false);
  }
}

async function startAnalysis() {
  state.summary = null;
  $('empty-result').classList.remove('hidden');
  $('result-content').classList.add('hidden');
  $('log-output').textContent = 'Menyiapkan analisis...';
  setProgress(0, 'Menyiapkan analisis', 'validation');
  setRunning(true);
  switchPage('process-page');
  try {
    const response = await window.sawitHeight.startAnalysis({
      rscriptPath: $('rscript-path').value.trim(),
      config: collectConfig()
    });
    if (!response.ok) {
      (response.errors || ['Gagal memulai analisis.']).forEach((e) => showAlert(e, 'error'));
      setRunning(false);
      return;
    }
    state.currentRunDir = response.runDir;
    $('run-dir-line').textContent = response.runDir;
    appendLog(`Folder run: ${response.runDir}`);
  } catch (error) {
    showAlert(error.message, 'error');
    setRunning(false);
  }
}

function renderResults(summary, reportPath) {
  state.summary = summary;
  state.currentRunDir = summary.run_dir || state.currentRunDir;
  state.reportPath = reportPath || '';
  $('empty-result').classList.add('hidden');
  $('result-content').classList.remove('hidden');

  const metrics = [
    ['Titik input', Number(summary.input_points || 0).toLocaleString('id-ID')],
    ['Densitas', `${Number(summary.avg_density_points_m2 || 0).toFixed(2)} titik/m²`],
    ['Resolusi CHM', `${summary.chm_resolution_m} m`],
    ['Ground', summary.ground_pct == null ? 'DTM eksternal' : `${Number(summary.ground_pct).toFixed(2)}%`],
    ['Titik pokok', Number(summary.tree_count || 0).toLocaleString('id-ID')],
    ['Tinggi valid', Number(summary.valid_height_count || 0).toLocaleString('id-ID')],
    ['CHM NoData', `${Number(summary.chm_na_pct || 0).toFixed(2)}%`],
    ['Run', summary.run_name || '-']
  ];
  $('metric-grid').innerHTML = '';
  metrics.forEach(([label, value]) => {
    const card = document.createElement('div');
    card.className = 'metric-card';
    const s = document.createElement('span'); s.textContent = label;
    const strong = document.createElement('strong'); strong.textContent = value;
    card.append(s, strong); $('metric-grid').append(card);
  });

  const preview = Array.isArray(summary.preview) ? summary.preview : [];
  const table = $('preview-table');
  table.innerHTML = '';
  if (preview.length) {
    const headers = Object.keys(preview[0]);
    const thead = document.createElement('thead');
    const trh = document.createElement('tr');
    headers.forEach((h) => { const th = document.createElement('th'); th.textContent = h; trh.append(th); });
    thead.append(trh); table.append(thead);
    const tbody = document.createElement('tbody');
    preview.forEach((row) => {
      const tr = document.createElement('tr');
      headers.forEach((h) => { const td = document.createElement('td'); td.textContent = row[h] ?? ''; tr.append(td); });
      tbody.append(tr);
    });
    table.append(tbody);
  }

  $('output-list').innerHTML = '';
  (summary.output_files || []).forEach((filePath) => {
    const item = document.createElement('div'); item.className = 'output-item';
    const info = document.createElement('div');
    const name = document.createElement('b'); name.textContent = String(filePath).split(/[\\/]/).pop();
    const pathEl = document.createElement('small'); pathEl.textContent = filePath;
    info.append(name, pathEl);
    const btn = document.createElement('button'); btn.className = 'ghost'; btn.textContent = 'Tampilkan';
    btn.addEventListener('click', () => window.sawitHeight.showItem(filePath));
    item.append(info, btn); $('output-list').append(item);
  });
}

function handleBackendEvent(event) {
  if (!event || typeof event !== 'object') return;
  if (event.type === 'log') appendLog(event.message || '', event.level || 'info', event.timestamp || '');
  if (event.type === 'progress') setProgress(event.progress, event.label, event.stage);
  if (event.type === 'run-created') {
    state.currentRunDir = event.runDir;
    $('run-dir-line').textContent = event.runDir;
  }
  if (event.type === 'environment') {
    state.missingPackages = (event.packages || []).filter((p) => !p.installed).map((p) => p.name);
    state.environmentReady = !state.missingPackages.length;
    const packageText = state.missingPackages.length ? `Hilang: ${state.missingPackages.join(', ')}` : 'Semua package tersedia';
    setRuntimeStatus(state.environmentReady ? 'ready' : 'missing', `${event.r_version} · ${packageText}`);
    $('install-packages-btn').disabled = state.running || !state.missingPackages.length;
    appendLog(`${event.r_version}; ${packageText}`, state.environmentReady ? 'success' : 'warning');
  }
  if (event.type === 'package-install') {
    appendLog(event.message || '', event.level || 'info');
    if (event.progress != null) setProgress(event.progress, 'Instalasi package R', 'validation');
  }
  if (event.type === 'validation-result' && (event.status === 'valid' || event.status === 'success')) {
    appendLog(event.message || `Validasi berhasil; ${event.tree_count || ''} titik pokok.`, 'success');
  }
  if (event.type === 'fatal') {
    appendLog(event.message || 'Fatal error.', 'error');
    showAlert(`Gagal pada tahap ${event.stage || '-'}: ${event.message}`, 'error');
    setRunning(false);
  }
  if (event.type === 'result') {
    renderResults(event.summary, event.reportPath);
    showAlert('Analisis selesai. Seluruh hasil dan log telah disimpan.', 'success');
    setRunning(false);
    switchPage('result-page');
  }
  if (event.type === 'process') {
    if (event.status === 'started') setRunning(true);
    if (['completed','failed','cancelled','error'].includes(event.status)) {
      setRunning(false);
      if (event.status === 'cancelled') showAlert('Proses dibatalkan. Folder run mungkin berisi output parsial.', 'warning');
      if (event.status === 'failed' && !state.summary) appendLog(`Rscript berhenti dengan kode ${event.code}.`, 'error');
    }
  }
}

async function initialize() {
  document.querySelectorAll('.nav-btn').forEach((btn) => btn.addEventListener('click', () => switchPage(btn.dataset.page)));
  $('use-external-dtm').addEventListener('change', syncConditionalFields);
  $('chm-auto-resolution').addEventListener('change', syncConditionalFields);
  $('clear-log-btn').addEventListener('click', () => { $('log-output').textContent = 'Tampilan log dibersihkan. File analysis.log tetap tersimpan.'; });

  document.querySelectorAll('[data-picker]').forEach((btn) => btn.addEventListener('click', async () => {
    const target = btn.dataset.picker;
    const actions = {
      'point-cloud': window.sawitHeight.selectPointCloud,
      'tree-points': window.sawitHeight.selectTreePoints,
      'external-dtm': window.sawitHeight.selectDtm,
      'output-root': window.sawitHeight.selectOutputFolder,
      'rscript-path': window.sawitHeight.selectRscript
    };
    const value = await actions[target]();
    if (value) $(target).value = value;
  }));

  $('check-env-btn').addEventListener('click', checkEnvironment);
  $('install-packages-btn').addEventListener('click', async () => {
    setRunning(true); switchPage('process-page'); setProgress(0, 'Instalasi package R', 'validation');
    try {
      await window.sawitHeight.installPackages($('rscript-path').value.trim());
      showAlert('Instalasi package selesai. Environment akan diperiksa ulang.', 'success');
      await checkEnvironment();
    } catch (error) { showAlert(error.message, 'error'); setRunning(false); }
  });
  $('validate-btn').addEventListener('click', validateInputs);
  $('run-btn').addEventListener('click', startAnalysis);
  $('cancel-btn').addEventListener('click', () => window.sawitHeight.cancelAnalysis());
  $('open-output-btn').addEventListener('click', () => window.sawitHeight.openPath(state.currentRunDir));
  $('open-report-btn').addEventListener('click', () => window.sawitHeight.openPath(state.reportPath));

  window.sawitHeight.onAnalysisEvent(handleBackendEvent);
  const appState = await window.sawitHeight.getState();
  $('app-version').textContent = `v${appState.version}`;
  if (appState.settings?.lastConfig) applyConfig(appState.settings.lastConfig);
  if (appState.settings?.rscriptPath) $('rscript-path').value = appState.settings.rscriptPath;
  if (!$('threads').value || Number($('threads').value) < 1) $('threads').value = Math.max(1, Math.min(8, navigator.hardwareConcurrency || 4));

  const detection = await window.sawitHeight.detectEnvironment($('rscript-path').value.trim());
  if (detection.found) {
    $('rscript-path').value = detection.rscriptPath;
    setRuntimeStatus('neutral', detection.bundled ? 'Bundled R ditemukan; belum diperiksa.' : 'Rscript ditemukan; belum diperiksa.');
  } else {
    setRuntimeStatus('error', 'Rscript.exe tidak ditemukan. Pilih secara manual.');
  }
  syncConditionalFields();
}

initialize().catch((error) => showAlert(error.message, 'error'));
