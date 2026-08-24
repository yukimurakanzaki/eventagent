const STORAGE_KEY = 'eventagent.cashbook.v1';
const screens = ['ringkasan', 'peserta', 'uang', 'laporan'];
const labels = { ringkasan: 'RINGKASAN', peserta: 'PESERTA', uang: 'UANG', laporan: 'LAPORAN' };
const titles = { ringkasan: 'Ringkasan Wisata Dieng', peserta: 'Peserta Wisata Dieng', uang: 'Uang Wisata Dieng', laporan: 'Laporan Kas Wisata Dieng' };

const DEFAULT_STATE = {
  event: { name: 'Wisata Dieng', startDate: '2026-09-12', endDate: '2026-09-14', participantCapacity: 18, finalBudget: 14000000, sponsorContribution: 0, openingBalance: 500000 },
  participants: [
    { id: 'p-sari', name: 'Bu Sari', status: 'active', role: 'Ketua bendahara', payment: 750000 },
    { id: 'p-darto', name: 'Pak Darto', status: 'active', role: '—', payment: 0 },
    { id: 'p-lina', name: 'Ibu Lina', status: 'active', role: '—', payment: 750000 },
    { id: 'p-budi', name: 'Pak Budi', status: 'cancelled', role: 'diganti oleh Pak Roni', payment: 300000, refundPolicy: 'none' },
    { id: 'p-roni', name: 'Pak Roni', status: 'active', role: 'pengganti Pak Budi', payment: 300000 }
  ],
  transactions: [
    { id: 't-opening', type: 'opening_balance', label: 'Saldo awal / carry-over', amount: 500000 },
    { id: 't-participant-total', type: 'participant_payment', label: 'Pembayaran peserta lain', amount: 9000000 },
    { id: 't-sari', type: 'participant_payment', participantId: 'p-sari', label: 'Bu Sari', amount: 750000 },
    { id: 't-lina', type: 'participant_payment', participantId: 'p-lina', label: 'Ibu Lina', amount: 750000 },
    { id: 't-budi', type: 'participant_payment', participantId: 'p-budi', label: 'Pak Budi', amount: 300000 },
    { id: 't-roni', type: 'participant_payment', participantId: 'p-roni', label: 'Pak Roni', amount: 300000 },
    { id: 't-bus', type: 'expense', label: 'Sewa bus pariwisata', amount: 4000000, category: 'Transportasi' },
    { id: 't-hotel', type: 'expense', label: 'Uang muka penginapan', amount: 1000000, category: 'Akomodasi' },
    { id: 't-banner', type: 'expense', label: 'Spanduk acara', amount: 50000, category: 'Lainnya' }
  ],
  reminders: [
    { id: 'r-bus-dp', title: 'Bayar DP bus', dueAt: '2026-08-28', note: 'Pastikan bukti pembayaran disimpan.', status: 'open' },
    { id: 'r-collection-2', title: 'Tagih pembayaran peserta tahap 2', dueAt: '2026-09-05', note: 'Hubungi peserta yang masih sebagian atau belum bayar.', status: 'open' },
    { id: 'r-headcount', title: 'Konfirmasi jumlah peserta', dueAt: '2026-09-10', note: 'Kapasitas acara tetap 18 orang.', status: 'done' }
  ],
  syncQueue: [],
  paymentModelVersion: 2,
  reportNote: 'Pak Budi batal dan digantikan Pak Roni. Kontribusi tambahan akan dibahas saat pertemuan berikutnya.'
};

let state = loadState();
let modalMode = 'participant';
let modalParticipantId = null;
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));
const formatIDR = (value) => new Intl.NumberFormat('id-ID').format(Math.max(0, Number(value) || 0));
const activeCount = () => Math.max(1, state.event.participantCapacity || state.event.participantTarget || 18);
const participantNeed = () => state.event.finalBudget - state.event.sponsorContribution - state.event.openingBalance;
const targetPerPerson = () => CashbookModel.participantTarget(state.event);
const expensesTotal = () => CashbookModel.expenseTotal(state.transactions);
const paymentsTotal = () => CashbookModel.incomeTotal(state.transactions);
const currentBalance = () => CashbookModel.currentBalance(state.event, state.transactions);

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (saved && saved.event && Array.isArray(saved.participants)) {
      saved.reminders = Array.isArray(saved.reminders) ? saved.reminders : structuredClone(DEFAULT_STATE.reminders);
      saved.syncQueue = Array.isArray(saved.syncQueue) ? saved.syncQueue : [];
      migratePaymentTransactions(saved);
      return saved;
    }
  } catch (error) {
    console.warn('Data lokal tidak dapat dibaca, gunakan contoh data.', error);
  }
  return structuredClone(DEFAULT_STATE);
}

