import { test } from "node:test";
import assert from "node:assert/strict";
import { XMLSerializer } from "@xmldom/xmldom";
import { applyDiff, countSel, diffOps, parseXml } from "./patch.ts";

const doc = () =>
  parseXml(`<mdscript><cues>
<cue name="A"><actions><x v="a"/><x v="b"/></actions></cue>
<cue name="B"><actions><x v="a"/><x v="a"/></actions></cue>
</cues></mdscript>`);

const show = (d: ReturnType<typeof doc>) => new XMLSerializer().serializeToString(d).replace(/\n/g, "");

// Applies one diff (its ops' XML) to a fresh doc and returns the results and the patched XML
const patch = (ops: string) => {
  const d = doc();
  const results = applyDiff(d, parseXml(`<diff>${ops}</diff>`).documentElement!);
  return { results, xml: show(d) };
};

test("countSel counts with XPath as X4 reads it: a[@x='y'][2] is the 2nd match in each parent", () => {
  assert.equal(countSel("/mdscript/cues/cue/actions/x[@v='a'][2]", doc()), 1);
  assert.equal(countSel("//x[@v='a']", doc()), 3);
  assert.equal(countSel("//cue[@name='C']", doc()), 0);
  assert.equal(countSel("//cue[@name='A']/@name", doc()), 1);
  // A relative sel is read from the document
  assert.equal(countSel("mdscript/cues", doc()), 1);
});

test("countSel says why a sel can't be counted", () => {
  assert.match(String(countSel("//cue[@name='A'", doc())), /^not a valid XPath/);
  assert.equal(countSel("count(//x)", doc()), "not a node set");
  assert.equal(countSel("", doc()), "no sel");
});

test("diffOps lists the operation elements of a diff, without comments or text", () => {
  const diff = parseXml(`<diff><!-- c --><add sel="/a"/> text <remove sel="/b"/></diff>`).documentElement!;
  assert.deepEqual(diffOps(diff).map((op) => op.tagName), ["add", "remove"]);
});

test("add appends by default, and prepend, before and after place the new nodes", () => {
  assert.match(patch(`<add sel="//cue[@name='A']/actions"><y/></add>`).xml, /<x v="b"\/><y\/><\/actions>/);
  assert.match(patch(`<add sel="//cue[@name='A']/actions" pos="prepend"><y/></add>`).xml, /<actions><y\/><x v="a"\/>/);
  assert.match(patch(`<add sel="//cue[@name='A']//x[@v='b']" pos="before"><y/><z/></add>`).xml, /<x v="a"\/><y\/><z\/><x v="b"\/>/);
  assert.match(patch(`<add sel="//cue[@name='A']//x[@v='a']" pos="after"><y/></add>`).xml, /<x v="a"\/><y\/><x v="b"\/>/);
});

test("add with type=\"@name\" sets an attribute", () => {
  assert.match(patch(`<add sel="//cue[@name='A']" type="@extra">1</add>`).xml, /<cue name="A" extra="1">/);
});

test("replace swaps an attribute's value, an element or a text node", () => {
  assert.match(patch(`<replace sel="//cue[@name='A']/@name">Z</replace>`).xml, /<cue name="Z">/);
  assert.match(patch(`<replace sel="//cue[@name='A']//x[@v='b']"><y/></replace>`).xml, /<x v="a"\/><y\/><\/actions>/);
  const d = parseXml("<a><b>old</b></a>");
  applyDiff(d, parseXml(`<diff><replace sel="/a/b/text()">new</replace></diff>`).documentElement!);
  assert.equal(show(d), "<a><b>new</b></a>");
});

test("remove takes out an element or an attribute", () => {
  assert.doesNotMatch(patch(`<remove sel="//cue[@name='B']"/>`).xml, /name="B"/);
  assert.match(patch(`<remove sel="//cue[@name='A']/@name"/>`).xml, /<cue><actions>/);
});

test("ops apply in order, so a later op sees what an earlier one changed", () => {
  const { results } = patch(`
    <add sel="/mdscript/cues"><cue name="New"/></add>
    <add sel="//cue[@name='New']"><actions/></add>
    <replace sel="//cue[@name='A']/@name">Z</replace>
    <remove sel="//cue[@name='A']"/>`);
  assert.deepEqual(
    results.map((r) => r.count),
    [1, 1, 1, 0],
  );
});

test("an op that doesn't match exactly once is skipped, as X4 skips it", () => {
  const { results, xml } = patch(`
    <remove sel="//x[@v='a']"/>
    <remove sel="//cue[@name='C']"/>
    <add sel="//cue[@name='A'"/>`);
  assert.deepEqual(
    results.map((r) => [r.op, r.sel, r.count]),
    [
      ["remove", "//x[@v='a']", 3],
      ["remove", "//cue[@name='C']", 0],
      ["add", "//cue[@name='A'", results[2].count],
    ],
  );
  assert.match(String(results[2].count), /^not a valid XPath/);
  assert.equal(xml, show(doc()));
});
