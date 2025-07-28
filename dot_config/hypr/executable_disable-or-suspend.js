#!/bin/env node
const { execSync } = require('child_process');

exports.DisableOrSuspend = function (options) {
    const raw = execSync('hyprctl monitors all -j');
    const monitors = JSON.parse(raw.toString());

    console.log (monitors.length)

    execSync(`dunstify "Lid is now ${options.state === 'on' ? 'closed':'open'}"`)

    if (monitors.length === 1) {
        if (options.state === "off") {
            console.log('Resuming the system');
            return execSync('hyprctl resume');
        } else{
            console.log('Suspending the system');
            return execSync('hyprctl suspend');
        }
    } else {
        if (options.state === "off") {
            console.log(`Enabling monitor ${options.id}`);
            console.debug(`hyprctl keyword monitor "${options.id},preferred,auto,auto"`);
            return execSync(`hyprctl keyword monitor "${options.id},preferred,auto,auto"`)
        } else {
            console.log(`Disabling monitor ${options.id}`);
            console.debug(`hyprctl keyword monitor "${options.id}, disable"`);
            return execSync(`hyprctl keyword monitor "${options.id}, disable"`)

        }
    }
}

if (require.main === module) {
    const MODULE = process.argv[2];
    console.log(MODULE);
    let FLAGS = process.argv.slice(2);
    if (FLAGS.includes('--help')) {
        console.log(`
    Usage: disable-or-suspend.js [options]
    Modules:
      ${Object.keys(exports).join('\n      ')}
    Flags:
      --help: Display this help message
      --state=<state>: State of the monitor
      --id=<id>: Id of the monitor
    `);
        process.exit(0);
    }

    let options = {};

    let lastFlag = '';
    for (let i = 0; i < FLAGS.length; i++) {
        if (FLAGS[i].startsWith('--')) {
            const [key, value] = FLAGS[i].split('=');
            if (!value) {
                lastFlag = key;
                continue;
            }

            if (lastFlag) {
                options[lastFlag.slice(2)] = key;
                lastFlag = '';
                continue;
            }
            options[key.slice(2)] = value;
        }
    }

    console.log(options);

    if (!options.state) {
        console.error('State is required');
        process.exit(1);
    }

    if (!options.id) {
        console.error('Id is required');
        process.exit(1);
    }

    exports.DisableOrSuspend(options);
    execSync("~/.config/hypr/configs/monitors.sh");
}