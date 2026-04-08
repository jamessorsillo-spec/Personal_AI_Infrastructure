#!/usr/bin/env bun
/**
 * LoadAppleNotesTasks.hook.ts — Inject Apple Notes task list into session context
 *
 * Reads the synced master-tasks.md file and injects it as a system-reminder
 * so Claude always has visibility into the user's task list.
 *
 * TRIGGER: SessionStart
 *
 * INPUT:
 * - Environment: PAI_DIR
 * - Files: MEMORY/TASKS/master-tasks.md
 *
 * OUTPUT:
 * - stdout: <system-reminder> with task list content (if file exists)
 * - stderr: Status messages
 * - exit(0): Always (never blocks session)
 *
 * SYNC FLOW:
 * Apple Notes → apple-notes-sync.sh → MEMORY/TASKS/master-tasks.md → this hook → context
 *
 * PERFORMANCE:
 * - Blocking: No (tasks are helpful but not critical)
 * - Typical execution: <10ms (single file read)
 * - Skipped for subagents: Yes
 */

import { readFileSync, existsSync, statSync } from 'fs';
import { join } from 'path';
import { getPaiDir } from './lib/paths';

const MAX_TASK_CONTENT_CHARS = 8000; // Cap to avoid bloating context

function getRelativeAge(syncDate: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - syncDate.getTime();
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffHours < 1) return 'just now';
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays === 1) return 'yesterday';
  if (diffDays < 7) return `${diffDays}d ago`;
  if (diffDays < 30) return `${Math.floor(diffDays / 7)}w ago`;
  return `${diffDays}d ago`;
}

function parseFrontmatter(content: string): { meta: Record<string, string>; body: string } {
  const meta: Record<string, string> = {};
  let body = content;

  if (content.startsWith('---')) {
    const endIdx = content.indexOf('---', 3);
    if (endIdx !== -1) {
      const frontmatter = content.substring(3, endIdx).trim();
      body = content.substring(endIdx + 3).trim();

      for (const line of frontmatter.split('\n')) {
        const colonIdx = line.indexOf(':');
        if (colonIdx !== -1) {
          const key = line.substring(0, colonIdx).trim();
          const val = line.substring(colonIdx + 1).trim().replace(/^["']|["']$/g, '');
          meta[key] = val;
        }
      }
    }
  }

  return { meta, body };
}

function countTasks(body: string): { total: number; done: number; open: number } {
  const checkboxes = body.match(/- \[([ xX])\]/g) || [];
  const total = checkboxes.length;
  const done = checkboxes.filter(c => c.includes('[x]') || c.includes('[X]')).length;
  return { total, done, open: total - done };
}

async function main() {
  try {
    // Skip for subagents
    const claudeProjectDir = process.env.CLAUDE_PROJECT_DIR || '';
    const isSubagent = claudeProjectDir.includes('/.claude/Agents/') ||
                       process.env.CLAUDE_AGENT_TYPE !== undefined;

    if (isSubagent) {
      console.error('LoadAppleNotesTasks: skipped (subagent)');
      process.exit(0);
    }

    const paiDir = getPaiDir();
    const tasksFile = join(paiDir, 'MEMORY', 'TASKS', 'master-tasks.md');

    if (!existsSync(tasksFile)) {
      console.error('LoadAppleNotesTasks: no master-tasks.md found (run apple-notes-sync.sh to create)');
      process.exit(0);
    }

    const content = readFileSync(tasksFile, 'utf-8');
    if (!content.trim()) {
      console.error('LoadAppleNotesTasks: master-tasks.md is empty');
      process.exit(0);
    }

    const { meta, body } = parseFrontmatter(content);
    const { total, done, open } = countTasks(body);

    // Build staleness indicator
    let ageStr = '';
    let staleWarning = '';
    if (meta.synced_at) {
      const syncDate = new Date(meta.synced_at);
      ageStr = getRelativeAge(syncDate);

      const diffDays = Math.floor((Date.now() - syncDate.getTime()) / (1000 * 60 * 60 * 24));
      if (diffDays > 7) {
        staleWarning = `\n> **Warning:** Task list is ${diffDays} days old. Re-sync from Apple Notes for latest.`;
      }
    }

    // Truncate if too large
    let taskContent = body;
    let truncated = false;
    if (taskContent.length > MAX_TASK_CONTENT_CHARS) {
      taskContent = taskContent.substring(0, MAX_TASK_CONTENT_CHARS);
      truncated = true;
    }

    // Build the context injection
    const header = [
      `## Master Task List (from Apple Notes)`,
      ``,
      `Source: ${meta.note_name || 'Apple Notes'} | Synced: ${ageStr || meta.synced_at || 'unknown'}`,
      total > 0 ? `Progress: ${done}/${total} complete (${open} open)` : '',
      staleWarning,
      ``
    ].filter(Boolean).join('\n');

    const footer = truncated
      ? '\n\n> *Task list truncated. Full list in ~/.claude/MEMORY/TASKS/master-tasks.md*'
      : '';

    console.log(`<system-reminder>
${header}
${taskContent}${footer}
</system-reminder>`);

    console.error(`LoadAppleNotesTasks: loaded ${total} tasks (${open} open, synced ${ageStr})`);
    process.exit(0);
  } catch (error) {
    console.error('LoadAppleNotesTasks: error:', error);
    process.exit(0); // Never block session
  }
}

main();
