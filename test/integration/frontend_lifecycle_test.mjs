import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { execFileSync } from "node:child_process"
import vm from "node:vm"
import test from "node:test"

const path = "app/javascript/controllers/flash_controller.js"
const source = process.env.FRONTEND_TEST_REF
  ? execFileSync("git", ["show", `${process.env.FRONTEND_TEST_REF}:${path}`], { encoding: "utf8" })
  : readFileSync(path, "utf8")

function setup() {
  const callbacks = new Map()
  let nextId = 0
  const schedule = (callback) => {
    callbacks.set(++nextId, callback)
    return nextId
  }
  const cancel = (id) => callbacks.delete(id)
  const context = vm.createContext({
    Controller: class {},
    requestAnimationFrame: schedule,
    cancelAnimationFrame: cancel,
    setTimeout: schedule,
    clearTimeout: cancel
  })
  const Flash = vm.runInContext(source
    .replace(/^import .*$/m, "")
    .replace("export default class", "(class") + ")", context)
  const controller = new Flash()
  const classes = new Set()
  const frame = { connected: true }
  controller.element = {
    connected: true,
    classList: {
      add: (...names) => names.forEach(name => classes.add(name)),
      remove: (...names) => names.forEach(name => classes.delete(name))
    },
    addEventListener() {},
    removeEventListener() {},
    remove() { this.connected = false }
  }
  frame.child = controller.element
  return { controller, callbacks, frame }
}

test("flash disconnect cancels pending animation and dismissal on reconnect", () => {
  const { controller, callbacks } = setup()
  controller.connect()
  controller.dismiss()
  controller.disconnect()
  assert.equal(callbacks.size, 0)
  controller.connect()
  assert.equal(controller.element.connected, true)
  controller.disconnect()
  assert.equal(callbacks.size, 0)
})

test("flash dismissal removes only its node and preserves the surrounding frame", () => {
  const { controller, callbacks, frame } = setup()
  controller.connect()
  controller.dismiss()
  for (const callback of [...callbacks.values()]) callback()
  assert.equal(frame.child.connected, false)
  assert.equal(frame.connected, true)
})
