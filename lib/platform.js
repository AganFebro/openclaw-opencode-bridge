#!/usr/bin/env node
"use strict";

const os = require("os");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const chalk = require("chalk");

function detectOS() {
  const p = process.platform;
  if (p === "darwin") return "macOS";
  if (p === "linux") return "Linux";
  return p;
}

function getHomeDir() {
  return os.homedir();
}

function getWorkspace() {
  return path.join(getHomeDir(), ".openclaw", "workspace");
}

function getScriptsDir() {
  return path.join(getHomeDir(), ".openclaw", "scripts");
}

// --- Daemon install/remove ---

const PLIST_NAME = "ai.openclaw.opencode-session.plist";
const SYSTEMD_NAME = "openclaw-opencode-session.service";

function getPlistPath() {
  return path.join(getHomeDir(), "Library", "LaunchAgents", PLIST_NAME);
}

function getSystemdPath() {
  return path.join(getHomeDir(), ".config", "systemd", "user", SYSTEMD_NAME);
}

function installDaemon(scriptPath) {
  const platform = process.platform;

  if (platform === "darwin") {
    return installLaunchAgent(scriptPath);
  } else if (platform === "linux") {
    return installSystemdUnit(scriptPath);
  } else {
    console.log(
      chalk.yellow(`    ! Daemon auto-install not supported on ${platform}.`),
    );
    console.log(chalk.yellow(`      Run ${scriptPath} manually or via cron.`));
    return false;
  }
}

function substituteTemplate(content, vars) {
  let result = content;
  for (const [key, value] of Object.entries(vars)) {
    result = result.replace(new RegExp(`\\{\\{${key}\\}\\}`, "g"), value);
  }
  return result;
}

function installLaunchAgent(scriptPath) {
  const plistPath = getPlistPath();
  const dir = path.dirname(plistPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  const tplPath = path.join(
    __dirname,
    "..",
    "templates",
    "daemon",
    "macos.plist",
  );
  let content = fs.readFileSync(tplPath, "utf8");
  content = substituteTemplate(content, { SCRIPT_PATH: scriptPath });

  fs.writeFileSync(plistPath, content);

  // Unload if already loaded, then load
  try {
    execSync(`launchctl unload "${plistPath}" 2>/dev/null`, {
      stdio: "ignore",
    });
  } catch {}
  try {
    execSync(`launchctl load "${plistPath}"`);
    return true;
  } catch (e) {
    console.log(chalk.red(`    Failed to load LaunchAgent: ${e.message}`));
    return false;
  }
}

function installSystemdUnit(scriptPath) {
  const unitPath = getSystemdPath();
  const dir = path.dirname(unitPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

  const tplPath = path.join(
    __dirname,
    "..",
    "templates",
    "daemon",
    "linux.service",
  );
  let content = fs.readFileSync(tplPath, "utf8");
  content = substituteTemplate(content, { SCRIPT_PATH: scriptPath });

  fs.writeFileSync(unitPath, content);

  try {
    execSync("systemctl --user daemon-reload");
    execSync(`systemctl --user enable --now ${SYSTEMD_NAME}`);
    return true;
  } catch (e) {
    console.log(chalk.red(`    Failed to enable systemd unit: ${e.message}`));
    return false;
  }
}

const LEGACY_NAMES = {
  darwin: "ai.openclaw.claude-session.plist",
  linux: "openclaw-claude.service",
};

function removeDaemon() {
  const platform = process.platform;
  let removed = false;

  if (platform === "darwin") {
    const systemdDir = path.join(getHomeDir(), ".config", "systemd", "user");
    for (const name of [SYSTEMD_NAME, LEGACY_NAMES.darwin]) {
      const unitPath = path.join(systemdDir, name);
      if (fs.existsSync(unitPath)) {
        try {
          execSync(`systemctl --user disable --now ${name}`, {
            stdio: "ignore",
          });
        } catch {}
        fs.unlinkSync(unitPath);
        removed = true;
      }
    }
    const plistPath = getPlistPath();
    const legacyPlist = path.join(getHomeDir(), "Library", "LaunchAgents", LEGACY_NAMES.darwin);
    for (const p of [plistPath, legacyPlist]) {
      if (fs.existsSync(p)) {
        try {
          execSync(`launchctl unload "${p}" 2>/dev/null`, {
            stdio: "ignore",
          });
        } catch {}
        fs.unlinkSync(p);
        removed = true;
      }
    }
  } else if (platform === "linux") {
    const systemdDir = path.join(getHomeDir(), ".config", "systemd", "user");
    for (const name of [SYSTEMD_NAME, LEGACY_NAMES.linux]) {
      const unitPath = path.join(systemdDir, name);
      if (fs.existsSync(unitPath)) {
        try {
          execSync(`systemctl --user disable --now ${name}`, {
            stdio: "ignore",
          });
        } catch {}
        fs.unlinkSync(unitPath);
        removed = true;
      }
    }
    try {
      execSync("systemctl --user daemon-reload");
    } catch {}
  }
  return removed;
}

module.exports = {
  detectOS,
  getHomeDir,
  getWorkspace,
  getScriptsDir,
  installDaemon,
  removeDaemon,
  substituteTemplate,
};
