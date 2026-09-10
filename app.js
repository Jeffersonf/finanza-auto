const realData = window.FINANZA_AUTO_REAL_DATA || null;
const STORAGE_KEY = 'finanza-auto-real-state-v1';
const importedVehicle = realData?.vehicles?.[0];
const vehicles = realData ? {
  [importedVehicle.id]: { name: importedVehicle.name || 'Meu carro', year: '', details: 'Histórico importado do Drivvo', plate: importedVehicle.plate || '', mileage: Number(importedVehicle.odometer || 0).toLocaleString('pt-BR'), service: realData.summary?.latestDate || '—' }
} : {
  hrv: { name: 'Honda HR-V', year: '2022', details: 'Touring · Automático · Flex', plate: 'RBT 4E21', mileage: '28.420', service: '14' },
  corolla: { name: 'Toyota Corolla', year: '2021', details: 'Altis Premium · Automático · Flex', plate: 'ECO 7B83', mileage: '46.180', service: '29' }
};

const defaultTransactions = realData ? realData.events.map(event => ({
  description: event.type === 'fuel' ? `Abastecimento · ${event.fuelType}` : event.title,
  category: event.type === 'fuel' ? 'Abastecimento' : 'Outro',
  place: event.place || '', date: event.date, value: event.amount
})) : [
  { description: 'Abastecimento', category: 'Abastecimento', place: 'Posto Ipiranga', date: '2026-09-08', value: 248.60 },
  { description: 'Troca de óleo', category: 'Manutenção', place: 'Auto Center Prime', date: '2026-09-01', value: 380.00 },
  { description: 'Seguro auto', category: 'Seguro', place: 'Porto Seguro', date: '2026-08-12', value: 557.80 }
];

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved && Array.isArray(saved.transactions)) return { vehicle: saved.vehicle || 'hrv', transactions: saved.transactions };
  } catch (error) { /* storage unavailable: continue with defaults */ }
  return { vehicle: 'hrv', transactions: [...defaultTransactions] };
}

let state = loadState();
let toastTimer;

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];

function saveState() {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (error) { /* private browsing can block storage */ }
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[character]));
}

function formatCurrency(value) {
  return `R$ ${Number(value).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function formatDate(value) {
  return new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(`${value}T12:00:00`)).replace(/\./g, '');
}

function todayISO() {
  const today = new Date();
  return `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
}

function showToast(message) {
  const toast = $('#toast');
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('show'), 2800);
}

function chartData(period) {
  const source = state.transactions.filter(transaction => transaction.date);
  const latest = realData?.summary?.latestDate || source.map(transaction => transaction.date).sort().at(-1) || todayISO();
  const end = new Date(`${latest.slice(0, 7)}-01T12:00:00`);
  const keys = [];
  for (let offset = Number(period) - 1; offset >= 0; offset -= 1) {
    const month = new Date(end);
    month.setMonth(month.getMonth() - offset);
    keys.push(`${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, '0')}`);
  }
  const totalFor = key => source.filter(transaction => transaction.date.slice(0, 7) === key).reduce((sum, transaction) => sum + Number(transaction.value), 0);
  return {
    months: keys.map(key => new Intl.DateTimeFormat('pt-BR', { month: 'short' }).format(new Date(`${key}-01T12:00:00`)).replace(/\./g, '')),
    current: keys.map(totalFor),
    previous: keys.map(key => totalFor(`${Number(key.slice(0, 4)) - 1}${key.slice(4)}`)),
    total: keys.reduce((sum, key) => sum + totalFor(key), 0)
  };
}

function renderChart(period = '6') {
  const chart = chartData(period);
  const max = Math.max(1500, ...chart.current, ...chart.previous) * 1.08;
  $('#bars').innerHTML = chart.months.map((month, index) => `
    <div class="bar-group" title="${month}: ${formatCurrency(chart.current[index])}">
      <span class="bar previous" style="height:${Math.max(5, chart.previous[index] / max * 100)}%"></span>
      <span class="bar current" style="height:${Math.max(5, chart.current[index] / max * 100)}%"></span>
    </div>`).join('');
  $('#chartMonths').innerHTML = chart.months.map(month => `<span>${month}</span>`).join('');
  $('#periodTotal').textContent = formatCurrency(chart.total);
}

