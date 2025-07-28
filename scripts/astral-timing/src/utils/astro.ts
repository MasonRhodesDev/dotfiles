import { Location } from 'astronomy-bundle/earth/types/LocationTypes.js';
import { createTimeOfInterest } from 'astronomy-bundle/time';
import { createSun } from 'astronomy-bundle/sun';
import { createMoon } from 'astronomy-bundle/moon';
import {
    STANDARD_ALTITUDE_SUN_CIVIL_TWILIGHT,
    STANDARD_ALTITUDE_SUN_NAUTICAL_TWILIGHT,
    STANDARD_ALTITUDE_SUN_ASTRONOMICAL_TWILIGHT,
} from 'astronomy-bundle/constants/standardAltitude'
import TimeOfInterest from 'astronomy-bundle/time/TimeOfInterest';
import { Time } from 'astronomy-bundle/time/types/TimeTypes';

interface SunPositions {
    sunriseStart: Date;
    sunriseEnd: Date;
    sunriseGoldenHourEnd: Date;
    solarNoon: Date;
    sunsetStart: Date;
    sunsetEnd: Date;
    sunsetGoldenHourEnd: Date;
    nadir: Date;
}

interface MoonPositions {
    moonRise: Date;
    moonTransit: Date;
    moonSet: Date;
}

interface DaySections {
    [key: string]: Date;
}

interface TimeOfDay {
    key: string,

    /** in epoch time */
    time: TimeOfInterest,
}

function sortTimeObj(direction: 1 | -1 = 1) {
    return (todA: TimeOfDay, todB: TimeOfDay): number => {
        const timeA = todA.time.getDate().getTime()
        const timeB = todB.time.getDate().getTime()

        if (timeA < timeB) {
            return -1 * direction;
        }
        if (timeA > timeB) {
            return 1 * direction;
        }
        return 0;
    }
}


class SortedAstroArray {

    private items: TimeOfDay[] = [];

    private sections: Map<string, string> = new Map();

    private _sortAscending = () => {
        this.items.sort(sortTimeObj());
    }

    private _addSections(key: string) {
        const parts = key.split('.');
        for (let i = 0; i < parts.length; i++) {
            let section = parts.slice(0, i + 1).join('.');
            if (!this.sections.has(section)) {
                const firstChild = this.items.find(x => x.key.startsWith(section));
                if (!firstChild) {
                    throw new Error('Internal error. Unable to build sections.')
                }
                this.sections.set(section, firstChild.key);
            }
        }
    }
    constructor(...items: TimeOfDay[]) {
        this.items = items;
        this._sortAscending();

        // rebuild the sections
        this.items.forEach((item, index) => {
            this._addSections(item.key);
        });
    }

    add(item: TimeOfDay) {
        this.items.push(item);
        this._sortAscending();
        this._addSections(item.key);
    }

    get(key: string) {
        return this.items.find(x => x.key.startsWith(key));
    }

    /**
     * Returns all keys that are a prefix of the given key
     * @param key the full or partial key to search for
     */
    getSiblings(key: string): TimeOfDay[] {
        let exactMatch = this.items.find(x => x.key === key);
        if (exactMatch) {
            let parent = key.split('.')
            parent.pop();
            if (!parent) {
                throw new Error('Internal error. Unable to get parent.');
            }
            return this.items.filter(
                x => x.key.startsWith(parent.join('.'))
            )
        } else {
            // get all sections of the same depth as the current key
            let parts = key.split('.')
            let depth = parts.length;
            let sections = Array.from(this.sections.keys()).filter(x => x.split('.').length === depth);

            let siblings = sections.map(x => this.items.find(y => y.key === this.sections.get(x))).filter(x => x !== undefined) as TimeOfDay[];
            siblings.sort(sortTimeObj());
            return siblings;
        }
    }

    getNextEvent(key: string): TimeOfDay | null {
        const item = this.get(key);
        if (!item) {
            return null;
        }
        let next: TimeOfDay | null = null;
        let target = key;
        while (!next) {
            let siblings = this.getSiblings(target)
            let nextItem = siblings.find(x => x.time.getDate().getTime() > item.time.getDate().getTime());
            if (!nextItem) {
                let parent = target.split('.')
                parent.pop();
                if (parent.length === 0) {
                    return null;
                }
                target = parent.join('.');
            } else {
                next = nextItem;
            }
        }
        return next;
    }

