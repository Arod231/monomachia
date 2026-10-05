# Presses Send in the Claude desktop app for a launch the lanes board just
# opened (tools/lanes-board/launcher.mjs): it finds the new-session box holding
# the launch's prompt and presses that box's Send button, first confirming the
# app's "Trust this workspace?" dialog if, and only if, it names the launch's
# folder. Windows UI Automation only, no mouse or keyboard, so it works with
# nobody at the PC; not while the PC is locked, though, since the app is hidden
# from UI Automation then. The app's accessibility tree can take about 8 s to
# fill in once something starts reading it, so it keeps looking for a while.
#   LANES_PROMPT  the prompt the link put in the box (its exact text)
#   LANES_FOLDER  the folder the link named (the repository)
# It prints one line of JSON: {"result": "...", "ms": N, "trusted": bool}, with
# result one of
#   pressed    Send was pressed and the prompt left the box
#   locked     the PC is locked
#   no-app     no Claude window
#   no-draft   no box holding the prompt
#   no-send    the box has no Send button that can be pressed
#   not-taken  Send was pressed but the prompt stayed in the box
#   trust      the app is asking to trust a folder other than LANES_FOLDER
#   error      something else went wrong (with "error")
# -LockOnly only answers {"result": "locked"} or {"result": "unlocked"}. The
# trust dialog can come up a moment after the draft, so the box must have shown
# for -SettleMs before Send is pressed. -App names the program whose windows are
# searched (claude, the desktop app; tests pass a stand-in).
param([int]$WaitMs = 60000, [int]$TakeMs = 10000, [int]$SettleMs = 2000, [string]$App = 'claude', [switch]$LockOnly)
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
$trusted = $false
function Answer($result, $extra = @{}) {
  $o = [ordered]@{ result = $result; ms = $sw.ElapsedMilliseconds; trusted = $trusted }
  foreach ($k in $extra.Keys) { $o[$k] = $extra[$k] }
  [pscustomobject]$o | ConvertTo-Json -Compress
  exit 0
}