function renderSummary() {
  const total = state.transactions.reduce((sum, transaction) => sum + Number(transaction.value), 0);
  $('#monthTotal').textContent = formatCurrency(total);
  const summary = realData?.summary;
  const consumption = summary?.averageConsumption || 0;
  const distance = summary?.distance || 0;
  $('#avgConsumption').innerHTML = consumption ? `${consumption.toFixed(2).replace('.', ',')} <small>km/L</small>` : '— <small>km/L</small>';
  $('#costPerKm').textContent = distance ? formatCurrency(total / distance) : 'R$ 0,00';
  $('#totalFoot').innerHTML = `${state.transactions.length} <span>registros importados</span>`;
  if (summary) {
    const latest = state.transactions[0]?.date || summary.latestDate;
    const healthItems = $$('.health-item');
    const healthCopy = healthItems.map(item => item.querySelector('.health-info span'));
    const healthTitles = healthItems.map(item => item.querySelector('.health-info strong'));
    if (healthTitles[0]) healthTitles[0].textContent = 'Último abastecimento';
    if (healthTitles[1]) healthTitles[1].textContent = 'Combustível';
    if (healthTitles[2]) healthTitles[2].textContent = 'Manutenções';
    if (healthCopy[0]) healthCopy[0].textContent = latest ? `Em ${formatDate(latest)}` : 'Sem registros';
    if (healthCopy[1]) healthCopy[1].textContent = `${summary.refuels} abastecimentos · ${summary.liters.toLocaleString('pt-BR')} L`;
    $('.route-number strong').textContent = summary.distance.toLocaleString('pt-BR');
    $('.route-number span').textContent = 'km registrados';
    $('.route-progress span').style.width = '100%';
    $('.route-caption span').textContent = `${formatDate(summary.earliestDate)} a ${formatDate(summary.latestDate)}`;
    $('.route-caption strong').textContent = `${summary.refuels + summary.expenses} registros`;
    const routeStats = $$('.route-stats strong');
    if (routeStats[0]) routeStats[0].textContent = summary.refuels;
    if (routeStats[1]) routeStats[1].textContent = `${Math.max(...(realData.events || []).map(event => event.distance || 0)).toLocaleString('pt-BR')} km`;
    const routeLabels = $$('.route-stats span');
    if (routeLabels[0]) routeLabels[0].textContent = 'Abastecimentos';
    if (routeLabels[1]) routeLabels[1].textContent = 'Maior trecho';
    $('.route-year').textContent = 'Drivvo';
    $('#maintenanceButton').textContent = 'Ver histórico importado →';
    $('#docCount').innerHTML = '0 <small>disponíveis</small>';
    $('#docFoot').textContent = 'Nenhum documento no CSV';
    $('.document-list').innerHTML = '<div class="empty-state">O CSV trouxe abastecimentos e despesas, mas nenhum documento. Você pode adicionar arquivos depois.</div>';
  }
}

function categoryMeta(category) {
  return {
    Abastecimento: ['fuel-bg', 'fuel'],
    Manutenção: ['wrench-bg', 'wrench'],
    Seguro: ['insurance-bg', 'shield'],
    Documento: ['doc-bg', 'file'],
    Outro: ['doc-bg', 'file']
  }[category] || ['doc-bg', 'file'];
}

function renderActivity() {
  const list = $('#activityList');
  if (!state.transactions.length) {
    list.innerHTML = '<div class="empty-state">Nenhum lançamento ainda. Use “Novo lançamento” para começar.</div>';
    return;
  }
  list.innerHTML = state.transactions.slice(0, 8).map(transaction => {
    const [className, iconName] = categoryMeta(transaction.category);
    const detail = transaction.place ? `${escapeHtml(transaction.place)} · ${formatDate(transaction.date)}` : `${escapeHtml(transaction.category)} · ${formatDate(transaction.date)}`;
    return `<div class="activity-item"><div class="activity-icon ${className}">${icon(iconName)}</div><div class="activity-copy"><strong>${escapeHtml(transaction.description)}</strong><span>${detail}</span></div><strong class="activity-value">− ${formatCurrency(transaction.value)}</strong></div>`;
  }).join('');
}

function updateVehicle(vehicleKey, notify = true) {
  const vehicle = vehicles[vehicleKey] || vehicles.hrv;
  state.vehicle = vehicles[vehicleKey] ? vehicleKey : 'hrv';
  $('#vehicleSelect').value = state.vehicle;
  $('#heroCarName').innerHTML = vehicle.year ? `${vehicle.name} <span>${vehicle.year}</span>` : vehicle.name;
  $('#heroCarDetails').textContent = vehicle.details;
  $('#heroMileage').innerHTML = `${vehicle.mileage} <small>km</small>`;
  $('#heroService').innerHTML = realData ? `${formatDate(vehicle.service)} <small>último</small>` : `${vehicle.service} <small>dias</small>`;
  $('#sideCarName').textContent = vehicle.name;
  $('#sideCarPlate').textContent = vehicle.plate;
  saveState();
  if (notify) showToast(`${vehicle.name} selecionado`);
}

