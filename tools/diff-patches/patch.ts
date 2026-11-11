// X4's XML diff patches (RFC 5261, as X4 reads them), applied to a DOM: <add>, <replace> and
// <remove>, each with a sel that must match exactly one node. X4 skips an op whose sel matches
// nothing or more than one node, and applies the rest in order, so a later op sees what an
// earlier one changed. sels are XPath, counted as X4 counts them: a[@x='y'][2] is the 2nd match
// in each parent (Python's ElementTree counts it differently, which is why this is TypeScript).
import { DOMParser, type Attr, type Document, type Element, type Node } from "@xmldom/xmldom";
import * as xpath from "xpath";

// A DOM of text, throwing on any parse error or warning
export const parseXml = (text: string): Document => {
  const doc = new DOMParser({
    onError: (level, message) => {
      throw new Error(`${level}: ${message}`);
    },
  }).parseFromString(text, "text/xml");
  if (!doc.documentElement) throw new Error("no root element");
  return doc;
};

const select = (sel: string, doc: Document) => xpath.select(sel, doc as unknown as globalThis.Node);

// How many nodes sel selects in doc, or why it can't be counted
export const countSel = (sel: string, doc: Document): number | string => {
  if (!sel) return "no sel";
  let selected;
  try {
    selected = select(sel, doc);
  } catch (e) {
    return `not a valid XPath (${(e as Error).message})`;
  }
  return Array.isArray(selected) ? selected.length : "not a node set";
};

const children = (el: Element) => Array.from(el.childNodes) as Node[];

// The operation elements of a <diff>, in order
export const diffOps = (diff: Element): Element[] =>
  children(diff).filter((n): n is Element => n.nodeType === n.ELEMENT_NODE);

// What one op's sel matched (a count, or why it couldn't be counted); applied when the count is 1
export type OpResult = { op: string; sel: string; count: number | string };

const ATTRIBUTE_NODE = 2;
const TEXT_NODE = 3;

// The op's content, copied into doc: its child elements, or its text when it has none
const content = (op: Element, doc: Document): Node[] => {
  const elements = diffOps(op);
  const nodes = elements.length ? elements : children(op).filter((n) => n.nodeType === TEXT_NODE);
  return nodes.map((n) => doc.importNode(n, true));
};

const apply = (op: Element, target: Node, doc: Document) => {
  if (op.tagName === "remove") {
    if (target.nodeType === ATTRIBUTE_NODE) (target as Attr).ownerElement!.removeAttributeNode(target as Attr);
    else target.parentNode!.removeChild(target);
  } else if (op.tagName === "replace") {
    if (target.nodeType === ATTRIBUTE_NODE) (target as Attr).value = op.textContent ?? "";
    else if (target.nodeType === TEXT_NODE) target.nodeValue = op.textContent ?? "";
    else {
      for (const node of content(op, doc)) target.parentNode!.insertBefore(node, target);
      target.parentNode!.removeChild(target);
    }
  } else if (op.tagName === "add") {
    const type = op.getAttribute("type") ?? "";
    if (type.startsWith("@")) {
      (target as Element).setAttribute(type.slice(1), op.textContent ?? "");
      return;
    }
    const pos = op.getAttribute("pos") ?? "";
    const parent = pos === "before" || pos === "after" ? target.parentNode! : target;
    const before = pos === "before" ? target : pos === "after" ? target.nextSibling : pos === "prepend" ? target.firstChild : null;
    for (const node of content(op, doc)) parent.insertBefore(node, before);
  }
};

// Applies each op of diff to doc in order, as X4 does, and says what each sel matched
export const applyDiff = (doc: Document, diff: Element): OpResult[] =>
  diffOps(diff).map((op) => {
    const sel = op.getAttribute("sel") ?? "";
    const count = countSel(sel, doc);
    if (count === 1) apply(op, (select(sel, doc) as unknown as Node[])[0], doc);
    return { op: op.tagName, sel, count };
  });
