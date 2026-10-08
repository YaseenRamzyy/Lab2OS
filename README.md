# Lab2OS
# Lab 2: Simple Antivirus Daemon (CC373)

A small antivirus daemon written in Bash. It watches a directory, quarantines suspicious files,
and lets the user review quarantined files with a restore tool.

## 1. Overview

### Folder hierarchy

```
studentID-lab2/
├── antivirusd.sh          # Part 1: the daemon (polling loop + scan)
├── restore.sh             # Part 2: interactive restore/delete tool
├── Makefile               # Part 3: run targets + pre-build step
├── README.md              # this file
├── antivirus-cron.sh      # Bonus 1: single-pass version for cron
├── whitelist.txt          # Bonus 2: names of files marked safe
├── directory-info.last    # generated: last known snapshot of dir
├── directory-info.new     # generated: current snapshot of dir
├── testdir/               # the monitored directory (files only)
└── quarantine/            # malicious_dir (created automatically)
```

`directory-info.last` and `directory-info.new` are created by the scripts in the project folder, **not** inside the monitored directory, so 
saving them never counts as a change in `dir`.

### How the daemon works (`antivirusd.sh`)

```
antivirusd.sh dir malicious_dir interval-secs
```

1. On the first run there is no `directory-info.last`, so the daemon scans immediately and then saves `ls -l dir` as `directory-info.last`.
2. Every `interval-secs` seconds it saves a fresh `ls -l dir` as `directory-info.new` and compares it with `directory-info.last` using `diff`.
3. If nothing changed, it waits for the next interval without scanning.
4. If something changed, it scans `dir`, then copies `directory-info.new` over `directory-info.last`.
5. It runs forever until stopped with Ctrl+C.

A file is **malicious** if it matches at least one rule:

- its extension is in the flagged extension list, or
- its contents contain a flagged keyword (case-insensitive search).

For each malicious file the daemon prints `<file> is malicious and it is DELETED`, copies the file into `malicious_dir` under its original name, and deletes the original from `dir`.

### How the restore tool works (`restore.sh`)

```
restore.sh dir malicious_dir
```

- If `malicious_dir` is empty, it prints `No malicious files to review.` and exits.
- Otherwise it lists the quarantined files with numbers and asks the user to pick one. For the chosen file:
  - `1`: restore it to `dir` (prints `Restored <file> to <dir>.`) and add it to the whitelist
  - `2`: delete it permanently (prints `<file> permanently deleted.`)
  - `3`: leave it as is and return to the list

## 2. Location of the flagged lists

The extension and keyword lists are hardcoded near the top of the script, in the section marked `Flagged lists`:

|        File         | Lines |         Variable         |                  Contents                  |
|---------------------|-------|--------------------------|--------------------------------------------|
|    `antivirusd.sh`  |  16   |       `EXTENSIONS`       | `exe bat vbs scr ps1` |
|   `antivirusd.sh`   |  17   |       `KEYWORDS`         | `virus\|trojan\|malware\|worm\|ransomware` |
| `antivirus-cron.sh` | 19 & 20 | `EXTENSIONS`, `KEYWORDS` | same lists as above |

The matching logic lives in the `is_malicious` function: extensions are compared against the part of the filename after the last dot, and keywords are searched with `grep -aqiE` (`-i` makes it case-insensitive, `-a` lets it search inside binary files).

## 3. Prerequisites

Tested on Ubuntu. Everything below is preinstalled on a standard Ubuntu system except possibly `make`, `git` and `cron`.

| Tool | Used for |
|------|----------|
| `bash` | running the scripts |
| `coreutils` (`ls`, `cp`, `mv`, `rm`, `sleep`, `basename`) | file handling |
| `grep`, `diff` | content matching and change detection |
| `make` | running the Makefile targets |
| `git` | version control and submission |
| `cron` | Bonus 1 only |

Install on Ubuntu:

```bash
sudo apt update
sudo apt install make git cron
```

## 4. How to run

### Setup (once)

```bash
cd lab2OS
chmod +x antivirusd.sh restore.sh antivirus-cron.sh
mkdir -p testdir
```

### Run the antivirus daemon

Always run from the project folder.

```bash
make
```

This first creates `quarantine/` if it doesn't exist (pre-build step), then runs:

