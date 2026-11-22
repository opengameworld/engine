// `bun run export web <game>`    build .export/web/<game>/ (game.json + site/), or say why not
// `bun run export serve <game>`  play that folder at http://localhost:3200/
//
// Limits now:
// - Web only.
// - The publish commands (a release, a channel, a link) come with the publish service.

import { exportWeb, serve } from "./web";

const [cmd, slug, ...rest] = Bun.argv.slice(2);
const port = Number(rest[rest.indexOf("--port") + 1]) || 3200;

if (cmd === "web" && slug) {
  const r = await exportWeb(slug);
  process.exit(r.ok ? 0 : 1);
} else if (cmd === "serve" && slug) {
  if (!(await serve(slug, port))) process.exit(1);
} else {
  console.log("usage: bun run export web <game> | bun run export serve <game> [--port 3200]");
  process.exit(1);
}
