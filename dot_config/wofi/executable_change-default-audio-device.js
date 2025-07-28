#!/bin/node
const { execSync } = require('child_process');
const { GetWPCTLStatus } = require('./audio-devices.js');

exports.UpdateDefaultAudioDevice = async function (options) {
    const raw = execSync(`wpctl set-default ${options.id}`);
    console.log(raw.toString());
    return true;
};

exports.WofiListAudioDevices = async function (options) {
    const wpctlStatus = await GetWPCTLStatus({
        filter: 'Audio.Sinks'
    });

    const defaultDevice = wpctlStatus.default;
    let devices = wpctlStatus.devices;

    if (options.showDefault === 'false') {
        devices = devices.filter(device => device.id !== defaultDevice);
    }
    
    let wofiOutput;
    try {
        wofiOutput = execSync('printf "' + devices.map(device => `${device.id === defaultDevice ? '* ':'  '}${device.id}. ${device.name}`).join('\n') + '" | wofi -d').toString();
    } catch (e) {
        console.error(e);
        return {
            id: defaultDevice,
            name: devices.find(device => device.id === defaultDevice).name
        };
    }
    const [devId, devName] = wofiOutput.split('. ');
    
    if (devId !== defaultDevice) {
        execSync(`wpctl set-default ${devId}`);
    }
    return {
        id: devId,
        name: devName
    };
};

if (require.main === module) {
    const MODULE = process.argv[2];
    console.log(MODULE);
    const FLAGS = process.argv.slice(2);
    let options = {};
    if (FLAGS.includes('--help')) {
        console.log(`
    Usage: audio-devices.js [module] [options]
    Modules:
      ${Object.keys(exports).join('\n      ')}
    Flags:
      --help: Display this help message
      -o, --options: Options for the module (e.g. audio-devices.js wofi-list-audio-devices -o '{"showDefault":"false"}')
    `);
        process.exit(0);
    }

    if (FLAGS.includes('-o') || FLAGS.includes('--options')) {
        const optionsIndex = FLAGS.indexOf('-o') !== -1 ? FLAGS.indexOf('-o') : FLAGS.indexOf('--options');
        options = JSON.parse(FLAGS[optionsIndex + 1]);
    }

    const module = exports[MODULE];
    module(options).then(d => console.log(JSON.stringify(d, null, 2)));
}