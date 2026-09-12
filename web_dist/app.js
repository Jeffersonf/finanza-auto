'use strict';

const SOURCE_DATA = window.FINANZA_AUTO_REAL_DATA || {
  vehicles: [{ id: 'vehicle-1', name: 'Meu carro', plate: '', model: '', odometer: 0 }],
  events: [],
  summary: {}
};
const STORAGE_KEY = 'finanza-auto-car-state-v1';
const THEME_KEY = 'finanza-auto-theme';

const state = loadState();
const filters = {
  vehicle: state.activeVehicleId || 'all',
  period: 'all',
  type: 'all',
  kind: 'all',
  query: '',
  sort: 'date_desc',
  from: '',
  to: ''
};
let entryType = 'fuel';
let toastTimer;
let chartMode = 'bars';

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
const money = value => `R$ ${Number(value || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const dateText = value => {
  if (!value) return '—';
  try {
    const d = new Date(`${String(value).slice(0, 10)}T12:00:00`);
    return new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' }).format(d);
  } catch (_) {
    return value;
  }
};
const esc = value => String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[char]));

function uid(prefix = 'local') {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}
function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function normalizeVehicle(vehicle) {
  return {
    id: String(vehicle.id || uid('vehicle')),
    name: String(vehicle.name || 'Meu carro'),
    plate: String(vehicle.plate || '').toUpperCase(),
    model: String(vehicle.model || ''),
    odometer: Number(vehicle.odometer) || 0
  };
}

function normalizeEvent(event, vehicleId) {
  const fuel = event.type === 'fuel';
  return {
    id: String(event.id || uid('event')),
    vehicleId: String(event.vehicleId || vehicleId),
    type: fuel ? 'fuel' : 'expense',
    date: String(event.date || new Date().toISOString()).slice(0, 10),
    odometer: Number(event.odometer) || 0,
    fuelType: String(event.fuelType || 'Gasolina'),
    liters: Number(event.liters) || 0,
    pricePerLiter: Number(event.pricePerLiter || 0),
    amount: Number(event.amount || 0),
    title: String(event.title || ''),
    category: String(event.category || (fuel ? 'Combustivel' : 'Other')),
    note: String(event.note || event.place || '')
  };
}

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved?.vehicles?.length && Array.isArray(saved.events)) {
      return {
        vehicles: saved.vehicles.map(normalizeVehicle),
        events: saved.events.map(event => normalizeEvent(event, saved.vehicles[0].id)),
        activeVehicleId: saved.activeVehicleId || saved.vehicles[0].id
      };
    }
  } catch (error) {
    /* fallback to bundled data */
  }
  const vehicles = (SOURCE_DATA.vehicles || []).map(normalizeVehicle);
  const vehicleId = vehicles[0]?.id || 'vehicle-1';
  return {
    vehicles: vehicles.length ? vehicles : [normalizeVehicle({ id: vehicleId })],
    events: (SOURCE_DATA.events || []).map(event => normalizeEvent(event, vehicleId)),
    activeVehicleId: vehicleId
  };
}

function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (error) {
    /* storage may be blocked */
  }
}

function vehicleById(id) {
  return state.vehicles.find(vehicle => vehicle.id === id) || state.vehicles[0];
}

function vehicleName(id) {
  return vehicleById(id)?.name || 'Meu carro';
}

function notify(message, kind = '') {
  const toast = $('#toast');
  if (!toast) return;
  toast.textContent = message;
  toast.className = `toast show ${kind}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    toast.className = 'toast';
  }, 3000);
}

// Theme Management
function initTheme() {
  const saved = localStorage.getItem(THEME_KEY) || 'dark';
  applyTheme(saved, false);
}

function applyTheme(theme, save = true) {
  document.documentElement.setAttribute('data-theme', theme);
  const metaTheme = $('meta[name="theme-color"]');
  if (metaTheme) metaTheme.content = theme === 'dark' ? '#090a0f' : '#f4f5f8';
  if (save) localStorage.setItem(THEME_KEY, theme);

  const themeLabel = $('#themeLabel');
  if (themeLabel) {
    themeLabel.textContent = theme === 'dark' ? 'Tema escuro' : 'Tema claro';
  }
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || 'dark';
  const next = current === 'dark' ? 'light' : 'dark';
  applyTheme(next, true);
  notify(next === 'dark' ? 'Tema escuro ativado' : 'Tema claro ativado', 'success');
}

