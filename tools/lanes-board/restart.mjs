// Restarting the Project Manager from its pages (the phone's Launch tab). On
// the PC the board runs under a loop (follow.cmd, or run.cmd at logon) that
// moves its checkout to the newest origin branch and starts it again 30 s
// after it stops, so a restart is the server exiting. Only a board under that
// loop may do it: one started by hand would just go away.

// The loop's script named in a parent's command line ("follow.cmd" or
// "run.cmd"), or null.
export function restartLoopOf(commandLine) {
  return String(commandLine ?? '').match(/(?:^|[\\/"\s])((?:follow|run)\.cmd)\b/i)?.[1].toLowerCase() ?? null;
}

// The parent process's command line: PowerShell on Windows, ps elsewhere; null
// when it can't be read. `run` is a promisified execFile.
export async function parentCommandLine(run, ppid = process.ppid, platform = process.platform) {
  try {
    const { stdout } = platform === 'win32'
      ? await run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command',
        `(Get-CimInstance Win32_Process -Filter "ProcessId=${Number(ppid)}").CommandLine`], { windowsHide: true, timeout: 20_000 })
      : await run('ps', ['-o', 'args=', '-p', String(Number(ppid))], { timeout: 5000 });
    return stdout.trim() || null;
  } catch {
    return null;
  }
}

// POST /restart, and the board's line in /data. `loop` returns the loop's
// script, or null while it isn't known or there is none. The answer goes out
// before the server exits.
export function restartApi({ loop, exit = (code) => process.exit(code), delayMs = 500, startedAt = Date.now(), log = console.log }) {
  let leaving = false;
  return {
    info: () => ({ startedAt, restartable: !!loop() && !leaving, restarting: leaving }),
    post(url) {
      if (url !== '/restart') return undefined;
      const by = loop();
      if (!by) throw new Error("The Project Manager wasn't started by its restart loop on the PC (follow.cmd or run.cmd), so it can't start itself again: restart it on the PC.");
      if (!leaving) {
        leaving = true;
        log(`Restarting on request: ${by} starts the board again on the latest master`);
        setTimeout(() => exit(0), delayMs);
      }
      return { restarting: true, loop: by };
    },
  };
}
