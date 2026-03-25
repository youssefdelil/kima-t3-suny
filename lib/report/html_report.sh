#!/usr/bin/env bash
# lib/report/html_report.sh — Generate a visual HTML report after each run

html_report::generate() {
  local duration="$1"
  local disk_before="$2"
  local disk_after="$3"

  local report_dir="$HOME/.delileche/reports"
  mkdir -p "$report_dir"
  local timestamp
  timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  local report_file="$report_dir/report_${timestamp}.html"

  local mode_label
  mode_label="$([ "$DRY_RUN" == "true" ] && echo "DRY-RUN" || echo "LIVE")"
  local mode_color
  mode_color="$([ "$DRY_RUN" == "true" ] && echo "#a78bfa" || echo "#f87171")"

  local total_scanned=0
  local total_projected=0
  local module_rows=""
  local module_count=${#MODULE_NAMES[@]}

  for (( i=0; i<module_count; i++ )); do
    local name="${MODULE_NAMES[$i]}"
    local category="${MODULE_CATEGORIES[$i]}"
    local scanned="${MODULE_SCANNED[$i]}"
    local status="${MODULE_STATUS[$i]}"
    local projected="${MODULE_PROJECTED[$i]:-0}"
    local dur="${MODULE_DURATIONS[$i]:-0}"
    total_scanned=$(( total_scanned + scanned ))
    total_projected=$(( total_projected + projected ))

    local found_fmt="-"
    (( scanned > 0 )) && found_fmt=$(utils::format_bytes "$scanned")
    local proj_fmt="-"
    (( projected > 0 )) && proj_fmt=$(utils::format_bytes "$projected")

    local status_class="status-clean"
    case "$status" in
      pending) status_class="status-pending" ;;
      done)    status_class="status-done" ;;
      skipped) status_class="status-skipped" ;;
      review)  status_class="status-review" ;;
    esac

    module_rows+="<tr>
      <td class='cat'>$category</td>
      <td>$name</td>
      <td>$found_fmt</td>
      <td>$proj_fmt</td>
      <td><span class='badge $status_class'>$status</span></td>
      <td>${dur}s</td>
    </tr>"
  done

  local total_found_fmt
  total_found_fmt=$(utils::format_bytes "$total_scanned")
  local total_proj_fmt
  total_proj_fmt=$(utils::format_bytes "$total_projected")
  local free_before_fmt
  free_before_fmt=$(utils::format_bytes "$disk_before")
  local free_after_fmt
  free_after_fmt=$(utils::format_bytes "$disk_after")

  # Calculate bar chart data for modules (top 8)
  local chart_labels="" chart_data=""
  for (( i=0; i<module_count && i<8; i++ )); do
    chart_labels+="\"${MODULE_NAMES[$i]}\","
    chart_data+="${MODULE_PROJECTED[$i]:-0},"
  done
  chart_labels="${chart_labels%,}"
  chart_data="${chart_data%,}"

  cat > "$report_file" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>delileche Report — ${timestamp}</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
  <style>
    :root {
      --bg: #0f0d1a;
      --surface: #1a1730;
      --border: #2d2a45;
      --purple: #a78bfa;
      --magenta: #c084fc;
      --green: #4ade80;
      --yellow: #facc15;
      --red: #f87171;
      --cyan: #22d3ee;
      --text: #e2e0f0;
      --dim: #6b6890;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'SF Mono', 'Fira Code', monospace;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      padding: 2rem;
    }
    .header {
      text-align: center;
      padding: 2rem 0 1.5rem;
      border-bottom: 2px solid var(--border);
      margin-bottom: 2rem;
    }
    .header h1 {
      font-size: 2.4rem;
      background: linear-gradient(135deg, var(--purple), var(--magenta));
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      letter-spacing: 2px;
    }
    .header small {
      color: var(--dim);
      font-size: 0.85rem;
      display: block;
      margin-top: 0.4rem;
    }
    .cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 1rem;
      margin-bottom: 2rem;
    }
    .card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 1.2rem;
      text-align: center;
    }
    .card .val {
      font-size: 1.6rem;
      font-weight: bold;
      color: var(--purple);
      margin-bottom: 0.3rem;
    }
    .card .lbl { color: var(--dim); font-size: 0.8rem; text-transform: uppercase; letter-spacing: 1px; }
    .mode-badge {
      display: inline-block;
      padding: 0.2rem 0.8rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: bold;
      background: ${mode_color}22;
      color: ${mode_color};
      border: 1px solid ${mode_color}55;
    }
    .section-title {
      font-size: 1rem;
      color: var(--purple);
      text-transform: uppercase;
      letter-spacing: 2px;
      margin: 2rem 0 0.8rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    .section-title::after {
      content: '';
      flex: 1;
      height: 1px;
      background: var(--border);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: var(--surface);
      border-radius: 12px;
      overflow: hidden;
      font-size: 0.88rem;
    }
    th {
      background: #231f3a;
      color: var(--dim);
      text-transform: uppercase;
      letter-spacing: 1px;
      font-size: 0.75rem;
      padding: 0.8rem 1rem;
      text-align: left;
    }
    td { padding: 0.7rem 1rem; border-bottom: 1px solid var(--border); }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: #1e1b35; }
    .cat { color: var(--dim); font-size: 0.78rem; }
    .badge {
      padding: 0.15rem 0.6rem;
      border-radius: 10px;
      font-size: 0.78rem;
      font-weight: bold;
    }
    .status-pending  { background:#facc1520; color:#facc15; border:1px solid #facc1544; }
    .status-done     { background:#4ade8020; color:#4ade80; border:1px solid #4ade8044; }
    .status-clean    { background:#4ade8012; color:#4ade80; border:1px solid #4ade8033; }
    .status-skipped  { background:#6b688010; color:#6b6890; border:1px solid #6b689033; }
    .status-review   { background:#22d3ee15; color:#22d3ee; border:1px solid #22d3ee44; }
    .chart-wrap {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 2rem;
    }
    .footer {
      text-align: center;
      color: var(--dim);
      font-size: 0.78rem;
      margin-top: 3rem;
      padding-top: 1rem;
      border-top: 1px solid var(--border);
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🧹 delileche</h1>
    <small>by youcef — v${VERSION} &nbsp;|&nbsp; ${timestamp//_/ } &nbsp;|&nbsp;
      <span class="mode-badge">${mode_label}</span>
    </small>
  </div>

  <div class="cards">
    <div class="card">
      <div class="val">${total_found_fmt}</div>
      <div class="lbl">Scanned</div>
    </div>
    <div class="card">
      <div class="val" style="color:var(--green)">${total_proj_fmt}</div>
      <div class="lbl">Reclaimable</div>
    </div>
    <div class="card">
      <div class="val">${free_before_fmt}</div>
      <div class="lbl">Free Before</div>
    </div>
    <div class="card">
      <div class="val" style="color:var(--cyan)">${free_after_fmt}</div>
      <div class="lbl">Free After</div>
    </div>
    <div class="card">
      <div class="val">${duration}s</div>
      <div class="lbl">Duration</div>
    </div>
    <div class="card">
      <div class="val">${module_count}</div>
      <div class="lbl">Modules</div>
    </div>
  </div>

  <div class="section-title">Space by Module</div>
  <div class="chart-wrap">
    <canvas id="chart" height="80"></canvas>
  </div>

  <div class="section-title">Module Details</div>
  <table>
    <thead>
      <tr><th>Category</th><th>Module</th><th>Found</th><th>Reclaimable</th><th>Status</th><th>Time</th></tr>
    </thead>
    <tbody>
      ${module_rows}
    </tbody>
  </table>

  <div class="footer">
    Generated by delileche v${VERSION} · by youcef · ${timestamp//_/ }
  </div>

  <script>
    new Chart(document.getElementById('chart'), {
      type: 'bar',
      data: {
        labels: [${chart_labels}],
        datasets: [{
          label: 'Space (bytes)',
          data: [${chart_data}],
          backgroundColor: 'rgba(167,139,250,0.6)',
          borderColor: 'rgba(167,139,250,1)',
          borderWidth: 1,
          borderRadius: 6
        }]
      },
      options: {
        plugins: { legend: { display: false } },
        scales: {
          y: {
            ticks: { color: '#6b6890', callback: v => v > 1e9 ? (v/1e9).toFixed(1)+'GB' : v > 1e6 ? (v/1e6).toFixed(0)+'MB' : v+'B' },
            grid: { color: '#2d2a45' }
          },
          x: { ticks: { color: '#a78bfa' }, grid: { color: '#2d2a45' } }
        }
      }
    });
  </script>
</body>
</html>
HTML

  log::success "HTML report saved: $report_file"

  # Open in default browser if possible
  if command -v open >/dev/null 2>&1; then
    open "$report_file" 2>/dev/null || true
  fi
}