function migratePaymentTransactions(saved) {
  if (saved.paymentModelVersion >= 2) return;
  saved.transactions = Array.isArray(saved.transactions) ? saved.transactions : [];
  saved.participants.forEach((participant) => {
    const recorded = saved.transactions.filter((item) => item.type === 'participant_payment' && (item.participantId === participant.id || String(item.label || '').toLowerCase() === participant.name.toLowerCase())).reduce((sum, item) => sum + Number(item.amount || 0), 0);
    const difference = Number(participant.payment || 0) - recorded;
    if (difference > 0) saved.transactions.push({ id: 't-migrate-' + participant.id, type: 'participant_payment', participantId: participant.id, label: participant.name, amount: difference });
  });
  saved.paymentModelVersion = 2;
}

function saveState() {
  state.updatedAt = new Date().toISOString();
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function queueLocalChange(entityType, entityId, payload) {
  state.syncQueue = Array.isArray(state.syncQueue) ? state.syncQueue : [];
  state.syncQueue.push({ id: 'q-' + Date.now(), entityType, entityId: entityId || null, payload, createdAt: new Date().toISOString(), syncStatus: 'queued' });
}

function renderConnectionStatus() {
  const status = $('[data-connection-status]');
  if (!status) return;
  const offline = !navigator.onLine;
  const queued = state.syncQueue?.length || 0;
  status.classList.toggle('offline', offline);
  status.querySelector('strong').textContent = offline
    ? 'Offline · perubahan disimpan di perangkat ini'
    : queued
      ? 'Online · ' + queued + ' perubahan menunggu sinkronisasi'
      : 'Online · tersimpan di perangkat ini';
  status.querySelector('small').textContent = offline
    ? 'Tetap catat pembayaran, pengeluaran, dan pengingat. Sinkronisasi dilakukan saat sinyal kembali.'
    : queued
      ? 'Prototype ini belum tersambung ke server; antrean ditampilkan agar alur offline mudah divalidasi.'
      : 'Prototype ini menyimpan data lokal; aplikasi HP akan menyinkronkan ke server.';
}

function formatReminderDate(dateString) {
  return new Intl.DateTimeFormat('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(dateString + 'T09:00:00'));
}

function reminderTiming(dateString) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const due = new Date(dateString + 'T09:00:00');
  const days = Math.round((due - today) / 86400000);
  if (days < 0) return Math.abs(days) + ' hari lalu';
  if (days === 0) return 'hari ini';
  if (days === 1) return 'besok';
  return days + ' hari lagi';
}

function renderReminders() {
  const list = $('[data-reminder-list]');
  if (!list) return;
  const reminders = (state.reminders || []).slice().sort((a, b) => a.dueAt.localeCompare(b.dueAt));
  list.innerHTML = reminders.length ? reminders.map((reminder) => {
    const done = reminder.status === 'done';
    return '<div class="reminder-row' + (done ? ' done' : '') + '"><span class="reminder-icon">' + (done ? '✓' : '!') + '</span><div><strong>' + escapeHTML(reminder.title) + '</strong><small>' + formatReminderDate(reminder.dueAt) + ' · ' + reminderTiming(reminder.dueAt) + (reminder.note ? ' · ' + escapeHTML(reminder.note) : '') + '</small></div><button class="tag ' + (done ? 'green' : 'yellow') + ' reminder-action" data-toggle-reminder data-id="' + escapeHTML(reminder.id) + '">' + (done ? 'Buka lagi' : 'Tandai selesai') + '</button></div>';
  }).join('') : '<div class="empty-state"><strong>Belum ada pengingat.</strong><p>Tambahkan tenggat pembayaran atau persiapan agar tidak perlu mengingat semuanya sendiri.</p></div>';
}

function showToast(message) {
  const toast = $('#toast');
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(window.toastTimer);
  window.toastTimer = setTimeout(() => toast.classList.remove('show'), 3200);
}

function go(screen) {
  screens.forEach((item) => {
    $('#screen-' + item).classList.toggle('active', item === screen);
    $$('[data-screen="' + item + '"]').forEach((el) => el.classList.toggle('active', item === screen));
  });
  $('#page-label').textContent = labels[screen];
  $('#page-title').textContent = titles[screen];
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function openModal(mode, participantId = null) {
  modalMode = mode;
  modalParticipantId = participantId;
  const config = {
    event: ['Buat acara baru', 'Isi informasi dasar acara. Setelah disimpan, data tetap tersimpan di perangkat ini.', 'Nama acara', 'Contoh: Arisan keluarga'],
    participant: ['Tambah peserta', 'Isi nama peserta. Data bisa diedit kapan saja tanpa menghapus riwayat transaksi.', 'Nama peserta', 'Contoh: Ibu Rina'],
    editParticipant: ['Edit data peserta', 'Perubahan nama atau status tidak menghapus transaksi yang sudah dicatat.', 'Nama peserta', 'Contoh: Pak Roni'],
    budget: ['Anggaran akhir', 'Anggaran final ditetapkan oleh ketua panitia. Target dihitung dari anggaran dikurangi sponsor dan saldo awal.', 'Catatan anggaran', 'Contoh: Anggaran dari rapat 20 Agustus'],
    expense: ['Catat pengeluaran', 'Isi label dan nominal. Saldo akan diperbarui setelah disimpan.', 'Nama pengeluaran', 'Contoh: Konsumsi perjalanan'],
    payment: ['Catat pembayaran', 'Catat nominal yang diterima. Status sebagian atau lunas terlihat dari jumlah dibanding target per orang.', 'Nama peserta', 'Contoh: Pak Darto'],
    additional: ['Kontribusi tambahan', 'Catat kebutuhan tambahan dengan catatan yang dapat dijelaskan di laporan.', 'Alasan kontribusi', 'Contoh: Tambahan konsumsi'],
    sponsor: ['Edit kontribusi sponsor', 'Perubahan sponsor mengubah target per orang. Perubahan akan dicatat di audit.', 'Catatan sponsor', 'Contoh: Sponsor yang sama menambah dukungan'],
    opening: ['Edit saldo awal / carry-over', 'Perubahan saldo awal mengubah target per orang. Perubahan akan dicatat di audit.', 'Alasan perubahan', 'Contoh: Sisa kas kegiatan sebelumnya'],
    reminder: ['Tambah pengingat', 'Catat tenggat sederhana untuk pembayaran atau persiapan acara.', 'Judul pengingat', 'Contoh: Bayar DP bus']
  };
  const values = config[mode];
  $('#modal-title').textContent = values[0];
  $('#modal-copy').textContent = values[1];
  $('#modal-input-label').childNodes[0].textContent = values[2] + ' ';
  $('#modal-input').placeholder = values[3];
  $('#modal-input').value = '';
  $('#modal-amount').value = '';
  $('#modal-date').value = '';
  $('#modal-note').value = '';
  const participant = participantId ? state.participants.find((item) => item.id === participantId) : null;
  if (participant) {
    $('#modal-input').value = participant.name;
    $('#modal-amount').value = participant.payment || '';
  }
  $('#modal-status').value = participant?.status || 'active';
  $('#modal-refund').value = participant?.refundPolicy || 'undecided';
  const participantMode = mode === 'participant' || mode === 'editParticipant';
  const reminderMode = mode === 'reminder';
  const amountMode = ['participant', 'editParticipant', 'expense', 'payment', 'additional', 'budget', 'sponsor', 'opening'].includes(mode);
  $('#modal-refund-field').style.display = participantMode ? 'block' : 'none';
  $('#modal-status-field').style.display = participantMode ? 'block' : 'none';
  $('#modal-amount-label').style.display = amountMode ? 'block' : 'none';
  $('#modal-date-field').style.display = reminderMode ? 'block' : 'none';
  $('#modal-note-field').style.display = reminderMode ? 'block' : 'none';
  $('#modal-hint').textContent = ['budget', 'sponsor', 'opening'].includes(mode)
    ? 'Per orang saat ini: Rp ' + formatIDR(targetPerPerson()) + '. Rumus: (anggaran − sponsor − saldo awal) ÷ peserta aktif.'
    : mode === 'editParticipant' ? 'Refund penuh atau sebagian akan membuat transaksi pengembalian dana yang terlihat di buku kas.' : reminderMode ? 'Pengingat tersimpan lokal dan masuk antrean sinkronisasi.' : 'Nominal dan status akan disimpan sebagai bagian dari riwayat acara.';
  $('#modal').hidden = false;
  $('#modal-input').focus();
}

function closeModal() {
  $('#modal').hidden = true;
}

function escapeHTML(value) {
  return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;').replace(/'/g, '&#039;');
}

function renderParticipants() {
  const rows = $('#participant-rows');
  rows.innerHTML = state.participants.map((participant) => {
    const status = participant.status === 'cancelled' ? ['gray', 'Dibatalkan'] : ['green', 'Aktif'];
    const paymentLabel = participant.payment >= targetPerPerson() ? 'Lunas' : participant.payment > 0 ? 'Sebagian' : 'Belum bayar';
    const paymentClass = paymentLabel === 'Lunas' ? 'positive' : paymentLabel === 'Belum bayar' ? 'negative' : 'yellow-text';
    const refundTotal = participant.status === 'cancelled' ? CashbookModel.refundTotalForParticipant(state.transactions, participant.id) : 0;
    const refundNote = participant.status === 'cancelled' && refundTotal > 0 ? ' · refund Rp ' + formatIDR(refundTotal) : '';
    return '<tr><td><strong>' + escapeHTML(participant.name) + '</strong><small>' + escapeHTML(participant.role || '—') + '</small></td><td><span class=\"tag ' + status[0] + '\">' + status[1] + '</span></td><td><strong>Rp ' + formatIDR(participant.payment) + '</strong><small class=\"' + paymentClass + '\">' + paymentLabel + (participant.status === 'cancelled' ? ' · riwayat tersimpan' : '') + refundNote + '</small></td><td>' + (participant.payment ? '24 Agu 2026' : '—') + '</td><td><button class=\"icon-button\" data-edit-participant data-id=\"' + participant.id + '\" aria-label=\"Edit ' + escapeHTML(participant.name) + '\">✎</button></td></tr>';
  }).join('');
}

function renderDerivedValues() {
  const budgetTotal = $('.budget-total');
  if (budgetTotal) budgetTotal.innerHTML = 'Rp ' + formatIDR(state.event.finalBudget) + ' <span class=\"tag green\">Final</span>';
  const cards = $$('.metric-card strong');
  if (cards[0]) cards[0].textContent = 'Rp ' + formatIDR(currentBalance());
  if (cards[2]) cards[2].textContent = 'Rp ' + formatIDR(expensesTotal());
  if (cards[3]) cards[3].textContent = 'Rp ' + formatIDR(targetPerPerson());
  $$('[data-report-budget]').forEach((el) => el.textContent = 'Rp ' + formatIDR(state.event.finalBudget));
  $$('[data-report-collected]').forEach((el) => el.textContent = 'Rp ' + formatIDR(paymentsTotal()));
  $$('[data-report-expenses]').forEach((el) => el.textContent = 'Rp ' + formatIDR(expensesTotal()));
  $$('[data-report-balance]').forEach((el) => el.textContent = 'Rp ' + formatIDR(currentBalance()));
  if ($('[data-report-prepared-by]')) $('[data-report-prepared-by]').textContent = $('[data-report-role]')?.value || 'Bendahara';
  const budgetLines = $$('.budget-lines strong');
  if (budgetLines.length >= 3) {
    budgetLines[0].textContent = 'Rp ' + formatIDR(participantNeed());
    budgetLines[1].textContent = 'Rp ' + formatIDR(state.event.sponsorContribution);
    budgetLines[2].textContent = 'Rp ' + formatIDR(state.event.openingBalance);
  }
  renderConnectionStatus();
  renderReminders();
}

function saveModal() {
  const name = $('#modal-input').value.trim();
  const amount = Number($('#modal-amount').value || 0);
  if (!name && modalMode !== 'budget') {
    showToast('Isi nama atau keterangan terlebih dahulu.');
    $('#modal-input').focus();
    return;
  }
  if (['expense', 'payment', 'additional', 'budget', 'sponsor'].includes(modalMode) && amount <= 0) {
    showToast('Masukkan nominal lebih dari Rp 0.');
    $('#modal-amount').focus();
    return;
  }
  if (modalMode === 'reminder' && !$('#modal-date').value) {
    showToast('Pilih tanggal pengingat terlebih dahulu.');
    $('#modal-date').focus();
    return;
  }
  if (modalMode === 'event') state.event.name = name;
  if (modalMode === 'participant') {
    const participantId = 'p-' + Date.now();
    state.participants.push({ id: participantId, name, status: $('#modal-status').value, role: 'Peserta baru', payment: amount, refundPolicy: $('#modal-refund').value });
    if (amount > 0) state.transactions.push({ id: 't-' + Date.now(), type: 'participant_payment', participantId, label: name, amount });
    renderParticipants();
  }
  if (modalMode === 'editParticipant') {
    const participant = state.participants.find((item) => item.id === modalParticipantId) || state.participants[0];
    if (participant) {
      participant.name = name;
      participant.status = $('#modal-status').value;
      participant.refundPolicy = $('#modal-refund').value;
      if (participant.status === 'cancelled' && ['partial', 'full'].includes(participant.refundPolicy) && amount <= 0) {
        showToast('Masukkan nominal refund untuk kebijakan ini.');
        $('#modal-amount').focus();
        return;
      }
      if (participant.status === 'cancelled') {
        const requestedRefund = CashbookModel.refundAmount(participant.refundPolicy, participant.payment, amount);
        const existingRefund = CashbookModel.refundTotalForParticipant(state.transactions, participant.id);
        const adjustment = requestedRefund - existingRefund;
        if (adjustment > 0) state.transactions.push({ id: 't-' + Date.now(), type: 'refund', participantId: participant.id, label: 'Pengembalian dana ' + participant.name, amount: adjustment });
        if (adjustment < 0) state.transactions.push({ id: 't-' + Date.now(), type: 'refund_reversal', participantId: participant.id, label: 'Koreksi pengembalian dana ' + participant.name, amount: Math.abs(adjustment) });
      }
    }
    renderParticipants();
    renderDerivedValues();
  }
  if (modalMode === 'budget') {
    if (!window.confirm('Simpan anggaran final baru dan hitung ulang target per orang?')) return;
    state.event.finalBudget = amount;
    renderDerivedValues();
  }
  if (modalMode === 'sponsor') {
    if (state.transactions.some((item) => item.type === 'participant_payment')) {
      showToast('Kontribusi sponsor baru tidak dapat ditambahkan setelah pembayaran peserta dimulai.');
      return;
    }
    if (!window.confirm('Simpan perubahan sponsor dan hitung ulang target per orang?')) return;
    state.event.sponsorContribution = amount;
    state.auditLog = state.auditLog || [];
    state.auditLog.push({ at: new Date().toISOString(), type: 'sponsor_change', note: name, amount });
    renderDerivedValues();
  }
  if (modalMode === 'opening') {
    if (!window.confirm('Simpan saldo awal baru dan hitung ulang target per orang?')) return;
    state.event.openingBalance = amount;
    state.auditLog = state.auditLog || [];
    state.auditLog.push({ at: new Date().toISOString(), type: 'opening_balance_change', note: name, amount });
    renderDerivedValues();
  }
  if (modalMode === 'expense') {
    state.transactions.push({ id: 't-' + Date.now(), type: 'expense', label: name, amount, category: 'Lainnya' });
    renderDerivedValues();
  }
  if (modalMode === 'payment') {
    const participant = state.participants.find((item) => item.name.toLowerCase() === name.toLowerCase());
    state.transactions.push({ id: 't-' + Date.now(), type: 'participant_payment', participantId: participant?.id, label: name, amount });
    if (participant) participant.payment = Number(participant.payment || 0) + amount;
    renderParticipants();
    renderDerivedValues();
  }
  if (modalMode === 'additional') {
    state.transactions.push({ id: 't-' + Date.now(), type: 'additional_contribution', label: name, amount });
    renderDerivedValues();
  }
  if (modalMode === 'reminder') {
    state.reminders = state.reminders || [];
    const reminder = { id: 'r-' + Date.now(), title: name, dueAt: $('#modal-date').value, note: $('#modal-note').value.trim(), status: 'open' };
    state.reminders.push(reminder);
    queueLocalChange('reminder', reminder.id, reminder);
    renderDerivedValues();
  }
  if (modalMode !== 'reminder') queueLocalChange(modalMode, modalParticipantId, { name, amount });
  saveState();
  closeModal();
  showToast('Tersimpan. Riwayat transaksi tetap aman.');
}

function reportText() {
  const refundLabels = { none: 'Tidak ada refund', partial: 'Refund sebagian', full: 'Refund penuh', undecided: 'Refund belum diputuskan' };
  const participantLines = state.participants.map((participant) => {
    const status = participant.status === 'cancelled' ? 'Dibatalkan - ' + (refundLabels[participant.refundPolicy] || refundLabels.undecided) : participant.payment >= targetPerPerson() ? 'Lunas' : participant.payment > 0 ? 'Sebagian' : 'Belum bayar';
    return '- ' + participant.name + ': ' + status + ' (Rp ' + formatIDR(participant.payment) + ')';
  });
  const expenseLines = state.transactions.filter((item) => item.type === 'expense').map((item) => '- ' + item.label + ': Rp ' + formatIDR(item.amount));
  return [
    'LAPORAN KAS ' + state.event.name.toUpperCase(),
    '12–14 September 2026 · 18 peserta',
    'Dibuat oleh: ' + ($('[data-report-role]')?.value || 'Bendahara'),
    '',
    'Anggaran akhir: Rp ' + formatIDR(state.event.finalBudget),
    'Target per orang: Rp ' + formatIDR(targetPerPerson()),
    'Saldo saat ini: Rp ' + formatIDR(currentBalance()),
    'Total pengeluaran: Rp ' + formatIDR(expensesTotal()),
    '',
    'PESERTA',
    participantLines.join('\n'),
    '',
    'PENGELUARAN',
    expenseLines.join('\n'),
    '',
    state.reportNote,
    '',
    'Catatan: peserta yang dibatalkan tetap disimpan. Kebijakan refund dipilih per peserta oleh bendahara.'
  ].join('\\n');
}

function handlePDF() {
  showToast('Laporan siap dicetak. Pilih “Simpan sebagai PDF” pada dialog cetak.');
  setTimeout(() => window.print(), 350);
}

async function handleWhatsApp() {
  try {
    await navigator.clipboard.writeText(reportText());
    showToast('Ringkasan disalin. Siap ditempel ke WhatsApp.');
  } catch (error) {
    showToast('Ringkasan siap dibagikan: buka Laporan dan salin teksnya.');
  }
}

function resetDemo() {
  localStorage.removeItem(STORAGE_KEY);
  state = structuredClone(DEFAULT_STATE);
  renderParticipants();
  renderDerivedValues();
  showToast('Contoh data Wisata Dieng dikembalikan.');
}

function toggleReminder(id) {
  const reminder = (state.reminders || []).find((item) => item.id === id);
  if (!reminder) return;
  reminder.status = reminder.status === 'done' ? 'open' : 'done';
  queueLocalChange('reminder', id, { status: reminder.status });
  saveState();
  renderDerivedValues();
  showToast(reminder.status === 'done' ? 'Pengingat ditandai selesai.' : 'Pengingat dibuka kembali.');
}

document.addEventListener('click', (event) => {
  const screen = event.target.closest('[data-screen]')?.dataset.screen;
  if (screen) go(screen);
  if (event.target.closest('[data-create-event]')) openModal('event');
  if (event.target.closest('[data-add-participant]')) openModal('participant');
  if (event.target.closest('[data-edit-participant]')) openModal('editParticipant', event.target.closest('[data-edit-participant]').dataset.id);
  if (event.target.closest('[data-budget-edit]')) openModal('budget');
  if (event.target.closest('[data-sponsor-edit]')) openModal('sponsor');
  if (event.target.closest('[data-opening-edit]')) openModal('opening');
  if (event.target.closest('[data-add-transaction], [data-add-expense]')) openModal('expense');
  if (event.target.closest('[data-record-payment]')) openModal('payment');
  if (event.target.closest('[data-additional]')) openModal('additional');
  if (event.target.closest('[data-add-reminder]')) openModal('reminder');
  if (event.target.closest('[data-toggle-reminder]')) toggleReminder(event.target.closest('[data-toggle-reminder]').dataset.id);
  if (event.target.closest('[data-pdf]')) handlePDF();
  if (event.target.closest('[data-whatsapp]')) handleWhatsApp();
  if (event.target.closest('[data-help]')) showToast('Mulai dari Peserta, lalu catat pembayaran dan pengeluaran. Saldo diperbarui otomatis.');
  if (event.target.closest('[data-reset]')) resetDemo();
  if (event.target.closest('[data-close]')) closeModal();
  if (event.target.closest('[data-save]')) saveModal();
});

document.addEventListener('change', (event) => {
  if (event.target.matches('[data-report-role]')) renderDerivedValues();
});

window.addEventListener('online', renderConnectionStatus);
window.addEventListener('offline', renderConnectionStatus);

renderParticipants();
renderDerivedValues();
go('ringkasan');
