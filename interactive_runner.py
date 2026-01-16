import subprocess
import os
import json
import sys
import argparse
from datetime import datetime

# Configuration
def get_steps():
    print("\n🏗️  Select Installation Type:")
    print("1. Standalone (MariaDB 11.4)")
    print("2. Galera Cluster")
    print("3. Replication Cluster")
    
    try:
        choice = input("\nChoice [1-3] (default: 1): ").strip()
    except EOFError:
        choice = '1'
    except KeyboardInterrupt:
        print("\n👋 Runner interrupted.")
        sys.exit(0)
        
    if choice == '2':
        return "Galera Cluster", [
            {
                "id": "config",
                "name": "Test Configuration",
                "description": "Validates environment and SSL configuration.",
                "command": "make test-config"
            },
            {
                "id": "start",
                "name": "Start Galera",
                "description": "Starts the Galera cluster nodes and load balancer.",
                "command": "make up-galera"
            },
            {
                "id": "inject",
                "name": "Inject Data",
                "description": "Injects the employees dataset into the cluster.",
                "command": "make inject-employee-galera"
            },
            {
                "id": "verify",
                "name": "Verify Galera",
                "description": "Runs functional tests on the Galera cluster.",
                "command": "make test-galera"
            },
            {
                "id": "perf",
                "name": "Performance Test",
                "description": "Runs sysbench performance tests on Galera.",
                "command": "make test-perf-galera PROFILE=light ACTION=run"
            }
        ]
    elif choice == '3':
        return "Replication Cluster", [
            {
                "id": "config",
                "name": "Test Configuration",
                "description": "Validates environment and SSL configuration.",
                "command": "make test-config"
            },
            {
                "id": "start",
                "name": "Start Replication",
                "description": "Starts the Replication cluster nodes.",
                "command": "make up-repli"
            },
            {
                "id": "setup",
                "name": "Setup Replication",
                "description": "Configures Master/Slave relationship.",
                "command": "make setup-repli"
            },
            {
                "id": "inject",
                "name": "Inject Data",
                "description": "Injects the employees dataset into the master node.",
                "command": "make inject-employee-repli"
            },
            {
                "id": "verify",
                "name": "Verify Replication",
                "description": "Runs functional tests on the replication setup.",
                "command": "make test-repli"
            },
            {
                "id": "perf",
                "name": "Performance Test",
                "description": "Runs sysbench performance tests on Replication.",
                "command": "make test-perf-repli PROFILE=light ACTION=run"
            }
        ]
    else:
        return "Standalone", [
            {
                "id": "config",
                "name": "Test Configuration",
                "description": "Validates environment and SSL configuration.",
                "command": "make test-config"
            },
            {
                "id": "start",
                "name": "Start MariaDB",
                "description": "Starts the MariaDB 11.4 container.",
                "command": "make mariadb114"
            },
            {
                "id": "status",
                "name": "Check Status",
                "description": "Shows the current status of the MariaDB container.",
                "command": "make status"
            },
            {
                "id": "inject",
                "name": "Inject Data",
                "description": "Injects the employees dataset.",
                "command": "make inject-data service=mariadb114 db=employees"
            },
            {
                "id": "verify",
                "name": "Verify Integrity",
                "description": "Runs data integrity checks.",
                "command": "make test-config"
            }
        ]

INSTALL_TYPE, STEPS = get_steps()