function openModal(prefill = '', category = '') {
  $('#modalBackdrop').classList.add('open');
  $('#modalBackdrop').setAttribute('aria-hidden', 'false');
  $('#modalTitle').textContent = category ? `Adicionar ${category.toLowerCase()}` : 'Adicionar despesa';
  const description = $('input[name="description"]');
  const categoryField = $('select[name="category"]');
  if (prefill) description.value = prefill;
  if (category && [...categoryField.options].some(option => option.value === category)) categoryField.value = category;
  setTimeout(() => description.focus(), 60);
}

function closeModal() {
  $('#modalBackdrop').classList.remove('open');
  $('#modalBackdrop').setAttribute('aria-hidden', 'true');
  $('#expenseForm').reset();
  $('input[name="date"]').value = todayISO();
  $('#modalTitle').textContent = 'Adicionar despesa';
}

function addTransaction(form) {
  const transaction = {
    description: form.get('description').trim(),
    category: form.get('category'),
    date: form.get('date') || todayISO(),
    value: Number(form.get('value'))
  };
  state.transactions.unshift(transaction);
  saveState();
  renderActivity();
  renderSummary();
  closeModal();
  showToast('Lançamento salvo com sucesso');
}

// The icon helper lives in index.html so the page stays dependency-free.
document.body.innerHTML = document.body.innerHTML.replace(/\$\{icon\('([^']+)'\)\}/g, (_, name) => icon(name));

function prepareVehicleSelect() {
  const select = $('#vehicleSelect');
  const options = Object.entries(vehicles).map(([id, vehicle]) => `<option value="${id}">${escapeHtml(vehicle.name)}</option>`).join('');
  select.innerHTML = options;
  $('.select-car-dot').title = realData ? 'Dados importados do Drivvo' : 'Veículo ativo';
}

$('#vehicleSelect').addEventListener('change', event => updateVehicle(event.target.value));
$('#periodSelect').addEventListener('change', event => renderChart(event.target.value));
$('#openExpense').addEventListener('click', () => openModal());
$('#closeModal').addEventListener('click', closeModal);
$('#cancelModal').addEventListener('click', closeModal);
$('#modalBackdrop').addEventListener('click', event => { if (event.target === $('#modalBackdrop')) closeModal(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape' && $('#modalBackdrop').classList.contains('open')) closeModal(); });

$('#expenseForm').addEventListener('submit', event => {
  event.preventDefault();
  const form = new FormData(event.target);
  const value = Number(form.get('value'));
  if (!form.get('description').trim() || !Number.isFinite(value) || value <= 0) return showToast('Preencha uma descrição e um valor válido');
  addTransaction(form);
});

$$('.action-card').forEach(card => card.addEventListener('click', () => {
  const action = card.dataset.action;
  const category = ['Abastecimento', 'Manutenção', 'Seguro'].includes(action) ? action : '';
  openModal(action === 'Viagem' ? '' : action, category);
}));

$('#maintenanceButton').addEventListener('click', () => showToast('Plano de manutenção atualizado: tudo em dia'));
$('#helpButton').addEventListener('click', () => showToast('Suporte online — responderemos em breve'));
$('#notificationButton').addEventListener('click', () => showToast('Você não tem novas notificações'));
$('#allActivity').addEventListener('click', () => showToast(`${state.transactions.length} lançamento(s) no histórico`));
$('#sideCarButton').addEventListener('click', () => {
  const keys = Object.keys(vehicles);
  if (keys.length < 2) return showToast('Apenas um veículo foi encontrado no CSV');
  updateVehicle(keys[(keys.indexOf(state.vehicle) + 1) % keys.length]);
});
$('#addDocumentButton').addEventListener('click', () => showToast('Selecione um arquivo para guardar no carro'));
$('#tripButton').addEventListener('click', () => openModal('Viagem', ''));
$$('.document-more').forEach(button => button.addEventListener('click', () => showToast(`${button.dataset.document}: opções disponíveis em breve`)));
$$('.nav-item').forEach(item => item.addEventListener('click', () => {
  $$('.nav-item').forEach(nav => nav.classList.remove('active'));
  item.classList.add('active');
  if (window.innerWidth <= 900) $('.sidebar').classList.remove('open');
}));
$('.mobile-menu').addEventListener('click', () => $('.sidebar').classList.toggle('open'));
document.addEventListener('click', event => { if (window.innerWidth <= 900 && !event.target.closest('.sidebar') && !event.target.closest('.mobile-menu')) $('.sidebar').classList.remove('open'); });

prepareVehicleSelect();
$('input[name="date"]').value = todayISO();
updateVehicle(state.vehicle, false);
renderActivity();
renderSummary();
renderChart();