try {
  # Locked: this session's WTSSessionInfoEx flags say so (0 locked, 1 unlocked).
  Add-Type @'
using System; using System.Runtime.InteropServices;
public static class LanesSessionLock {
  [DllImport("wtsapi32.dll")] static extern bool WTSQuerySessionInformationW(IntPtr server, int session, int infoClass, out IntPtr buffer, out int bytes);
  [DllImport("wtsapi32.dll")] static extern void WTSFreeMemory(IntPtr memory);
  [DllImport("kernel32.dll")] static extern bool ProcessIdToSessionId(int pid, out int session);
  public static bool Locked() {
    int session; IntPtr buffer; int bytes;
    if (!ProcessIdToSessionId(System.Diagnostics.Process.GetCurrentProcess().Id, out session)) return false;
    if (!WTSQuerySessionInformationW(IntPtr.Zero, session, 25, out buffer, out bytes)) return false;
    // WTSINFOEXW: Level, then (8-byte aligned) SessionId, SessionState, SessionFlags.
    int flags = Marshal.ReadInt32(buffer, 16);
    WTSFreeMemory(buffer);
    return flags == 0;
  }
}
'@
  if ($LockOnly) { if ([LanesSessionLock]::Locked()) { Answer 'locked' } else { Answer 'unlocked' } }
  if ([LanesSessionLock]::Locked()) { Answer 'locked' }

  $norm = { param($s) (([string]$s).Replace([string][char]0xFF0F, '/') -replace '\s+', ' ').Trim() }
  $want = & $norm $env:LANES_PROMPT
  if (-not $want) { Answer 'error' @{ error = 'LANES_PROMPT is empty' } }
  $folder = ([string]$env:LANES_FOLDER).Replace('/', '\').TrimEnd('\').ToLowerInvariant()

  Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
  $AE = [System.Windows.Automation.AutomationElement]
  $TS = [System.Windows.Automation.TreeScope]
  $CT = [System.Windows.Automation.ControlType]
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $isEdit = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $CT::Edit)
  $isText = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $CT::Text)
  $button = { param($name) New-Object System.Windows.Automation.AndCondition(
    (New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, $CT::Button)),
    (New-Object System.Windows.Automation.PropertyCondition($AE::NameProperty, $name))) }
  $isSend = & $button 'Send'
  $isTrust = & $button 'Trust workspace'

  # The app's top-level windows (for the Claude app, its own claude.exe: its
  # sessions' claude.exe processes have none).
  $windows = {
    $ids = @(Get-Process -Name $App -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    @($AE::RootElement.FindAll($TS::Children, [System.Windows.Automation.Condition]::TrueCondition) |
      Where-Object { $ids -contains $_.Current.ProcessId })
  }
  # The box holding the prompt, in any of them.
  $findBox = {
    foreach ($w in (& $windows)) {
      foreach ($e in $w.FindAll($TS::Descendants, $isEdit)) {
        try {
          $vp = $null
          if ($e.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern, [ref]$vp) -and (& $norm $vp.Current.Value) -eq $want) { return $e }
        } catch { }
      }
    }
    $null
  }

  # "Trust this workspace?": confirms it when it names the launch's own folder.
  # The dialog is the nearest window above its button that holds no prompt box
  # (never the app's own window). Says 'confirmed', 'other' (a dialog naming
  # another folder, left for the owner) or 'none'.
  $trustCheck = {
    $seen = 'none'
    foreach ($w in (& $windows)) {
      foreach ($t in $w.FindAll($TS::Descendants, $isTrust)) {
        $dialog = $t
        do { $dialog = $walker.GetParent($dialog) } while ($dialog -and $dialog.Current.ControlType -ne $CT::Window)
        if (-not $dialog -or $dialog.FindFirst($TS::Descendants, $isEdit)) { continue }
        $names = @($dialog.FindAll($TS::Descendants, $isText) | ForEach-Object { $_.Current.Name.Replace('/', '\').TrimEnd('\').ToLowerInvariant() })
        if ($folder -and $names -contains $folder) {
          $t.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
          $script:trusted = $true
          Start-Sleep -Milliseconds 600
          if ($seen -eq 'none') { $seen = 'confirmed' }
        } elseif ($names.Count) { $seen = 'other' }
      }
    }
    $seen
  }

  $sawApp = $false; $sawBox = $false; $otherFolder = $false; $boxSince = $null
  while ($sw.ElapsedMilliseconds -lt $WaitMs) {
    if ([LanesSessionLock]::Locked()) { Answer 'locked' }
    try {
      $wins = & $windows
      if ($wins.Count) { $sawApp = $true }
      # Never press Send behind a dialog it won't confirm.
      if ((& $trustCheck) -eq 'other') { $otherFolder = $true; $boxSince = $null; Start-Sleep -Milliseconds 400; continue }

      $box = & $findBox
      if (-not $box) { $boxSince = $null }
      else {
        $sawBox = $true
        if ($null -eq $boxSince) { $boxSince = $sw.ElapsedMilliseconds }
      }
      if ($box -and $sw.ElapsedMilliseconds - $boxSince -ge $SettleMs) {
        # This box's Send: the nearest ancestor holding exactly one.
        $send = $null
        $node = $box
        for ($i = 0; $i -lt 10 -and $node; $i++) {
          $node = $walker.GetParent($node)
          if (-not $node) { break }
          $sends = $node.FindAll($TS::Descendants, $isSend)
          if ($sends.Count -eq 1) { $send = $sends[0]; break }
          if ($sends.Count -gt 1) { break }
        }
        if ($send -and $send.Current.IsEnabled) {
          $send.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
          # Sent once the prompt has left the box. A trust dialog coming up now
          # also hides the box, so look at that first.
          $until = $sw.ElapsedMilliseconds + $TakeMs
          while ($sw.ElapsedMilliseconds -lt $until) {
            Start-Sleep -Milliseconds 400
            try {
              $after = & $trustCheck
              if ($after -eq 'other') { Answer 'trust' }
              if ($after -eq 'none' -and -not (& $findBox)) { Answer 'pressed' }
            } catch { }
          }
          Answer 'not-taken'
        }
      }
    } catch [System.Windows.Automation.ElementNotAvailableException] {
      # Something closed while being read; look again.
    }
    Start-Sleep -Milliseconds 400
  }
  if ($otherFolder) { Answer 'trust' }
  if ($sawBox) { Answer 'no-send' }
  if ($sawApp) { Answer 'no-draft' }
  Answer 'no-app'
} catch {
  Answer 'error' @{ error = "$($_.Exception.Message)" }
}
