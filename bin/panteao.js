#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const jarPath = path.join(__dirname, '../build/libs/jason-ipc-all.jar');

if (!fs.existsSync(jarPath)) {
    console.error(`Error: Jason engine JAR not found at ${jarPath}`);
    console.error(`Please compile the project first using: ./gradlew shadowJar`);
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

const args = [
    '-jar',
    jarPath,
    ...process.argv.slice(2)
];

const child = spawn('java', args, {
    stdio: 'inherit' // Inherits standard streams (stdin, stdout, stderr)
});

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