    // seconds
    getDuration(key: string) {
        const item = this.get(key);
        if (!item) {
            return 0;
        }
        let nextItem = this.getNextEvent(key);
        if (this.items.indexOf(item) === this.items.length - 1) {
            // is the last item
            return -1;
        } else if (!nextItem) {
            return 0;
        }
        return (nextItem.time.getDate().getTime() - item.time.getDate().getTime()) / 1000;
    }

    list() {
        return this.items;
    }
}

const DAY_SECTIONS: Record<string, Date | null> = {
    // occurs when the Sun is between 12 degrees and 18 degrees below the horizon.
    "Morning.Astronomical dawn": null,
    // occurs when the Sun is between 6 degrees and 12 degrees below the horizon.
    "Morning.Nautical dawn": null,
    // occurs when the Sun is between 0 degrees and 6 degrees below the horizon.
    "Morning.Civil dawn": null,

    // occurs at the instant that the sun is positioned due south of that specific geographic location
    "Midday.Solar noon": null,

    // is the moment when the center of the Sun is 6 degrees below the horizon in the evening.
    "Evening.Civil dusk": null,
    // is the moment when the center of the Sun is 12 degrees below the horizon in the evening.
    "Evening.Nautical dusk": null,
    // is the moment when the center of the Sun is 18 degrees below the horizon in the evening.
    "Evening.Astronomical dusk": null,

    // 12 hours after solar noon
    "Night.Midnight": null,
};

export async function getDaySections(location: Location): Promise<SortedAstroArray> {
    const now = new Date();
    const toi = createTimeOfInterest.fromTime(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const sun = createSun(toi);

    const toiTomorrow = createTimeOfInterest.fromTime(toi.time.year, toi.time.month, toi.time.day + 1, 0, 0, 0);
    const sunTomorrow = createSun(toiTomorrow);

    // type is method of sun name
    type SunGetter = 'getRise' | 'getSet' | 'getTransit';

    const astronomicalStart = await sun.getRise(location, STANDARD_ALTITUDE_SUN_ASTRONOMICAL_TWILIGHT)

    async function adjuster(method: SunGetter, location: Location, standardAltitude?: number | undefined) {
        const time = await sun[method](location, standardAltitude);
        if (time.getDate().getTime() >= astronomicalStart.getDate().getTime())
            return time;
        return sunTomorrow[method](location, standardAltitude);
    }


    const nauticalStart = await adjuster('getRise', location, STANDARD_ALTITUDE_SUN_NAUTICAL_TWILIGHT)
    const civilStart = await adjuster('getRise', location, STANDARD_ALTITUDE_SUN_CIVIL_TWILIGHT)
    const daylightStart = await adjuster('getRise', location, 0)
    const solarNoon = await adjuster('getTransit', location)

    const daylightEnd = await adjuster('getSet', location, 0)
    const civilEnd = await adjuster('getSet', location, STANDARD_ALTITUDE_SUN_CIVIL_TWILIGHT)
    const nauticalEnd = await adjuster('getSet', location, STANDARD_ALTITUDE_SUN_NAUTICAL_TWILIGHT)
    const astronomicalEnd = await adjuster('getSet', location, STANDARD_ALTITUDE_SUN_ASTRONOMICAL_TWILIGHT)

    const midnightTime = Object.assign({}, solarNoon.getTime())
    midnightTime.hour += 12
    if (midnightTime.hour >= 24) {
        midnightTime.hour -= 24
        midnightTime.day += 1
    }
    const midnight = createTimeOfInterest.fromTime(midnightTime.year, midnightTime.month, midnightTime.day, midnightTime.hour, midnightTime.min, midnightTime.sec)


    const results = new SortedAstroArray(
        {
            time: astronomicalStart,
            key: "Morning.Astronomical start",
        },
        {
            time: nauticalStart,
            key: "Morning.Nautical start",
        },
        {
            time: civilStart,
            key: "Morning.Civil start",
        },
        {
            time: daylightStart,
            key: "Midday.Daylight start",
        },
        {
            time: solarNoon,
            key: "Midday.Solar noon",
        },
        {
            time: daylightEnd,
            key: "Midday.Daylight end",
        },
        {
            time: civilEnd,
            key: "Evening.Civil end",
        },
        {
            time: nauticalEnd,
            key: "Evening.Nautical end",
        },
        {
            time: astronomicalEnd,
            key: "Evening.Astronomical end",
        },
        {
            time: midnight,
            key: "Night.Midnight",
        },
        // Night ends when Astronomical dawn starts
    );

    return results;
}
