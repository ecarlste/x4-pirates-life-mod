// The settings as the player README (release/README.txt) names them, and as the config file
// (md/apirateslife_config.xml) sets them, each by setting name -> its group (Settings or Tuning)
// and default value, and the differences between the two.
import * as xpath from "xpath";
import { configDefaults } from "../check-settings-defaults/defaults.ts";
import { parseXml } from "../diff-patches/patch.ts";

export type Setting = { group: string; value: string };

// The README's "Settings: …" and "Tuning: …" lines each start a group, which runs to the next
// group or underlined heading; inside one, an entry is a line "  Name (default value)"
const GROUP = /^(Settings|Tuning):/;
const UNDERLINE = /^[-=]{3,}\s*$/;
const ENTRY = /^ {2}(\w+) \(default ([^)]+)\)\s*$/;

export const readmeSettings = (text: string): Map<string, Setting> => {
  const settings = new Map<string, Setting>();
  const lines = text.split(/\r?\n/);
  let group = "";
  lines.forEach((line, i) => {
    if (UNDERLINE.test(lines[i + 1] ?? "")) group = "";
    group = GROUP.exec(line)?.[1] ?? group;
    const entry = ENTRY.exec(line);
    if (group && entry) settings.set(entry[1], { group, value: entry[2] });
  });
  return settings;
};

// The config file's banner comments ("===== Settings: … =====") each start a group, running to
// the next banner; a setting above every banner has group ""
const BANNER = /^\s*=+\s*(Settings|Tuning):/;
const GLOBAL = /^global\.\$APiratesLife_(\w+)$/;

export const configSettings = (xml: string): Map<string, Setting> => {
  const groups = new Map<string, string>();
  let group = "";
  const nodes = xpath.select("//library[@name='Defaults']//node()", parseXml(xml) as unknown as globalThis.Node) as Node[];
  for (const node of nodes) {
    if (node.nodeType === node.COMMENT_NODE) group = BANNER.exec(node.nodeValue ?? "")?.[1] ?? group;
    const name = node.nodeName === "set_value" ? GLOBAL.exec((node as Element).getAttribute("name") ?? "")?.[1] : undefined;
    if (name) groups.set(name, group);
  }
  return new Map([...configDefaults(xml)].map(([name, value]) => [name, { group: groups.get(name) ?? "", value }]));
};

const same = (a: string, b: string) => a === b || (a.trim() !== "" && Number(a) === Number(b));

// One line per difference: a setting only one side has, in another group, or with another default
export const compareSettings = (readme: Map<string, Setting>, fromConfig: Map<string, Setting>): string[] => [
  ...[...readme].flatMap(([name, { group, value }]) => {
    const other = fromConfig.get(name);
    if (!other) return [`${name}: in the README only`];
    return [
      ...(group === other.group ? [] : [`${name}: under ${group} in the README, ${other.group || "no banner"} in the config file`]),
      ...(same(value, other.value) ? [] : [`${name}: the README gives default ${value}, the config file ${other.value}`]),
    ];
  }),
  ...[...fromConfig]
    .filter(([name]) => !readme.has(name))
    .map(([name, { group }]) => `${name}: in the config file only (${group || "under no Settings or Tuning banner"})`),
];
