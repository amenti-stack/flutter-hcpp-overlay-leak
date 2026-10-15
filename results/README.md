# Raw results

All runs on the same device: Xiaomi Mi TV box (MiTV-AFMU0), Android 14, Mali-G310, Flutter 3.47.0,
Impeller (Vulkan), profile build, HCPP active.

## 2026-10-14: the runs in the issue

| File | What |
|---|---|
| `gpu-mem-banner-300-changes.txt` | First run: 300 media changes with only a small text banner, no full-screen overlay. Flat. |
| `gpu-mem-phases-a-b.txt` | The run in the issue: phase A (40 changes, full-screen overlay + spinner for 2 s each), then phase B (40 resizes, no overlay), then idle. |
| `log-*.txt` | The app's `REPRO` log lines. Only the end of each run survived in logcat. |

These two were sampled with a longer version of `tools/gpu-mem-sampler.sh` that records more columns:

```
T <epoch s> pid=<pid> avail=<MemAvailable kB> anon=<RssAnon kB> file=<RssFile kB> shmem=<RssShmem kB>
  swap=<VmSwap kB> mali0=<mappings of /dev/mali0> dmabuf=<dma-buf fds> dmabuf_kb=<dma-buf kB> gpu_kb=<kB>
```

`gpu_kb` is the figure in the issue: the Mali kbase driver's `used_pages` for the app's pid, summed
over its contexts in `/sys/class/misc/mali0/device/gpu_memory`, times 4 KB. Lines with an empty
`pid=` were taken before the app started.

## 2026-10-15: timeline trace

About 65 s of phase A (roughly changes 4 to 14, one full-screen overlay + spinner every 6 s), recorded
over the VM service with the Dart, Embedder and GC streams. The recording began a second or two after
the first memory sample:

| File | What |
|---|---|
| `timeline.pftrace` | Perfetto trace (`getPerfettoVMTimeline`), the format DevTools reads. Opens in ui.perfetto.dev. |
| `timeline.json` | The same window as Chrome trace events (`getVMTimeline`). Opens in ui.perfetto.dev or chrome://tracing. |
| `gpu-mem.txt` | `gpu_kb` every 10 s across the same window, from `tools/gpu-mem-sampler.sh` as published. |
| `log.txt` | The app's `REPRO` lines for changes 6 to 19 (read after the run); the last number on each is the change's epoch time, the clock `gpu-mem.txt` uses. |

In this window the count rose once, 33,880 → 37,588 KB, between the first two samples (epoch
1792080053 and 1792080063, around change 4), and stayed there to the end. In the longer run above the 4 MB steps also came on
some overlay cycles, not every one: three steps in 40.
