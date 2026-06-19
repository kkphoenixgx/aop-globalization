#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const nativePathLinux = path.join(__dirname, 'panteao-engine');
const nativePathWin = path.join(__dirname, 'panteao-engine.exe');
const nativePath = fs.existsSync(nativePathWin) ? nativePathWin : nativePathLinux;

const jarPath = path.join(__dirname, '../build/libs/jason-ipc-all.jar');

if (!fs.existsSync(nativePath) && !fs.existsSync(jarPath)) {
    console.error(`Error: Neither native engine executable nor JAR found.`);
    console.error(`Please compile the project first using: npm run build`);
    process.exit(1);
}

// Identify temp MAS2J file path to clean it up on exit
const jcmArg = process.argv.slice(2).find(arg => arg.endsWith('.jcm'));
let tempMas2jPath = null;
if (jcmArg) {
    const parsedPath = path.resolve(jcmArg);
    const dir = path.dirname(parsedPath);
    const ext = path.extname(parsedPath);
    const base = path.basename(parsedPath, ext);
    tempMas2jPath = path.join(dir, `.${base}.mas2j`);
}

function cleanup() {
    if (tempMas2jPath && fs.existsSync(tempMas2jPath)) {
        try {
            fs.unlinkSync(tempMas2jPath);
        } catch (e) {
            // ignore
        }
    }
}

let child;
if (fs.existsSync(nativePath)) {
    child = spawn(nativePath, process.argv.slice(2), {
        stdio: 'inherit'
    });
} else {
    const args = [
        '-jar',
        jarPath,
        ...process.argv.slice(2)
    ];
    child = spawn('java', args, {
        stdio: 'inherit'
    });
}

child.on('close', (code) => {
    cleanup();
    process.exit(code);
});

// Forward signals and cleanup
process.on('SIGINT', () => {
    cleanup();
    child.kill('SIGINT');
    process.exit(130);
});
process.on('SIGTERM', () => {
    cleanup();
    child.kill('SIGTERM');
    process.exit(143);
});
process.on('exit', cleanup);
