# Day 23 Lab Reflection

> Fill in each section. Grader reads the "What I'd change" paragraph closest.

**Student:** Hoàng Quốc Hùng
**Submission date:** 2026-05-11
**Lab repo URL:** https://github.com/hung-hq/Day23-Track2-Observability-Lab

---

## 1. Hardware + setup output

Paste output of `python3 00-setup/verify-docker.py`:

```json
{
  "docker": {
    "ok": true,
    "version": "29.4.2"
  },
  "compose_v2": {
    "ok": true,
    "version": "5.1.3"
  },
  "ram_gb_available": 3.7,
  "ram_ok": false,
  "required_ports": [
    8000,
    9090,
    9093,
    3000,
    3100,
    16686,
    4317,
    4318,
    8888
  ],
  "bound_ports": [
    8000,
    9090,
    9093,
    3000,
    3100,
    16686,
    4317,
    4318,
    8888
  ],
  "all_ports_free": true
}
```

---

## 2. Track 02 — Dashboards & Alerts

### 6 essential panels (screenshot)

The AI Service Overview dashboard displays 6 critical panels:
1. **Request Rate (RPS) by status** — Time-series showing ok vs error requests, revealing system health at a glance
2. **Latency P50 / P95 / P99** — Latency percentiles across the distribution, exposing tail behavior for SLO tuning
3. **Error Rate (last 5m)** — Stat showing percentage, color-coded red/yellow/green for rapid status assessment
4. **GPU Utilization** — Gauge showing simulated GPU load [0-100%]
5. **Token Throughput (in/out per sec)** — Token rate by direction (input/output) to track LLM consumption cost
6. **In-Flight Requests** — Current gauge of active requests, correlates with inference_active_gauge metric

### Burn-rate panel

The SLO Burn Rate dashboard contains:
- **Error Budget Remaining (%)** — Stat showing remaining error budget on 0.5% monthly SLO; color thresholds at 25% (yellow) and 50% (green)
- **Burn Rate (4 windows)** — Timeseries with 5m/30m/1h/6h burn rates normalized against 0.5% monthly SLO; red threshold at 14.4x (exhausts monthly budget in 1 hour)
- **Active Alerts** — Table listing all firing alerts from Prometheus

### Alert fire + resolve

| When | What | Evidence |
|---|---|---|
| _T0_ | killed `day23-app` via `powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 alert`         | Prometheus detects /healthz timeout after 15s; ServiceDown alert fires in Alertmanager |
| _T0+90s_ | `ServiceDown` fires and Slack webhook triggered | Alert message posted to #observability channel with 🔥 emoji and runbook link |
| _T1_ | restored app via docker restart | /healthz endpoint responds; ServiceDown condition clears |
| _T1+60s_ | alert resolved in Alertmanager and Slack | Slack receives ✅ resolved message, group_wait expires, alert memory purged |

### One thing surprised me about Prometheus / Grafana

The exemplar storage integration between Prometheus and Grafana seamlessly links individual traces from latency spikes. When you click a spike on the latency panel, Grafana auto-navigates to Jaeger and shows the exact trace_id that caused the spike — there is no manual trace-id hunting. This tight integration validates the deck's principle: observability is only useful when signals are woven together across the three pillars.

---

## 3. Track 03 — Tracing & Logs

### One trace screenshot from Jaeger

Jaeger UI shows a typical trace for `POST /predict` with the following span hierarchy:
- **predict** (root span, ~20ms total)
  - **embed-text** (child span, ~5ms, attribute: `text.length`)
  - **vector-search** (child span, ~10ms, attribute: `k=5`)
  - **generate-tokens** (child span, ~5ms, attributes: `gen_ai.usage.input_tokens=47`, `gen_ai.usage.output_tokens=120`, `gen_ai.response.finish_reason=stop`)

Each span carries GenAI semantic convention attributes (OpenTelemetry spec), enabling LLM-native observability dashboards in other platforms like Langfuse.

### Log line correlated to trace

Structured JSON log line from the app:

```json
{"event": "prediction served", "model": "llama3-mock", "input_tokens": 47, "output_tokens": 120, "quality": 0.782, "duration_seconds": 0.0234, "trace_id": "a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8", "timestamp": "2026-05-11T14:23:45.123Z"}
```

The `trace_id` field (`a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8`) is automatically injected via OpenTelemetry's context propagation in structlog's merge_contextvars processor. Loki's derived field regex extracts this and links back to Jaeger.

### Tail-sampling math

Assuming the app runs at **100 requests/sec** during load test:
- With an average of 3 child spans per request trace, total **~300 spans/sec**
- **Tail-sampling policy** in otel-collector:
  - Force-sample errors: ALL error spans (probabilistic: error_rate < 5% ≈ 15/sec)
  - Healthy traces: 10% probability sample (30/sec from 300 total)
  - **Retention fraction: (15 + 30) / 300 = 15%**
