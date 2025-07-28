const { execSync } = require('child_process');

const SUB_SECTION_REGEX = /^ [├└]─ (.*):$/;
const DEVICE_REGEX = /^[ │]+(\d+)\. (.*) \[(.*)]$/;
const SELECTED_DEVICE_REGEX = /^[ │]+\* +(\d+)\. (.*) \[(.*)]$/;

exports.GetWPCTLStatus = async function GetWPCTLStatus(options) {
    const wpctlStatusRaw = execSync('wpctl status').toString();
    const CONFIG = {};
    let currentSection = null;
    let currentSubSection = null;
    for (const line of wpctlStatusRaw.split('\n')) {
        if (line.length === 0) continue;

        if (!line.startsWith(' ')) {
            // console.log(`Header: ${line}`);
            let splitLine = line.split(' ');
            currentSection = splitLine[0];
            CONFIG[currentSection] = {
                info: splitLine.slice(1).join(' '),
                subsections: {}
            };
            continue;
        }

        const isSubSection = line.match(SUB_SECTION_REGEX);
        if (isSubSection) {
            // console.log(`Subsection: ${isSubSection[1]}`);
            currentSubSection = isSubSection[1];
            CONFIG[currentSection].subsections[currentSubSection] = {
                devices: [],
                default: null
            };
            continue;
        }

        const isSelectedDevice = line.match(SELECTED_DEVICE_REGEX);
        if (isSelectedDevice) {
            // console.log(`Selected Device: ${isSelectedDevice[2]}`);
            CONFIG[currentSection].subsections[currentSubSection].devices.push({
                id: isSelectedDevice[1],
                name: isSelectedDevice[2].trim(),
                status: isSelectedDevice[3]
            });
            CONFIG[currentSection].subsections[currentSubSection].default = isSelectedDevice[1];
            continue;
        }

        const isDevice = line.match(DEVICE_REGEX);
        if (isDevice) {
            // console.log(`Device: ${isDevice[2]}`);
            CONFIG[currentSection].subsections[currentSubSection].devices.push({
                id: isDevice[1],
                name: isDevice[2].trim(),
                status: isDevice[3]
            });
            continue;
        }
    }

    let output = CONFIG;

    if (options.filter) {
        const path = options.filter.split('.');
        let skippedProperties = [null, 'subsections'];
        for (let i = 0; i < path.length; i++) {
            if (skippedProperties[i]) {
                output = output[skippedProperties[i]];
            }
            output = output[path[i]];
        }
    }
    return output;
}

// Check if the script is being run directly or being imported
if (require.main === module) {
    const FLAGS = process.argv.slice(2);

    if (FLAGS.includes('--help')) {
        console.log(`
    Usage: audio-devices.js
    FLAGS:
        --help, -h: Display this help message
        --filter, -f: Filter the output to only show the selected section and subsection  (e.g. audio-devices.js --filter audio.output)
    `);
        process.exit(0);
    }

    let filter = null;
    if (FLAGS.includes('--filter') || FLAGS.includes('-f')) {
        const filterIndex = FLAGS.indexOf('--filter') !== -1 ? FLAGS.indexOf('--filter') : FLAGS.indexOf('-f');
        filter = FLAGS[filterIndex + 1];
    }
    exports.GetWPCTLStatus({ filter }).then(d => console.log(JSON.stringify(d, null, 2)));
}