// The settings' two copies of their defaults: the config file's (md/apirateslife_config.xml, its
// Defaults library) and the loader's own (md/apirateslife_settings.xml, the $Defaults table in its
// Validate library, used when X4 skipped the config file). Each is read as setting name -> value.
import type { Element } from "@xmldom/xmldom";
import * as xpath from "xpath";
import { parseXml } from "../diff-patches/patch.ts";

const select = (sel: string, xml: string) =>
  xpath.select(sel, parseXml(xml) as unknown as globalThis.Node) as unknown as Element[];

export const GLOBAL = /^global\.\$APiratesLife_(\w+)$/;

// Each global the config file's Defaults library sets, by setting name
export const configDefaults = (xml: string): Map<string, string> => {
  const defaults = new Map<string, string>();
  for (const el of select("//library[@name='Defaults']//set_value", xml)) {
    const name = GLOBAL.exec(el.getAttribute("name") ?? "")?.[1];
    if (name) defaults.set(name, el.getAttribute("exact") ?? "");
  }
  return defaults;
};

// The entries of the loader's table[$Name = value, ...], by setting name
export const loaderDefaults = (xml: string): Map<string, string> => {
  const [el] = select("//library[@name='Validate']//set_value[@name='$Defaults']", xml);
  const table = /^\s*table\[([^\]]*)\]\s*$/.exec(el?.getAttribute("exact") ?? "");
  if (!table) throw new Error("the loader's Validate library sets no $Defaults = table[...]");
  return new Map(
    table[1]
      .split(",")
      .filter((entry) => entry.trim())
      .map((entry) => {
        const [, name, value] = /^\s*\$(\w+)\s*=\s*(\S+)\s*$/.exec(entry) ?? [];
        if (!name) throw new Error(`can't read the $Defaults entry '${entry.trim()}'`);
        return [name, value];
      }),
  );
};

// Two values agree when equal as text or, both being numbers, as numbers
export const same = (a: string, b: string) => a === b || (a.trim() !== "" && Number(a) === Number(b));

// One line per difference: a value that differs, or a setting only one copy has
export const compareDefaults = (fromConfig: Map<string, string>, fromLoader: Map<string, string>): string[] => [
  ...[...fromConfig].flatMap(([name, value]) => {
    const other = fromLoader.get(name);
    if (other === undefined) return [`${name}: in the config file only`];
    return same(value, other) ? [] : [`${name}: the config file gives ${value}, the loader ${other}`];
  }),
  ...[...fromLoader.keys()].filter((name) => !fromConfig.has(name)).map((name) => `${name}: in the loader only`),
];