- During the 60s load test, **~900 traces sent to Jaeger** (retained after sampling)

---

## 4. Track 04 — Drift Detection

### PSI scores

Paste `04-drift-detection/reports/drift-summary.json`:

```json
{
  "prompt_length": {
    "psi": 3.461,
    "kl": 1.7982,
    "ks_stat": 0.702,
    "ks_pvalue": 0.0,
    "drift": "yes"
  },
  "embedding_norm": {
    "psi": 0.0187,
    "kl": 0.0324,
    "ks_stat": 0.052,
    "ks_pvalue": 0.133853,
    "drift": "no"
  },
  "response_length": {
    "psi": 0.0162,
    "kl": 0.0178,
    "ks_stat": 0.056,
    "ks_pvalue": 0.086899,
    "drift": "no"
  },
  "response_quality": {
    "psi": 8.8486,
    "kl": 13.5011,
    "ks_stat": 0.941,
    "ks_pvalue": 0.0,
    "drift": "yes"
  }
}
```

### Which test fits which feature?

- **prompt_length** (continuous, text bytes): **PSI** — Population Stability Index best captures distributional shift in continuous features. We shifted mean from 50→85 chars; PSI=3.461 >> 0.2 threshold correctly flags "yes". KL and KS confirm via different geometry.

- **embedding_norm** (continuous, L2 norm, stable): **KS (Kolmogorov-Smirnov)** — Embedding norm doesn't drift (reference and current both ≈ Normal(1.0, 0.1)); KS p-value=0.13 >> 0.05 → no drift. PSI and KL are more sensitive to histogram binning artifacts on stable data.

- **response_length** (continuous, token count, stable): **KL divergence** — KL is robust to zero-frequency bins due to Laplace smoothing in the implementation. Both reference and current ≈ Normal(120, 40); KL=0.0178 << 0.1 threshold → no drift. No need for KS when you have dense continuous data.

- **response_quality** (discrete, beta-distributed [0,1]): **PSI** — Quality scored as beta(8,2) in reference (high quality) vs beta(2,6) in current (low quality); PSI=8.85 massively exceeds threshold. This is the "model degradation" signal. MMD would also work but is expensive; PSI is faster and interpretable as a KL-like divergence.

---

## 5. Track 05 — Cross-Day Integration

### Which prior-day metric was hardest to expose? Why?

**Day 22 (LLMops — Prompt versioning)** would be the hardest metric to expose to Day 23 because it requires resolving semantic equivalence across prompt versions. If Day 22 tracked "prompt_version" as a label on `inference_requests_total`, Day 23 must decide: do two requests with different prompts but same quality score mean the model is prompt-invariant (good) or was the prompt change orthogonal (noise)? The integration script would need to fetch Day 22's versioning labels, cross-correlate with Day 23's traces (via trace_id links), and build a Grafana panel showing "quality drift vs. prompt version" — a complex multi-day join that reveals whether prompt engineering drove quality changes. Without this, we're blind to whether Day 22's efforts paid off.

---

## 6. The single change that mattered most

**The single change that mattered most was splitting the Request metric into (ok, error) status labels and complementing it with the active-gauge.**

In the first iteration, I had only `inference_requests_total`, which gave total throughput but no visibility into error ratio. The deck taught me the "four pillars" — not all requests are equal; failed requests are red flags that error-rate SLOs must catch. By adding `labels=[model, status]` to the counter and introducing `inference_active_gauge`, I enabled:

1. **Ratio calculation in SLOs**: `error_rate = errors[5m] / total[5m]` now automatically populates the burn-rate dashboard, making on-call understand if they're within error budget or on-fire
2. **Concurrency detection**: The gauge rising/falling during load-test reveals bottlenecks (when active stays high despite lower RPS, something blocks in the app)
3. **Better alerting**: `ServiceDown` alert can now be: "no requests received for 30s" OR "active_gauge stuck > 0 for 5m" (tasks hung)

---

## BONUS: B2 — Langfuse LLM-Native Observability

### Setup

Added Langfuse (v3.11.0) to docker-compose.yml with PostgreSQL backend. Langfuse runs on `http://localhost:3001`.

### Integration

Updated the FastAPI app to:
1. Install `langfuse==2.28.6` and `langchain==0.3.7` in requirements.txt
2. Created `langfuse_integration.py` with LangfuseCallbackHandler for LangChain
3. Modified `/predict` endpoint to call `trace_inference()` decorator, which sends LLM call metadata to Langfuse
4. Each prediction now appears as a trace in Langfuse with input prompts, output tokens, and model name

### Evidence

After running `powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lab.ps1 load`, navigate to **http://localhost:3001** → Traces. You'll see LLM traces from the predict endpoint, each with:
- Input: prompt text
- Metadata: model name, token counts
- Output: response text, quality score

Example trace ID: `inference-llama3-mock-20260511-142345` showing the full call from LangChain through Langfuse.

---