// Filter and stats logic
function periodRange() {
  if (filters.period === 'all') return {};
  if (filters.period === 'custom') return { from: filters.from, to: filters.to };
  const now = new Date();
  if (filters.period === 'month') {
    return {
      from: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`,
      to: now.toISOString().slice(0, 10)
    };
  }
  const days = filters.period === 'year' ? 365 : Number(filters.period.replace('d', ''));
  const from = new Date(now);
  from.setDate(from.getDate() - days + 1);
  return { from: from.toISOString().slice(0, 10), to: now.toISOString().slice(0, 10) };
}

function filteredEvents() {
  const range = periodRange();
  let events = [...state.events];
  if (filters.vehicle !== 'all') events = events.filter(event => event.vehicleId === filters.vehicle);
  if (range.from) events = events.filter(event => event.date >= range.from);
  if (range.to) events = events.filter(event => event.date <= range.to);
  if (filters.type !== 'all') events = events.filter(event => event.type === filters.type);
  if (filters.kind !== 'all') {
    events = events.filter(event =>
      event.type === 'fuel' ? `fuel:${event.fuelType.toLowerCase()}` === filters.kind : `cat:${event.category}` === filters.kind
    );
  }
  if (filters.query) {
    const query = filters.query.toLowerCase();
    events = events.filter(event =>
      [vehicleName(event.vehicleId), event.fuelType, event.title, event.category, event.note, event.odometer]
        .join(' ')
        .toLowerCase()
        .includes(query)
    );
  }
  const direction = filters.sort.endsWith('_asc') ? 1 : -1;
  if (filters.sort.startsWith('odo')) events.sort((a, b) => ((a.odometer || 0) - (b.odometer || 0)) * direction);
  else if (filters.sort.startsWith('amount')) events.sort((a, b) => ((a.amount || 0) - (b.amount || 0)) * direction);
  else events.sort((a, b) => a.date.localeCompare(b.date) * direction || a.id.localeCompare(b.id) * direction);
  return events;
}

function eventStats(events) {
  const fuels = events
    .filter(event => event.type === 'fuel' && event.liters > 0 && event.odometer > 0)
    .sort((a, b) => a.odometer - b.odometer || a.date.localeCompare(b.date));
  const latest = fuels.at(-1);
  const previous = fuels.at(-2);
  const distance = latest && previous ? Math.max(0, latest.odometer - previous.odometer) : 0;
  const intervalEvents = latest && previous ? events.filter(event => event.date >= previous.date && event.date <= latest.date) : [];
  const total = events.reduce((sum, event) => sum + event.amount, 0);
  const fuelTotal = events.filter(event => event.type === 'fuel').reduce((sum, event) => sum + event.amount, 0);
  const expenseTotal = total - fuelTotal;

  return {
    total,
    fuelTotal,
    expenseTotal,
    fuelCount: events.filter(event => event.type === 'fuel').length,
    expenseCount: events.filter(event => event.type === 'expense').length,
    distance,
    liters: latest?.liters || 0,
    kmPerLiter: distance && latest?.liters ? distance / latest.liters : 0,
    costPerKm: distance ? intervalEvents.reduce((sum, event) => sum + event.amount, 0) / distance : 0,
    avgTicket: events.length ? total / events.length : 0,
    lastEvent: events[0],
    maxOdo: Math.max(0, ...events.map(event => event.odometer || 0)),
    avgFuelPrice:
      events.filter(event => event.type === 'fuel' && event.liters).reduce((sum, event) => sum + event.amount, 0) /
        (events.filter(event => event.type === 'fuel' && event.liters).reduce((sum, event) => sum + event.liters, 0) || 1),
    topKind: [...events.reduce((map, event) => {
      const key = event.type === 'fuel' ? event.fuelType : event.title || event.category;
      map.set(key, (map.get(key) || 0) + event.amount);
      return map;
    }, new Map())].sort((a, b) => b[1] - a[1])[0]
  };
}

function expenseLabel(category) {
  return (
    {
      Maintenance: 'Manutenção',
      Insurance: 'Seguro',
      Tax: 'Imposto',
      Parking: 'Estacionamento',
      Wash: 'Lavagem',
      Fine: 'Multa',
      Other: 'Outro'
    }[category] || category || 'Despesa'
  );
}

function expenseIconSvg(category) {
  switch (category) {
    case 'Maintenance':
      return '🔧';
    case 'Insurance':
      return '🛡️';
    case 'Tax':
      return '📑';
    case 'Parking':
      return '🅿️';
    case 'Wash':
      return '🧼';
    case 'Fine':
      return '⚠️';
    default:
      return '📦';
  }
}

function renderControls() {
  const vehicleSelect = $('#carVehicleFilter');
  if (vehicleSelect) {
    vehicleSelect.innerHTML = `<option value="all">Todos os veículos (${state.vehicles.length})</option>${state.vehicles
      .map(v => `<option value="${esc(v.id)}">${esc(v.name)}${v.plate ? ` (${esc(v.plate)})` : ''}</option>`)
      .join('')}`;
    vehicleSelect.value = filters.vehicle;
  }

  const periodFilter = $('#carPeriodFilter');
  if (periodFilter) periodFilter.value = filters.period;

  const typeFilter = $('#carTypeFilter');
  if (typeFilter) typeFilter.value = filters.type;

  const sortFilter = $('#carSortFilter');
  if (sortFilter) sortFilter.value = filters.sort;

  const searchFilter = $('#carSearchFilter');
  if (searchFilter) searchFilter.value = filters.query;

  const customRange = $('#customRange');
  if (customRange) customRange.classList.toggle('open', filters.period === 'custom');

  const fromFilter = $('#carFromFilter');
  if (fromFilter) fromFilter.value = filters.from;

  const toFilter = $('#carToFilter');
  if (toFilter) toFilter.value = filters.to;

  const kinds = new Map();
  state.events.forEach(event => {
    const key = event.type === 'fuel' ? `fuel:${event.fuelType.toLowerCase()}` : `cat:${event.category}`;
    const label = event.type === 'fuel' ? `Combustível: ${event.fuelType}` : `Despesa: ${expenseLabel(event.category)}`;
    kinds.set(key, label);
  });
  const kindFilter = $('#carKindFilter');
  if (kindFilter) {
    kindFilter.innerHTML = `<option value="all">Todos combustíveis / categorias</option>${[...kinds]
      .map(([key, label]) => `<option value="${esc(key)}">${esc(label)}</option>`)
      .join('')}`;
    kindFilter.value = kinds.has(filters.kind) ? filters.kind : 'all';
  }
}

function renderStats(events, stats) {
  const cards = [
    {
      label: 'Gastos totais',
      value: money(stats.total),
      caption: `${events.length} registro${events.length === 1 ? '' : 's'} (${money(stats.fuelTotal)} comb. · ${money(stats.expenseTotal)} desp.)`,
      tone: 'blue',
      icon: '💳'
    },
    {
      label: 'Consumo médio',
      value: stats.kmPerLiter ? `${stats.kmPerLiter.toFixed(1).replace('.', ',')} km/l` : '—',
      caption: stats.liters ? `${stats.liters.toLocaleString('pt-BR', { maximumFractionDigits: 1 })} L no último abastecimento` : 'precisa de 2 abastecimentos',
      tone: 'mint',
      icon: '⚡'
    },
    {
      label: 'Custo por km',
      value: stats.costPerKm ? money(stats.costPerKm) : '—',
      caption: stats.distance ? `baseado em ${Math.round(stats.distance).toLocaleString('pt-BR')} km rodados` : 'sem dados de distância',
      tone: 'amber',
      icon: '📊'
    },
    {
      label: 'Km rodados',
      value: stats.distance ? `${Math.round(stats.distance).toLocaleString('pt-BR')} km` : '—',
      caption: 'distância no intervalo acompanhado',
      tone: 'mint',
      icon: '🛣️'
    },
    {
      label: 'Hodômetro atual',
      value: stats.maxOdo ? `${Math.round(stats.maxOdo).toLocaleString('pt-BR')} km` : '—',
      caption: 'maior leitura registrada no sistema',
      tone: 'purple',
      icon: '🏎️'
    },
    {
      label: 'Preço médio / Litro',
      value: stats.avgFuelPrice ? money(stats.avgFuelPrice) : '—',
      caption: `${stats.fuelCount} abastecimento${stats.fuelCount === 1 ? '' : 's'} no período`,
      tone: 'amber',
      icon: '🏷️'
    }
  ];

  const statsContainer = $('#carStats');
  if (statsContainer) {
    statsContainer.innerHTML = cards
      .map(
        c => `
      <article class="insight-card">
        <div class="insight-card-head">
          <span class="insight-k">${c.label}</span>
          <div class="insight-icon-box ${c.tone}">${c.icon}</div>
        </div>
        <div class="insight-v ${c.tone}">${c.value}</div>
        <div class="insight-caption">${c.caption}</div>
      </article>`
      )
      .join('');
  }
}

function renderMaintenance(events) {
  const maintenance = events.filter(event => event.type === 'expense');
  const latest = [...maintenance].sort((a, b) => b.date.localeCompare(a.date))[0];
  const highest = Math.max(0, ...events.map(event => event.odometer || 0));

  // Find last oil service
  const oilServices = maintenance.filter(e => /oleo|óleo|filtro|revis/i.test(`${e.title} ${e.note}`));
  const lastOil = oilServices.sort((a, b) => b.odometer - a.odometer || b.date.localeCompare(a.date))[0];
  const nextOilKm = lastOil && lastOil.odometer > 0 ? lastOil.odometer + 7000 : highest + 5000;
  const remainingKm = nextOilKm - highest;

  const vendors = new Map();
  events.forEach(event => {
    const vendor = event.note || '';
    if (vendor && !/^importado do drivvo$/i.test(vendor)) {
      vendors.set(vendor, (vendors.get(vendor) || 0) + event.amount);
    }
  });
  const topVendors = [...vendors].sort((a, b) => b[1] - a[1]).slice(0, 4);

  const container = $('#carMaintenancePanel');
  if (!container) return;

  container.innerHTML = `
    <div class="maintenance-grid">
      <div class="maintenance-card">
        <div class="maintenance-k">Próxima troca de óleo</div>
        <div class="maintenance-v ${remainingKm <= 0 ? 'coral' : 'mint'}">
          ${lastOil ? (remainingKm <= 0 ? 'Vencida!' : `${Math.round(remainingKm).toLocaleString('pt-BR')} km`) : '—'}
        </div>
        <div class="insight-caption">
          ${lastOil ? `Última em ${dateText(lastOil.date)} (${Math.round(lastOil.odometer).toLocaleString('pt-BR')} km)` : 'cadastre troca de óleo para estimar'}
        </div>
      </div>
      <div class="maintenance-card">
        <div class="maintenance-k">Hodômetro conhecido</div>
        <div class="maintenance-v">${highest ? Math.round(highest).toLocaleString('pt-BR') : '—'} km</div>
        <div class="insight-caption">maior leitura importada</div>
      </div>
      <div class="maintenance-card">
        <div class="maintenance-k">Ações rápidas</div>
        <div class="maintenance-actions">
          <button class="btn btn-primary" data-maintenance="oil">+ Troca de óleo</button>
          <button class="btn btn-ghost" data-maintenance="review">+ Revisão</button>
        </div>
        <div class="insight-caption" style="margin-top: 6px;">abre formulário pré-preenchido</div>
      </div>
    </div>
    <div class="maintenance-lower">
      <div class="sub-panel">
        <h4>Postos e oficinas frequentes</h4>
        <p>Locais onde você mais investe no veículo</p>
        <div class="vendor-list">
          ${
            topVendors.length
              ? topVendors
                  .map(
                    ([vendor, amount]) => `
              <div class="vendor-row">
                <div>
                  <strong>${esc(vendor)}</strong>
                  <span>acumulado no histórico</span>
                </div>
                <b>${money(amount)}</b>
              </div>`
                  )
                  .join('')
              : '<div class="empty">Sem observações de postos/locais nos registros.</div>'
          }
        </div>
      </div>
      <div class="sub-panel">
        <h4>Última manutenção registrada</h4>
        <p>Serviços salvos no período filtrado</p>
        <div class="vendor-list">
          ${
            latest
              ? `
            <div class="vendor-row">
              <div>
                <strong>${esc(latest.title || expenseLabel(latest.category))}</strong>
                <span>${dateText(latest.date)} · ${esc(latest.note || 'sem detalhes')}</span>
              </div>
              <b>${money(latest.amount)}</b>
            </div>`
              : '<div class="empty">Nenhum serviço ou despesa encontrado no filtro.</div>'
          }
        </div>
      </div>
    </div>`;

  $$('[data-maintenance]').forEach(btn =>
    btn.addEventListener('click', () => openEntry('expense', btn.dataset.maintenance === 'oil' ? 'Troca de óleo' : 'Revisão geral'))
  );
}

function renderChart(events) {
  const dates = events.map(event => event.date).sort();
  const latest = dates.at(-1) || new Date().toISOString().slice(0, 10);
  const end = new Date(`${latest.slice(0, 7)}-01T12:00:00`);
  const months = [];
  for (let i = 11; i >= 0; i -= 1) {
    const d = new Date(end);
    d.setMonth(d.getMonth() - i);
    months.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
  }
  const values = key => events.filter(e => e.date.slice(0, 7) === key).reduce((sum, e) => sum + e.amount, 0);
  const current = months.map(values);
  const previous = months.map(key => values(`${Number(key.slice(0, 4)) - 1}${key.slice(4)}`));
  const max = Math.max(100, ...current, ...previous) * 1.15;

  const axisTop = $('#axisTop');
  if (axisTop) axisTop.textContent = money(max);

  const chartTotal = $('#chartTotal');
  if (chartTotal) {
    chartTotal.textContent = `${money(current.reduce((sum, value) => sum + value, 0))} no período`;
  }

  const spendLabels = $('#spendLabels');
  if (spendLabels) {
    spendLabels.innerHTML = months
      .map(
        key =>
          `<span>${new Intl.DateTimeFormat('pt-BR', { month: 'short' })
            .format(new Date(`${key}-01T12:00:00`))
            .replace('.', '')}</span>`
      )
      .join('');
  }

  const spendChart = $('#spendChart');
  if (!spendChart) return;

  if (chartMode === 'line') {
    spendChart.innerHTML = current
      .map(
        value =>
          `<span class="line-point" style="--pos:${100 - (value / max) * 100}%" title="${money(value)}"></span>`
      )
      .join('');
  } else {
    spendChart.innerHTML = current
      .map(
        (value, index) => `
        <div class="bar-group">
          <span class="bar previous" style="height:${Math.max(3, (previous[index] / max) * 100)}%" title="Anterior: ${money(previous[index])}"></span>
          <span class="bar" style="height:${Math.max(3, (value / max) * 100)}%" title="Atual: ${money(value)}"></span>
        </div>`
      )
      .join('');
  }
}

function renderHistory(events) {
  const countEl = $('#resultCount');
  if (countEl) countEl.textContent = `${events.length} registro${events.length === 1 ? '' : 's'}`;

  const listEl = $('#carList');
  if (!listEl) return;

  if (!events.length) {
    listEl.innerHTML = `
      <div class="empty">
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" style="opacity: 0.5;"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        <span>Nenhum registro encontrado com os filtros selecionados.</span>
      </div>`;
    return;
  }

  listEl.innerHTML = events
    .map(event => {
      const fuel = event.type === 'fuel';
      const title = fuel
        ? `${event.fuelType} · ${event.liters.toLocaleString('pt-BR', { maximumFractionDigits: 2 })} L`
        : event.title || expenseLabel(event.category);
      const metaParts = [
        filters.vehicle === 'all' ? vehicleName(event.vehicleId) : '',
        dateText(event.date),
        event.odometer ? `${Math.round(event.odometer).toLocaleString('pt-BR')} km` : '',
        fuel && event.pricePerLiter ? `${money(event.pricePerLiter)}/L` : '',
        event.note
      ].filter(Boolean);

      return `
      <div class="car-row">
        <div class="car-ico ${fuel ? 'fuel' : 'expense'}">
          ${fuel ? '⛽' : expenseIconSvg(event.category)}
        </div>
        <div class="car-info">
          <div class="car-name">${esc(title)}</div>
          <div class="car-meta">${esc(metaParts.join(' · ') || 'Sem detalhes')}</div>
        </div>
        <div class="car-amt">${money(event.amount)}</div>
        <button class="car-delete" data-delete="${esc(event.id)}" aria-label="Remover registro" title="Excluir">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
      </div>`;
    })
    .join('');

  $$('.car-delete').forEach(button =>
    button.addEventListener('click', () => deleteEvent(button.dataset.delete))
  );
}

function renderAll() {
  const events = filteredEvents();
  const stats = eventStats(events);
  const vehicle = vehicleById(filters.vehicle === 'all' ? state.activeVehicleId : filters.vehicle);

  const titleView = $('#carTitleView');
  if (titleView) {
    titleView.textContent =
      filters.vehicle === 'all'
        ? state.vehicles.length > 1
          ? 'Todos os veículos'
          : vehicle?.name || 'Meu carro'
        : vehicle?.name || 'Meu carro';
  }

  const subView = $('#carSubView');
  if (subView) {
    subView.textContent =
      [vehicle?.model, vehicle?.plate, stats.maxOdo ? `${Math.round(stats.maxOdo).toLocaleString('pt-BR')} km` : '']
        .filter(Boolean)
        .join(' · ') || 'Consumo, abastecimentos e despesas';
  }

  const sourceLabel = $('#dataSourceLabel');
  if (sourceLabel) {
    sourceLabel.textContent = `${SOURCE_DATA.summary?.source || 'Dados locais'} (${state.events.length} reg.)`;
  }

  const lastUpdated = $('#lastUpdated');
  if (lastUpdated) {
    lastUpdated.textContent = stats.lastEvent ? `Último: ${dateText(stats.lastEvent.date)}` : 'Sem registros';
  }

  renderControls();
  renderStats(events, stats);
  renderMaintenance(events);
  renderChart(events);
  renderHistory(events);
}

function setEntryType(type) {
  entryType = type;
  $('#fuelTypeTab')?.classList.toggle('active', type === 'fuel');
  $('#expenseTypeTab')?.classList.toggle('active', type === 'expense');
  const fuelFields = $('#fuelFields');
  const expenseFields = $('#expenseFields');
  if (fuelFields) fuelFields.hidden = type !== 'fuel';
  if (expenseFields) expenseFields.hidden = type !== 'expense';
  const modalTitle = $('#carModalTitle');
  if (modalTitle) modalTitle.textContent = type === 'fuel' ? 'Novo abastecimento' : 'Nova despesa';
}

function populateEntryVehicles() {
  const select = $('#carEntryVehicle');
  if (!select) return;
  select.innerHTML = state.vehicles
    .map(v => `<option value="${esc(v.id)}">${esc(v.name)}${v.plate ? ` · ${esc(v.plate)}` : ''}</option>`)
    .join('');
  select.value = state.activeVehicleId;
}

function openEntry(type = 'fuel', title = '') {
  setEntryType(type);
  populateEntryVehicles();
  $('#carDate').value = new Date().toISOString().slice(0, 10);
  $('#carOdo').value = vehicleById(state.activeVehicleId)?.odometer || '';
  $('#carFuelType').value = 'Gasolina';
  $('#carLiters').value = '';
  $('#carPrice').value = '';
  $('#carAmount').value = '';
  $('#carAmount').dataset.manual = '';
  $('#carAmountExpense').value = '';
  $('#carTitle').value = title;
  $('#carNote').value = '';
  $('#carModal')?.classList.add('open');
  setTimeout(() => (type === 'fuel' ? $('#carLiters') : $('#carTitle'))?.focus(), 50);
}

function closeModal(id) {
  $(`#${id}`)?.classList.remove('open');
}

function saveEntry() {
  const vehicleId = $('#carEntryVehicle').value;
  const fuel = entryType === 'fuel';
  const liters = Number($('#carLiters').value) || 0;
  const price = Number($('#carPrice').value) || 0;
  const amount = fuel ? Number($('#carAmount').value) || liters * price : Number($('#carAmountExpense').value);

  if (!amount || amount <= 0 || (fuel && (!liters || !price))) {
    return notify(fuel ? 'Informe litros, preço e valor válidos.' : 'Informe um valor válido.', 'error');
  }

  const event = normalizeEvent(
    {
      id: uid('event'),
      vehicleId,
      type: entryType,
      date: $('#carDate').value,
      odometer: Number($('#carOdo').value) || 0,
      fuelType: $('#carFuelType').value,
      liters,
      pricePerLiter: price,
      amount,
      title: $('#carTitle').value.trim(),
      category: $('#carCategory').value,
      note: $('#carNote').value.trim()
    },
    vehicleId
  );

  state.events.unshift(event);
  const vehicle = vehicleById(vehicleId);
  vehicle.odometer = Math.max(vehicle.odometer, event.odometer);
  state.activeVehicleId = vehicleId;
  saveState();
  closeModal('carModal');
  filters.vehicle = vehicleId;
  renderAll();
  notify('Lançamento salvo com sucesso.', 'success');
}

function deleteEvent(id) {
  if (!confirm('Deseja realmente remover este lançamento?')) return;
  state.events = state.events.filter(event => event.id !== id);
  saveState();
  renderAll();
  notify('Lançamento removido.', 'success');
}

function saveVehicle() {
  const id = $('#carVehicleId').value;
  const name = $('#carVehicleName').value.trim();
  if (!name) return notify('Informe o nome do veículo.', 'error');

  const vehicle = normalizeVehicle({
    id: id || uid('vehicle'),
    name,
    plate: $('#carPlate').value.trim().toUpperCase(),
    model: $('#carModel').value.trim(),
    odometer: Number($('#carVehicleOdo').value) || 0
  });

  const index = state.vehicles.findIndex(item => item.id === id);
  if (index >= 0) state.vehicles[index] = vehicle;
  else state.vehicles.push(vehicle);

  state.activeVehicleId = vehicle.id;
  filters.vehicle = vehicle.id;
  saveState();
  closeModal('carVehicleModal');
  renderAll();
  notify('Veículo salvo com sucesso.', 'success');
}

function openVehicle(id = '') {
  const vehicle = vehicleById(id || state.activeVehicleId);
  $('#vehicleModalTitle').textContent = id ? 'Editar veículo' : 'Novo veículo';
  $('#carVehicleId').value = id;
  $('#carVehicleName').value = id ? vehicle.name : '';
  $('#carPlate').value = id ? vehicle.plate : '';
  $('#carModel').value = id ? vehicle.model : '';
  $('#carVehicleOdo').value = id ? vehicle.odometer : '';
  const delBtn = $('#deleteVehicleButton');
  if (delBtn) delBtn.style.display = id && state.vehicles.length > 1 ? 'inline-block' : 'none';
  $('#carVehicleModal')?.classList.add('open');
}

function deleteVehicle() {
  const id = $('#carVehicleId').value;
  if (!id || state.vehicles.length <= 1) return notify('Mantenha pelo menos um veículo cadastrado.', 'error');
  if (state.events.some(event => event.vehicleId === id)) {
    return notify('Esse veículo possui registros associados. Remova-os antes de excluir.', 'error');
  }
  state.vehicles = state.vehicles.filter(v => v.id !== id);
  state.activeVehicleId = state.vehicles[0].id;
  filters.vehicle = state.activeVehicleId;
  saveState();
  closeModal('carVehicleModal');
  renderAll();
  notify('Veículo removido.', 'success');
}

function exportBackup() {
  const payload = {
    app: 'Finanza Auto',
    version: '2.0',
    exportedAt: new Date().toISOString(),
    source: SOURCE_DATA.summary,
    car: {
      vehicles: clone(state.vehicles),
      events: clone(state.events),
      activeVehicleId: state.activeVehicleId
    }
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json;charset=utf-8' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = `finanza-auto-backup-${new Date().toISOString().slice(0, 10)}.json`;
  link.click();
  URL.revokeObjectURL(link.href);
  notify('Backup JSON exportado com sucesso.', 'success');
}

function parseCsvRows(text) {
  const rows = [];
  let row = [],
    cell = '',
    quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    const next = text[i + 1];
    if (char === '"' && quoted && next === '"') {
      cell += '"';
      i += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === ',' && !quoted) {
      row.push(cell);
      cell = '';
    } else if ((char === '\n' || char === '\r') && !quoted) {
      if (char === '\r' && next === '\n') i += 1;
      row.push(cell);
      if (row.some(value => value.trim())) rows.push(row);
      row = [];
      cell = '';
    } else {
      cell += char;
    }
  }
  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

function categoryFromText(text) {
  const value = String(text || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
  if (/seguro|insurance/.test(value)) return 'Insurance';
  if (/ipva|licenciamento|taxa|imposto|document|tax/.test(value)) return 'Tax';
  if (/estacion|parking|pedagio|toll/.test(value)) return 'Parking';
  if (/lavagem|lava|wash/.test(value)) return 'Wash';
  if (/multa|fine/.test(value)) return 'Fine';
  if (/manut|revis|oleo|pneu|oficina|service|repair|maintenance/.test(value)) return 'Maintenance';
  return 'Other';
}

function parseNumber(value) {
  const text = String(value || '').trim();
  if (!text) return 0;
  return Number(text.includes(',') && !text.includes('.') ? text.replace(',', '.') : text) || 0;
}

function importCsv(file) {
  const reader = new FileReader();
  reader.onload = () => {
    const rows = parseCsvRows(reader.result);
    let section = '';
    let headers = null;
    let added = 0;
    const known = new Set(state.events.map(event => `${event.date}|${event.amount}|${event.odometer}|${event.type}`));
    rows.forEach(row => {
      if (row[0]?.startsWith('##')) {
        section = row[0].slice(2).toLowerCase();
        headers = null;
        return;
      }
      if (!headers) {
        headers = row.map(value =>
          value
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .toLowerCase()
        );
        return;
      }
      const get = names => {
        const index = headers.findIndex(header => names.some(name => header.includes(name)));
        return index >= 0 ? row[index] : '';
      };
      const fuel = section.includes('refuelling') || section.includes('abastec');
      const amount = parseNumber(get(['valor total', 'amount', 'valor']));
      const liters = parseNumber(get(['volume', 'litros', 'liters']));
      if (!amount && !liters) return;
      const date = String(get(['data', 'date'])).slice(0, 10);
      const odometer = parseNumber(get(['odometro', 'odometer', 'quilometragem', 'km']));
      const type = fuel ? 'fuel' : 'expense';
      const fingerprint = `${date}|${amount}|${odometer}|${type}`;
      if (known.has(fingerprint)) return;
      const vehicleId = state.activeVehicleId;
      const title = get(['tipo de despesa', 'descricao', 'description']);
      state.events.push(
        normalizeEvent(
          {
            id: uid('import'),
            vehicleId,
            type,
            date,
            odometer,
            fuelType: get(['combustivel', 'fuel']) || 'Gasolina',
            liters,
            pricePerLiter: parseNumber(get(['preco / l', 'preco litro', 'price'])),
            amount,
            title,
            category: fuel ? 'Combustivel' : categoryFromText(`${title} ${row.join(' ')}`),
            note: get(['posto', 'local', 'place', 'observacao', 'note']) || 'Importado do Drivvo'
          },
          vehicleId
        )
      );
      known.add(fingerprint);
      added += 1;
    });
    if (added) {
      const vehicle = vehicleById(state.activeVehicleId);
      vehicle.odometer = Math.max(vehicle.odometer, ...state.events.map(event => event.odometer || 0));
      saveState();
      renderAll();
      notify(`${added} registros importados com sucesso.`, 'success');
    } else {
      notify('Nenhum registro novo encontrado no arquivo CSV.', 'error');
    }
  };
  reader.readAsText(file, 'UTF-8');
}

// Event Listeners setup
function setupListeners() {
  $('#newFuelButton')?.addEventListener('click', () => openEntry('fuel'));
  $('#newExpenseButton')?.addEventListener('click', () => openEntry('expense'));
  $('#newVehicleButton')?.addEventListener('click', () => openVehicle());
  $('#editVehicleButton')?.addEventListener('click', () => openVehicle(state.activeVehicleId));
  $('#saveCarButton')?.addEventListener('click', saveEntry);
  $('#saveVehicleButton')?.addEventListener('click', saveVehicle);
  $('#deleteVehicleButton')?.addEventListener('click', deleteVehicle);
  $('#exportButton')?.addEventListener('click', exportBackup);

  $('#carCsvFile')?.addEventListener('change', event => {
    if (event.target.files[0]) importCsv(event.target.files[0]);
    event.target.value = '';
  });
  $('#sideImport')?.addEventListener('change', event => {
    if (event.target.files[0]) importCsv(event.target.files[0]);
    event.target.value = '';
  });

  $('#fuelTypeTab')?.addEventListener('click', () => setEntryType('fuel'));
  $('#expenseTypeTab')?.addEventListener('click', () => setEntryType('expense'));

  // Real-time calculation in fuel modal
  const updateFuelTotal = () => {
    const l = Number($('#carLiters')?.value) || 0;
    const p = Number($('#carPrice')?.value) || 0;
    const amtInput = $('#carAmount');
    if (amtInput && (!amtInput.value || !amtInput.dataset.manual)) {
      if (l > 0 && p > 0) {
        amtInput.value = (l * p).toFixed(2);
      }
    }
  };
  $('#carLiters')?.addEventListener('input', updateFuelTotal);
  $('#carPrice')?.addEventListener('input', updateFuelTotal);
  $('#carAmount')?.addEventListener('input', () => {
    $('#carAmount').dataset.manual = '1';
  });

  // Filters
  $('#carVehicleFilter')?.addEventListener('change', event => {
    filters.vehicle = event.target.value;
    state.activeVehicleId = event.target.value === 'all' ? state.activeVehicleId : event.target.value;
    saveState();
    renderAll();
  });
  $('#carPeriodFilter')?.addEventListener('change', event => {
    filters.period = event.target.value;
    renderAll();
  });
  $('#carTypeFilter')?.addEventListener('change', event => {
    filters.type = event.target.value;
    renderAll();
  });
  $('#carKindFilter')?.addEventListener('change', event => {
    filters.kind = event.target.value;
    renderAll();
  });
  $('#carSortFilter')?.addEventListener('change', event => {
    filters.sort = event.target.value;
    renderAll();
  });
  $('#carSearchFilter')?.addEventListener('input', event => {
    filters.query = event.target.value;
    renderAll();
  });
  $('#carFromFilter')?.addEventListener('change', event => {
    filters.from = event.target.value;
    filters.period = 'custom';
    renderAll();
  });
  $('#carToFilter')?.addEventListener('change', event => {
    filters.to = event.target.value;
    filters.period = 'custom';
    renderAll();
  });

  // Chart modes
  $('#carChartBars')?.addEventListener('click', () => {
    chartMode = 'bars';
    $('#carChartBars')?.classList.add('active');
    $('#carChartLine')?.classList.remove('active');
    renderChart(filteredEvents());
  });
  $('#carChartLine')?.addEventListener('click', () => {
    chartMode = 'line';
    $('#carChartLine')?.classList.add('active');
    $('#carChartBars')?.classList.remove('active');
    renderChart(filteredEvents());
  });

  // Theme Toggles
  $('#themeToggleBtn')?.addEventListener('click', toggleTheme);
  $('#topThemeToggle')?.addEventListener('click', toggleTheme);

  // Mobile sidebar
  $('#mobileMenu')?.addEventListener('click', () => {
    $('#sidebar')?.classList.toggle('open');
    $('#sidebarBackdrop')?.classList.toggle('open');
  });
  $('#sidebarBackdrop')?.addEventListener('click', () => {
    $('#sidebar')?.classList.remove('open');
    $('#sidebarBackdrop')?.classList.remove('open');
  });

  // Modal close buttons
  $$('[data-close]').forEach(button =>
    button.addEventListener('click', () => closeModal(button.dataset.close))
  );

  // Nav item active indicator
  $$('.nav-item').forEach(item =>
    item.addEventListener('click', () => {
      $$('.nav-item').forEach(nav => nav.classList.remove('active'));
      item.classList.add('active');
      if (window.innerWidth < 960) {
        $('#sidebar')?.classList.remove('open');
        $('#sidebarBackdrop')?.classList.remove('open');
      }
    })
  );

  // Close modals on Escape key
  window.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      closeModal('carModal');
      closeModal('carVehicleModal');
    }
  });
  // Cloudflare Sync Button
  $('#cfSyncButton')?.addEventListener('click', async () => {
    const choice = confirm('Nuvem Cloudflare:\n\n• OK = Enviar dados deste navegador para a Nuvem\n• Cancelar = Baixar dados da Nuvem para este navegador');
    if (choice) {
      try {
        showToast('Enviando dados para o Cloudflare...', 'info');
        const res = await fetch('/api/sync', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            version: 1,
            generatedAt: new Date().toISOString(),
            car: {
              vehicles: state.vehicles,
              events: state.events,
              activeVehicleId: state.activeVehicleId
            }
          })
        });
        const data = await res.json();
        if (data.success) {
          showToast('Dados salvos na Nuvem Cloudflare com sucesso!', 'success');
        } else {
          showToast('Erro ao salvar: ' + (data.error || 'Falha'), 'error');
        }
      } catch (err) {
        showToast('Erro de conexão com Cloudflare: ' + err.message, 'error');
      }
    } else {
      try {
        showToast('Buscando dados na Nuvem...', 'info');
        const res = await fetch('/api/sync');
        const json = await res.json();
        if (json.empty) {
          showToast('Nenhum dado na nuvem ainda.', 'info');
          return;
        }
        const cloudData = json.data?.car || json.data || json;
        if (Array.isArray(cloudData.events) && Array.isArray(cloudData.vehicles)) {
          state.vehicles = cloudData.vehicles.map(normalizeVehicle);
          state.events = cloudData.events.map(e => normalizeEvent(e, state.vehicles[0].id));
          state.activeVehicleId = cloudData.activeVehicleId || state.vehicles[0].id;
          saveState();
          renderAll();
          showToast(`Sucesso! ${state.events.length} registros sincronizados da Nuvem.`, 'success');
        } else {
          showToast('A nuvem não continha registros válidos.', 'error');
        }
      } catch (err) {
        showToast('Erro ao baixar dados: ' + err.message, 'error');
      }
    }
  });

  // Drivvo Text/Print Import Button
  $('#drivvoTextButton')?.addEventListener('click', () => {
    const raw = prompt('Cole aqui o texto copiado de um print ou relatório do Drivvo:');
    if (!raw || !raw.trim()) return;

    let isFuel = true;
    if (raw.toLowerCase().includes('despesa') || raw.toLowerCase().includes('manuten') || raw.toLowerCase().includes('serviço')) {
      if (!raw.toLowerCase().includes('abastec')) isFuel = false;
    }

    let fuelType = 'Etanol';
    if (raw.toLowerCase().includes('gasolina')) fuelType = 'Gasolina';
    else if (raw.toLowerCase().includes('diesel')) fuelType = 'Diesel';

    let km = 0;
    const kmMatch = raw.match(/(?:od[oô]metro|km)[\s:]*([0-9.,]+)/i) || raw.match(/([0-9]{4,6}(?:[.,][0-9]+)?)\s*km/i);
    if (kmMatch) km = parseFloat(kmMatch[1].replace(/\./g, '').replace(',', '.')) || 0;

    let total = 0;
    const totalMatch = raw.match(/(?:total|valor|pago|r\$)[\s:]*(?:r\$\s*)?([0-9.,]+)/i);
    if (totalMatch) total = parseFloat(totalMatch[1].replace(/\./g, '').replace(',', '.')) || 0;

    let liters = 0;
    const litMatch = raw.match(/(?:litros?|volume|qtd)[\s:]*([0-9.,]+)/i) || raw.match(/([0-9.,]+)\s*l(?:\b|\s)/i);
    if (litMatch) liters = parseFloat(litMatch[1].replace(/\./g, '').replace(',', '.')) || 0;

    let price = 0;
    const prcMatch = raw.match(/(?:preço\s*\/\s*l|preço|unit[áa]rio)[\s:]*(?:r\$\s*)?([0-9.,]+)/i);
    if (prcMatch) price = parseFloat(prcMatch[1].replace(/\./g, '').replace(',', '.')) || 0;
    else if (total > 0 && liters > 0) price = total / liters;

    let dt = new Date().toISOString().slice(0, 10);
    const dateMatch = raw.match(/(\d{2})[/.-](\d{2})[/.-](\d{4})/);
    if (dateMatch) dt = `${dateMatch[3]}-${dateMatch[2]}-${dateMatch[1]}`;

    // Confirm before saving
    const msg = `REVISAR DADOS DO DRIVVO:\n\n` +
      `• Tipo: ${isFuel ? 'Abastecimento (' + fuelType + ')' : 'Despesa'}\n` +
      `• Valor: R$ ${total.toFixed(2)}\n` +
      `• Odômetro: ${km} km\n` +
      (isFuel ? `• Volume: ${liters.toFixed(2)} L (Preço: R$ ${price.toFixed(3)}/L)\n` : '') +
      `• Data: ${dt}\n\n` +
      `Deseja confirmar e adicionar ao histórico?`;

    if (confirm(msg)) {
      const newEvent = normalizeEvent({
        id: uid('drivvo'),
        vehicleId: state.activeVehicleId,
        type: isFuel ? 'fuel' : 'expense',
        date: dt,
        odometer: km,
        fuelType: isFuel ? fuelType : '',
        liters: isFuel ? liters : 0,
        pricePerLiter: isFuel ? price : 0,
        amount: total,
        title: isFuel ? `Abastecimento (${fuelType})` : 'Despesa importada',
        category: isFuel ? 'Combustivel' : 'Maintenance',
        note: 'Importado de texto Drivvo'
      }, state.activeVehicleId);

      state.events.unshift(newEvent);
      const vehicle = state.vehicles.find(v => v.id === state.activeVehicleId);
      if (vehicle && km > vehicle.odometer) vehicle.odometer = km;
      saveState();
      renderAll();
      showToast('Registro do Drivvo adicionado com sucesso!', 'success');
    }
  });
}

// Initial bootstrap
initTheme();
setupListeners();
renderAll();

