// Run with: node --test apps/geomextric_web/test/geomextric_web/sdf3d_hook_test.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const file = new URL(
  "../../lib/geomextric_web/live/sdf3d_live.ex",
  import.meta.url,
);
const source = readFileSync(file, "utf8")
  .split('name=".Canvas">')[1]
  .split("</script>")[0];

function setup() {
  const calls = [];
  const gl = new Proxy(
    {
      getProgramParameter: () => true,
      getAttribLocation: () => 0,
      getUniformLocation: (_, name) => name,
    },
    {
      get(target, name) {
        if (name in target) return target[name];
        if (name === name.toUpperCase()) return name;
        return (...args) => {
          calls.push([name, ...args]);
          return {};
        };
      },
    },
  );
  const context = vm.createContext({});
  vm.runInContext(
    source.replace("export default", "globalThis.hook ="),
    context,
  );
  const scene = { texture: {}, height: 0, count: 0, maxHeight: 4096 };
  let records = [];
  const el = {
    querySelectorAll: (selector) => {
      assert.equal(selector, "[data-scene] > [data-shape]");
      return records.map((record) => ({
        dataset: { shape: JSON.stringify(record) },
      }));
    },
    appendChild() {},
  };
  return {
    context,
    gl,
    calls,
    scene,
    el,
    setRecords(value) {
      records = value;
    },
  };
}

test("scene additions, movement, and deletion upload data without compiling shaders", () => {
  const { context, gl, calls, scene, el, setRecords } = setup();
  const record = Array.from({ length: 16 }, (_, i) => i);
  const instance = { gl, scene, el, canvas: {} };
  setRecords(Array.from({ length: 603 }, () => record));
  context.hook.updated.call(instance);
  assert.equal(scene.count, 603);
  const allocation = calls.find(([name]) => name === "texImage2D");
  assert.deepEqual(allocation.slice(1, 9), [
    "TEXTURE_2D",
    0,
    "RGBA32F",
    4,
    603,
    0,
    "RGBA",
    "FLOAT",
  ]);
  assert.equal(allocation[9].length, 603 * 16);
  assert.deepEqual(Array.from(allocation[9].slice(0, 16)), record);

  context.hook.updated.call(instance);
  assert.equal(calls.filter(([name]) => name === "texSubImage2D").length, 1);
  setRecords([record]);
  context.hook.updated.call(instance);
  assert.equal(scene.count, 1);
  assert.equal(calls.filter(([name]) => name === "texImage2D").length, 2);
  assert.equal(
    calls.some(([name]) => /compile|link|createProgram/.test(name)),
    false,
  );
});

test("empty scenes allocate a valid texture; oversized scenes retain previous data", () => {
  const { context, gl, calls, scene, el, setRecords } = setup();
  context.uploadScene(gl, el, scene);
  assert.equal(scene.height, 1);
  assert.equal(scene.count, 0);
  scene.maxHeight = 2;
  setRecords(Array.from({ length: 3 }, () => Array(16).fill(0)));
  const before = calls.length;
  assert.throws(() => context.uploadScene(gl, el, scene), /texture limit/);
  assert.equal(calls.length, before);
  assert.equal(scene.count, 0);
});

test("program completion is polled before querying link status", () => {
  const { context, gl, calls, scene } = setup();
  let complete = false;
  let linkQueries = 0;
  gl.getProgramParameter = (_, name) => {
    if (name === "completion") return complete;
    linkQueries++;
    return true;
  };
  const pending = context.prepareDraw(
    gl,
    {},
    {},
    { COMPLETION_STATUS_KHR: "completion" },
  );
  assert.equal(pending.ready(), false);
  assert.equal(linkQueries, 0);
  complete = true;
  assert.equal(pending.ready(), true);
  const draw = pending.finish();
  scene.count = 603;
  draw(scene, [0, 0, 500], [0, 0, 0]);
  assert.ok(
    calls.some(
      ([name, location, value]) =>
        name === "uniform1i" && location === "shape_count" && value === 603,
    ),
  );
  draw.destroy();
  assert.ok(calls.some(([name]) => name === "deleteProgram"));
});
