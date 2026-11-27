// OpenCode equivalents of the Claude Code hooks in .claude/settings.json. The
// checks themselves stay in tools/hooks/*.sh: this file only adapts payload and
// hook semantics, so one implementation guards both harnesses.
//
//   Claude PostToolUse (Edit|Write|MultiEdit) -> ctx.tool.hook("execute.after")
//     findings replace the tool result, so the agent sees them in the same turn
//   Claude PreToolUse (Bash)                  -> ctx.permission.hook("evaluate")
//     effect "deny" + message blocks the call before it runs, reason reaches the agent
//
// The scripts keep Claude's contract: exit 2 blocks (reason on stderr), project
// root from CLAUDE_PROJECT_DIR, hook JSON on stdin as { tool_input: { ... } }.
// Any other non-zero exit is treated as a broken script and asks instead of
// silently allowing the call.

import { Plugin } from "@opencode/plugin"
import { execFile } from "node:child_process"
import { existsSync } from "node:fs"
import path from "node:path"

const EDIT_TOOLS = new Set(["edit", "write", "patch", "apply_patch", "multiedit", "multi_edit"])
const PATH_KEYS = new Set(["path", "filePath", "file_path", "filepath", "filename", "target", "targets"])
// apply_patch headers, used only by the patch-shaped tools above.
const PATCH_FILE = /^\*\*\* (?:Update|Add|Delete) File: (.+\.lua)$/gm

// Shell gates, in the order Claude ran them. Each script exits 0 immediately
// when its pattern does not match the command it is given.
const SHELL_GATES = [
  { script: "tools/hooks/pre-commit-tests.sh", timeout: 120 },
  { script: "tools/hooks/pre-release-tag.sh", timeout: 30 },
]

const GUARD = "tools/hooks/lua-lint.sh"

type Run = { code: number; stderr: string }

function run(root: string, script: string, payload: unknown, timeoutSeconds: number): Promise<Run> {
  return new Promise((resolve) => {
    const child = execFile(
      "bash",
      [script],
      { cwd: root, timeout: timeoutSeconds * 1000, env: { ...process.env, CLAUDE_PROJECT_DIR: root } },
      (error, _stdout, stderr) => {
        const raw = error ? (error as { code?: unknown }).code : 0
        const code = typeof raw === "number" ? raw : error ? 1 : 0
        resolve({ code, stderr: (stderr ?? "").trim() })
      },
    )
    child.stdin?.write(JSON.stringify(payload))
    child.stdin?.end()
  })
}

// The repository this plugin belongs to: the directory holding the guarded
// scripts. Walk up from the plugin file, then from the session directory, so a
// session opened in a subdirectory still finds it and an unrelated one guards
// nothing.
function findRoot(starts: Array<string | undefined>): string | undefined {
  for (const start of starts) {
    let dir = start
    while (dir) {
      if (existsSync(path.join(dir, GUARD))) return dir
      const parent = path.dirname(dir)
      if (parent === dir) break
      dir = parent
    }
  }
  return undefined
}

const PATCH_TOOLS = new Set(["patch", "apply_patch"])

// Which .lua files a tool call touches. Only path-shaped input fields count as
// paths; edit bodies (oldString/newString) are never read as paths.
function luaFiles(tool: string, input: unknown): string[] {
  const found = new Set<string>()
  const scan = (text: string) => {
    for (const match of text.matchAll(PATCH_FILE)) found.add(match[1])
  }
  const queue: unknown[] = [input]
  const seen = new Set<unknown>()
  while (queue.length) {
    const value = queue.pop()
    if (typeof value === "string") {
      if (PATCH_TOOLS.has(tool)) scan(value)
      continue
    }
    if (!value || typeof value !== "object" || seen.has(value)) continue
    seen.add(value)
    if (Array.isArray(value)) {
      queue.push(...value)
      continue
    }
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      if (typeof item === "string") {
        if (PATH_KEYS.has(key) && item.endsWith(".lua")) found.add(item)
        continue
      }
      if (item && typeof item === "object") queue.push(item)
    }
  }
  return [...found]
}

function appendFindings(event: { result: { content?: string | readonly unknown[] } }, note: string) {
  const content = event.result.content
  if (Array.isArray(content)) event.result = { ...event.result, content: [...content, { type: "text", text: note }] }
  else event.result = { ...event.result, content: `${typeof content === "string" ? `${content}\n\n` : ""}${note}` }
}

export default Plugin.define({
  id: "bloodyscreen.checks",
  async setup(ctx) {
    const fromFile = (() => {
      try {
        return path.dirname(decodeURIComponent(new URL(import.meta.url).pathname))
      } catch {
        return undefined
      }
    })()
    const root = findRoot([
      fromFile && path.resolve(fromFile, "..", ".."),
      ctx.location.directory,
      ctx.location.project?.canonical,
    ])
    if (!root) return

    // Lint the Lua a tool call just changed (Claude's PostToolUse hook).
    await ctx.tool.hook("execute.after", async (event) => {
      if (event.status !== "completed" || !EDIT_TOOLS.has(event.tool)) return
      const files = luaFiles(event.tool, event.input).map((file) =>
        path.isAbsolute(file) ? file : path.resolve(ctx.location.directory, file),
      )
      if (files.length === 0) return
      const findings: string[] = []
      for (const file of files) {
        const result = await run(root, GUARD, { tool_input: { file_path: file } }, 30)
        if (result.code === 0) continue
        findings.push(result.stderr || `lua-lint reported nothing for ${file}`)
      }
      if (findings.length === 0) return
      appendFindings(
        event,
        `Lua checks failed (${GUARD}):\n\n${findings.join("\n\n")}\n\nThe file was written; fix these before continuing.`,
      )
    })

    // Run the pre-commit and release-tag gates before the shell call runs
    // (Claude's PreToolUse hooks). OpenCode offers one resource per subcommand
    // of a compound command, so each is passed to the scripts separately.
    await ctx.permission.hook("evaluate", async (event) => {
      if (event.action !== "shell") return
      const commands = event.resources.filter((resource) => /\bgit\b/.test(resource))
      if (commands.length === 0) return
      for (const gate of SHELL_GATES) {
        for (const command of commands) {
          const result = await run(root, gate.script, { tool_input: { command } }, gate.timeout)
          if (result.code === 0) continue
          event.effect = result.code === 2 ? "deny" : "ask"
          event.message = `${gate.script}: ${result.stderr || `exit ${result.code}`}`
          return
        }
      }
    })
  },
})