```bash
./antivirusd.sh testdir quarantine 5
```

To use different values, change `DIR`, `MAL_DIR` and `INTERVAL` at the top of the `Makefile`, or run the script directly. Stop it with Ctrl+C.

### Run the restore tool

In a **second terminal** (the daemon and the restore tool must not run at the same time, so stop the daemon first):

```bash
make restore
```

### Quick test

```bash
echo "hello" > testdir/clean.txt
echo "I am a ViRuS" > testdir/bad.txt
touch testdir/run.exe
make
```

Expected: `bad.txt` and `run.exe` are reported as malicious and moved to `quarantine/`; `clean.txt` stays in `testdir/`.

To test the first-run behavior again, delete `directory-info.last` before starting.

## 5. Bonus 1: Cron job

`antivirus-cron.sh` performs the same scan and quarantine as the daemon but makes a **single pass** and exits. Cron repeats it. There is no interactive restore loop. It stores its state files (`directory-info.*`, `whitelist.txt`) next to the script, so it works regardless of the directory cron runs it from.

### Prerequisites

- `cron` installed and running
- `antivirus-cron.sh` executable
- the monitored directory already exists
- write access to the project folder (for `directory-info.*`, `whitelist.txt`, `cron.log`)

```bash
sudo apt install cron
sudo systemctl enable --now cron
sudo systemctl status cron
```

### Step-by-step setup

1. Make the script executable and test it by hand with absolute paths:
   ```bash
   chmod +x antivirus-cron.sh
   ./antivirus-cron.sh "$PWD/testdir" "$PWD/quarantine"
   ```
2. Find your project's absolute path with `pwd`.
3. Open the crontab: `crontab -e`.
4. Add this line, replacing `/home/os/lab2OS` with your real path:
   ```
   * * * * * sleep 23; /home/os/lab2OS/antivirus-cron.sh /home/os/lab2OS/testdir /home/os/lab2OS/quarantine >> /home/os/lab2OS/cron.log 2>&1
   ```
5. Save and exit, then verify with `crontab -l`.
6. Watch the output: `tail -f cron.log`.
7. To stop it, run `crontab -e` and delete the line.

If you see the message `No MTA installed, discarding output`, it is harmless. Cron is only saying it has no mail system to send job output to. Add `MAILTO=""` as the first line of the crontab to silence it.

### Running at second 23 of every minute

Cron has only minute granularity, so the job is scheduled every minute (`* * * * *`) and the command begins with `sleep 23`. Cron starts the job at second 0, and the script actually runs at second 23.

### Every 3rd Friday of the month at 12:31 AM

```
31 0 15-21 * * [ "$(date +\%u)" -eq 5 ] && /home/os/lab2OS/antivirus-cron.sh /home/os/lab2OS/testdir /home/os/lab2OS/quarantine
```

Explanation:

- `31 0` means 12:31 AM.
- The 3rd Friday of any month always falls between day 15 and day 21, so the day-of-month field is `15-21`.
- In cron, if both day-of-month and day-of-week are restricted, the job runs when **either** matches (OR). Writing `31 0 15-21 * 5` would therefore run on days 15-21 **and** every Friday. To get the intended AND, the day-of-week field stays `*` and the command checks the weekday itself: `date +%u` returns 5 on Friday.
- `%` must be written as `\%` inside a crontab, otherwise cron treats it as a newline.

## 6. Bonus 2: Whitelist

Restored files are remembered as safe so they are not quarantined again, even if they still match a rule.

- **Storage:** `whitelist.txt` in the project folder, one filename per line. Because it is a file, it persists across daemon restarts.
- **How a file gets added:** in `restore.sh`, choosing option `1` (restore) moves the file back into `dir` and appends its filename to `whitelist.txt`, unless it is already listed (`grep -qxF "$file" whitelist.txt || echo "$file" >> whitelist.txt`).
- **How the daemon checks it:** during each scan, `antivirusd.sh` (and `antivirus-cron.sh`) runs `grep -qxF "$name" whitelist.txt` for every file in `dir` before applying the malicious rules. `-x` matches the whole line and `-F` matches plain text. If the name is listed, the file is skipped and left untouched.
- **Removing a file from the whitelist:** delete its line from `whitelist.txt`.
