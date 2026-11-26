// `bun run release`: builds a release of the engine, or checks one by building it again.
//
//   bun run release build <tag> --out <dir>                          a tag: clean tree, HEAD at it
//   bun run release build --commit <sha> --version <A.B.C> --out <dir>   a dry run, no tag
//   bun run release verify <dir>                                    rebuild from a clean clone
//
// Limits now:
// - Builds and verifies only; it publishes nothing (no signature, no upload, no tag pushed).

import { buildCommit, buildTag, Refused, verify } from "./build";

const USAGE = `usage:
  bun run release build <tag> --out <dir>
  bun run release build --commit <sha> --version <A.B.C> --out <dir>
  bun run release verify <dir>`;

function flags(args: string[]) {
  const named: Record<string, string> = {};
  const rest: string[] = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      if (i + 1 >= args.length) throw new Refused(`${args[i]} needs a value\n${USAGE}`);
      named[args[i].slice(2)] = args[++i];
    } else rest.push(args[i]);
  }
  return { named, rest };
}

async function main(argv: string[]): Promise<number> {
  const [cmd, ...args] = argv;
  const { named, rest } = flags(args);
  if (cmd === "build") {
    if (!named.out) throw new Refused(`--out is required\n${USAGE}`);
    if (rest.length === 1 && !named.commit && !named.version) await buildTag(rest[0], named.out);
    else if (rest.length === 0 && named.commit && named.version) await buildCommit(named.commit, named.version, named.out);
    else throw new Refused(USAGE);
    return 0;
  }
  if (cmd === "verify" && rest.length === 1) return (await verify(rest[0])) ? 0 : 1;
  throw new Refused(USAGE);
}

try {
  process.exit(await main(process.argv.slice(2)));
} catch (e) {
  if (!(e instanceof Refused)) throw e;
  console.error(e.message);
  process.exit(1);
}
