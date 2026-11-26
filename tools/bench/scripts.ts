// Times a tick of Play with n things, each with a script attached (tools/bench/scripts.bend), in
// JavaScript: the lane the editor and a game run in, in a browser. `bun tools/bench/scripts.ts`.
//
// It runs 60 ticks (one second of Play) for each n and prints the milliseconds per tick, against
// the tick's own length (engine/play/tick.bend: 1/60 s, about 16.7 ms, shared with drawing), and
// the same ticks with no script attached (what the rest of the tick costs).

import plugin from "../../../bend/bend2/main.ts";
Bun.plugin(plugin);

const Bench = (await import("./scripts.bend")).default;
const TICKS = 60;
const sizes = (process.argv[2] ?? "10,100,1000").split(",").map(Number);

Bench.run(10, 2);   // the first call compiles and warms up the code
const time = (f) => { const t0 = performance.now(); const x = f(); return [(performance.now() - t0) / TICKS, x]; };
for (const n of sizes) {
  const [ms, x] = time(() => Bench.run(n, TICKS));
  const [base] = time(() => Bench.run_plain(n, TICKS));
  const [index] = time(() => Bench.run_index(n, TICKS));
  console.log(`${String(n).padStart(6)} things: ${ms.toFixed(2).padStart(9)} ms per tick (${(ms / (1000 / 60) * 100).toFixed(0)}% of a 1/60 s tick); without scripts ${base.toFixed(2)} ms; the World's index alone ${index.toFixed(2)} ms  [x after 1 s: ${x.toFixed(2)}]`);
}