REPORT_FILE = "reports/run_report.html"

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Runner Report - {timestamp}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
    <style>
        :root {{
            --glass: rgba(255, 255, 255, 0.03);
            --glass-border: rgba(255, 255, 255, 0.08);
            --bg: #0b0e14;
        }}
        body {{
            font-family: 'Inter', sans-serif;
            background: radial-gradient(circle at 0% 0%, #1e293b 0%, #0f172a 50%, #020617 100%);
            color: #f1f5f9;
            min-height: 100vh;
        }}
        .glass {{
            background: var(--glass);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid var(--glass-border);
            border-radius: 1.5rem;
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
        }}
        .status-success {{ color: #10b981; text-shadow: 0 0 10px rgba(16, 185, 129, 0.3); }}
        .status-failure {{ color: #f43f5e; text-shadow: 0 0 10px rgba(244, 63, 94, 0.3); }}
        .status-skipped {{ color: #94a3b8; }}
        .code-block {{
            font-family: 'Fira Code', monospace;
            background: rgba(0, 0, 0, 0.4);
            border: 1px solid rgba(255, 255, 255, 0.03);
            box-shadow: inset 0 2px 4px 0 rgba(0, 0, 0, 0.06);
        }}
        pre {{
            white-space: pre-wrap;
            word-wrap: break-word;
        }}
        .step-card {{
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }}
        .step-card:hover {{
            transform: translateY(-4px);
            border-color: rgba(255, 255, 255, 0.15);
            background: rgba(255, 255, 255, 0.05);
        }}
        .gradient-text {{
            background: linear-gradient(135deg, #60a5fa 0%, #34d399 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}
        ::-webkit-scrollbar {{ width: 8px; }}
        ::-webkit-scrollbar-track {{ background: rgba(0, 0, 0, 0.2); }}
        ::-webkit-scrollbar-thumb {{ background: rgba(255, 255, 255, 0.1); border-radius: 4px; }}
        ::-webkit-scrollbar-thumb:hover {{ background: rgba(255, 255, 255, 0.2); }}
        
        .status-running {{ 
            color: #60a5fa; 
            text-shadow: 0 0 15px rgba(96, 165, 250, 0.4);
            animation: pulse-blue 2s infinite;
        }}
        @keyframes pulse-blue {{
            0%, 100% {{ opacity: 1; }}
            50% {{ opacity: 0.7; }}
        }}
        .header-compact {{ padding-bottom: 2rem; margin-bottom: 2rem; }}
        .step-compact {{ margin-bottom: 1.5rem !important; }}
    </style>
    <script>
        let countdown = 5;
        function updateTimer() {{
            const timerEl = document.getElementById('auto-reload-timer');
            const isFinished = document.body.hasAttribute('data-finished');
            
            if (isFinished) {{
                if (timerEl) timerEl.innerText = 'Execution Complete';
                return;
            }}

            if (timerEl) {{
                timerEl.innerText = 'Auto-refreshing in ' + countdown + 's';
            }}
            if (countdown <= 0) {{
                window.location.reload();
            }}
            countdown--;
        }}
        
        window.onload = () => {{
            // Start countdown
            setInterval(updateTimer, 1000);
            
            // Focus on running task
            const runningIcon = document.querySelector('.animate-spin');
            if (runningIcon) {{
                const section = runningIcon.closest('section');
                if (section) {{
                    section.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
                    section.classList.add('ring-2', 'ring-blue-500/50');
                }}
            }} else {{
                // If nothing is running, focus on the last successful/failed task
                const steps = document.querySelectorAll('section[id^="step-"]');
                let target = null;
                steps.forEach(s => {{
                    if (s.querySelector('.status-success') || s.querySelector('.status-failure')) {{
                        target = s;
                    }}
                }});
                if (target) {{
                    target.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
                }}
            }}
        }};
    </script>
</head>
<body class="p-6 md:p-12 text-slate-100" {data_finished}>
    <div class="max-w-6xl mx-auto">
        <header class="header-compact relative">
            <div class="absolute -top-12 -left-12 w-48 h-48 bg-blue-500/10 rounded-full blur-3xl"></div>
            <div class="absolute -top-12 -right-12 w-48 h-48 bg-emerald-500/10 rounded-full blur-3xl"></div>
            
            <div class="relative text-center">
                <h1 class="text-4xl font-black tracking-tight mb-3 gradient-text">
                    Test execution
                </h1>
                <p class="text-slate-400 text-sm font-light">
                    Real-time dashboard for <span class="text-slate-200 font-medium">test_db</span>
                </p>
                <div id="auto-reload-timer" class="mt-2 text-[10px] uppercase tracking-[0.3em] text-blue-400/60 font-bold">
                    Auto-refreshing in 5s
                </div>
                <div class="flex flex-wrap justify-center gap-4 mt-6">
                    <div class="glass px-4 py-2 flex flex-col items-center min-w-[120px]">
                        <span class="text-[9px] uppercase tracking-[0.1em] text-slate-500 font-bold">Type</span>
                        <span class="text-sm font-semibold text-slate-200">{install_type}</span>
                    </div>
                    <div class="glass px-4 py-2 flex flex-col items-center min-w-[120px]">
                        <span class="text-[9px] uppercase tracking-[0.1em] text-cyan-500/60 font-bold">Date</span>
                        <span class="text-sm font-semibold text-slate-200">{timestamp}</span>
                    </div>
                    <div class="glass px-4 py-2 flex flex-col items-center min-w-[80px]">
                        <span class="text-[9px] uppercase tracking-[0.1em] text-slate-500 font-bold">Steps</span>
                        <span class="text-xl font-black text-white">{total_steps}</span>
                    </div>
                    <div class="glass px-4 py-2 border-emerald-500/20 flex flex-col items-center min-w-[80px]">
                        <span class="text-[9px] uppercase tracking-[0.1em] text-emerald-500/60 font-bold">Passed</span>
                        <span class="text-xl font-black text-emerald-400">{passed_steps}</span>
                    </div>
                    <div class="glass px-4 py-2 border-rose-500/20 flex flex-col items-center min-w-[80px]">
                        <span class="text-[9px] uppercase tracking-[0.1em] text-rose-500/60 font-bold">Failed</span>
                        <span class="text-xl font-black text-rose-400">{failed_steps}</span>
                    </div>
                </div>
            </div>
        </header>

        <main class="space-y-4 relative">
            <div class="absolute left-6 top-0 bottom-0 w-px bg-gradient-to-b from-blue-500/20 via-slate-500/10 to-transparent hidden lg:block"></div>
            {steps_content}
        </main>

        <footer class="mt-20 text-center text-slate-500 text-sm font-medium tracking-wide">
            Generated by www.lightpath.fr Runner &bull; {timestamp}
        </footer>
    </div>
</body>
</html>
"""

STEP_TEMPLATE = """
<section id="step-{id}" class="step-card glass p-4 md:p-5 relative overflow-hidden step-compact">
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-4 relative z-10">
        <div class="flex items-center gap-4">
            <span class="text-[9px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-full bg-slate-800 text-slate-400 border border-slate-700">Step {index}</span>
            <div>
                <h2 class="text-xl font-bold text-white tracking-tight">{name}</h2>
                <p class="text-slate-400 text-xs font-light leading-relaxed">{description}</p>
            </div>
        </div>
        <div class="flex items-center gap-4 glass px-4 py-2 bg-white/[0.02]">
            <div class="text-right">
                <p class="text-lg font-black tracking-tight {status_class}">{status}</p>
            </div>
            <div class="w-10 h-10 rounded-xl flex items-center justify-center {status_bg} relative overflow-hidden">
                <div class="absolute inset-0 bg-current opacity-10 animate-pulse"></div>
                {status_icon}
            </div>
        </div>
    </div>

    <details class="group/details" {open_state}>
        <summary class="flex items-center gap-2 cursor-pointer list-none text-slate-500 hover:text-blue-400 transition-colors mb-2">
            <svg class="w-3 h-3 transition-transform group-open/details:rotate-90" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
            <span class="text-[10px] font-bold uppercase tracking-widest">Logs</span>
        </summary>
        <div class="space-y-4 pt-3 border-t border-white/5 relative z-10">
            <div>
                <div class="code-block p-3 rounded-lg border border-white/5 text-blue-300 group transition-all duration-300">
                    <code class="text-xs font-medium leading-relaxed">{command}</code>
                </div>
            </div>

            {output_section}
        </div>
    </details>
</section>
"""

OUTPUT_TEMPLATE = """
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 pt-4">
            <div class="space-y-3">
                <div class="flex items-center gap-2">
                    <div class="w-2 h-2 rounded-full bg-emerald-500"></div>
                    <h3 class="text-xs font-bold uppercase tracking-widest text-slate-500">Standard Output</h3>
                </div>
                <div class="code-block p-5 rounded-xl border border-white/5 h-[32rem] overflow-y-auto text-emerald-300 text-sm scrollbar-thin">
                    <pre class="leading-relaxed">{stdout}</pre>
                </div>
            </div>
            <div class="space-y-3">
                <div class="flex items-center gap-2">
                    <div class="w-2 h-2 rounded-full bg-rose-500"></div>
                    <h3 class="text-xs font-bold uppercase tracking-widest text-slate-500">Error / Stderr</h3>
                </div>
                <div class="code-block p-5 rounded-xl border border-white/5 h-[32rem] overflow-y-auto text-rose-300 text-sm scrollbar-thin">
                    <pre class="leading-relaxed">{stderr}</pre>
                </div>
            </div>
        </div>
"""

def run_command(command, update_func=None):
    print(f"\n📦 Executing: {command}")
    print("-" * 40)
    process = subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        universal_newlines=True
    )
    
    stdout_lines = []
    stderr_lines = []

    # Read stdout in real-time
    while True:
        line = process.stdout.readline()
        if not line and process.poll() is not None:
            break
        if line:
            print(line, end="")
            stdout_lines.append(line)
            # Update report every 5 lines of output to avoid too many writes
            if update_func and len(stdout_lines) % 5 == 0:
                update_func("".join(stdout_lines), "".join(stderr_lines))
            
    # Capture remaining stderr
    stderr_content = process.stderr.read()
    if stderr_content:
        print(f"\n❌ STDERR:\n{stderr_content}")
        stderr_lines.append(stderr_content)
        if update_func:
            update_func("".join(stdout_lines), "".join(stderr_lines))

    print("-" * 40)
    return process.returncode, "".join(stdout_lines), "".join(stderr_lines)

def generate_report(results, finished=False):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    steps_content = ""
    passed = 0
    failed = 0
    
    data_finished = "data-finished" if finished else ""
    
    for i, res in enumerate(results):
        status_colors = {
            "SUCCESS": ("status-success", "bg-emerald-500/20"),
            "FAILED": ("status-failure", "bg-rose-500/20"),
            "RUNNING": ("status-running text-blue-400", "bg-blue-500/20"),
            "PENDING": ("text-amber-400", "bg-amber-500/20"),
            "SKIPPED": ("status-skipped", "bg-slate-500/20")
        }
        status_class, status_bg = status_colors.get(res['status'], ("status-skipped", "bg-slate-500/20"))
        
        status_icon = ""
        if res['status'] == "SUCCESS":
            passed += 1
            status_icon = '<svg class="w-7 h-7 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"></path></svg>'
        elif res['status'] == "FAILED":
            failed += 1
            status_icon = '<svg class="w-7 h-7 text-rose-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12"></path></svg>'
        elif res['status'] == "RUNNING":
            status_icon = '<svg class="w-7 h-7 text-blue-500 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>'
        elif res['status'] == "PENDING":
            status_icon = '<svg class="w-7 h-7 text-amber-500 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
        else:
            status_icon = '<svg class="w-7 h-7 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"></path></svg>'

        output_section = ""
        if res['status'] not in ["SKIPPED", "PENDING", "RUNNING"]:
            output_section = OUTPUT_TEMPLATE.format(
                stdout=res['stdout'] if res['stdout'] else "(no output)",
                stderr=res['stderr'] if res['stderr'] else "(no error output)"
            )

        open_state = "open" if res['status'] == "RUNNING" else ""

        steps_content += STEP_TEMPLATE.format(
            index=i+1,
            id=res['id'],
            name=res['name'],
            description=res['description'],
            command=res['command'],
            status=res['status'],
            status_class=status_class,
            status_bg=status_bg,
            status_icon=status_icon,
            output_section=output_section,
            open_state=open_state
        )

    html = HTML_TEMPLATE.format(
        timestamp=timestamp,
        install_type=INSTALL_TYPE,
        total_steps=len(results),
        passed_steps=passed,
        failed_steps=failed,
        steps_content=steps_content,
        data_finished=data_finished
    )

    os.makedirs(os.path.dirname(REPORT_FILE), exist_ok=True)
    with open(REPORT_FILE, "w") as f:
        f.write(html)
    
    print(f"\n✨ Report updated: {REPORT_FILE}")

def main():
    parser = argparse.ArgumentParser(description="Interactive and Automated Test Runner for test_db")
    parser.add_argument("-a", "--auto", action="store_true", help="Run in automated mode (no prompts)")
    parser.add_argument("-i", "--interactive", action="store_true", help="Run in interactive mode (prompts for each step)")
    args = parser.parse_args()

    print("\n🚀 Test Runner Dashboard")
    print("========================")
    
    if args.auto:
        mode = 'a'
    elif args.interactive:
        mode = 'i'
    else:
        # Fallback to interactive prompt if no flag provided
        mode_input = input("Run mode ([a]uto / [i]nteractive - default: i)? ").lower().strip()
        mode = 'a' if mode_input == 'a' else 'i'
    
    print(f"Mode: {'Automated (no prompts)' if mode == 'a' else 'Interactive'}")
    
    results = []
    
    # Initial report generation with all steps as PENDING
    initial_results = [
        {**step, "status": "PENDING", "stdout": "", "stderr": ""}
        for step in STEPS
    ]
    generate_report(initial_results)

    for i, step in enumerate(STEPS):
        print(f"\n[{i+1}/{len(STEPS)}] Step: {step['name']}")
        print(f"Description: {step['description']}")
        
        should_run = True
        if mode == 'i':
            confirm = input(f"   Run this step? (Y/n) ").lower().strip()
            if confirm == 'n':
                should_run = False
        
        if should_run:
            # Mark current as RUNNING in report
            def on_update(curr_stdout, curr_stderr):
                curr_report = results + [{**step, "status": "RUNNING", "stdout": curr_stdout, "stderr": curr_stderr}] + [
                    {**s, "status": "PENDING", "stdout": "", "stderr": ""}
                    for s in STEPS[len(results)+1:]
                ]
                generate_report(curr_report)

            on_update("", "") # Initial running status
            returncode, stdout, stderr = run_command(step['command'], update_func=on_update)
            status = "SUCCESS" if returncode == 0 else "FAILED"
            results.append({
                **step,
                "status": status,
                "stdout": stdout,
                "stderr": stderr
            })
            # Update report after finishing
            current_report = results + [
                {**s, "status": "PENDING", "stdout": "", "stderr": ""}
                for s in STEPS[len(results):]
            ]
            generate_report(current_report)

            if status == "FAILED":
                print(f"❌ Step failed with return code {returncode}")
                if mode == 'i':
                    cont = input("   Continue to next step? (y/N) ").lower().strip()
                    if cont != 'y':
                        break
        else:
            results.append({
                **step,
                "status": "SKIPPED",
                "stdout": "",
                "stderr": ""
            })
            current_report = results + [
                {**s, "status": "PENDING", "stdout": "", "stderr": ""}
                for s in STEPS[len(results):]
            ]
            generate_report(current_report)
    
    # Final update after all tasks
    generate_report(results, finished=True)
    print(f"\n✅ All steps completed. Final report: {REPORT_FILE}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Runner interrupted by user.")
        sys.exit(0)
