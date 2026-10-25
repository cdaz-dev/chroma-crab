// chroma-crab-shim: a stand-in claude.exe that install.ps1 compiles and puts
// ahead of the real claude on PATH, so keybinds, Windows Terminal profiles
// and anything else that runs `claude` get a crab colour too.
//
// It has to be an .exe: Windows Terminal and other direct launches only look
// for claude.exe on PATH and would skip a claude.cmd.
using System;
using System.Diagnostics;
using System.IO;

class ChromaCrabShim
{
    static int Main()
    {
        // Pass our own arguments through untouched: take the raw command line
        // and drop the program name from the front of it.
        string cmd = Environment.CommandLine;
        string rest;
        if (cmd.StartsWith("\""))
        {
            int end = cmd.IndexOf('"', 1);
            rest = end < 0 ? "" : cmd.Substring(end + 1);
        }
        else
        {
            int space = cmd.IndexOf(' ');
            rest = space < 0 ? "" : cmd.Substring(space);
        }

        // Installed layout: %LOCALAPPDATA%\chroma-crab\shim\claude.exe next to
        // %LOCALAPPDATA%\chroma-crab\chroma-crab.ps1
        string script = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "chroma-crab.ps1"));

        var psi = new ProcessStartInfo("powershell.exe",
            "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"" + rest);
        psi.UseShellExecute = false;

        // Claude Code handles Ctrl+C itself; don't let it take the shim down.
        Console.CancelKeyPress += (s, e) => { e.Cancel = true; };

        using (Process p = Process.Start(psi))
        {
            p.WaitForExit();
            return p.ExitCode;
        }
    }
}
