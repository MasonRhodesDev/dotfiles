#!/usr/bin/env python3

from astral.sun import sun
from astral import LocationInfo
from datetime import datetime, timedelta
import pytz
import pysolar.solar as solar

# Define the sections and sub-sections of the day
DAY_SECTIONS = {
    'Night': {
        'Astronomical_Twilight': {},
        'Nautical_Twilight': {},
        'Civil_Twilight': {}
    },
    'Day': {
        'Morning': {
            'Dawn': {},
            'Early_Morning': {}
        },
        'Midday': {},
        'Afternoon': {},
        'Evening': {
            'Dusk': {},
            'Late_Evening': {}
        }
    }
}

def approximate_nautical_twilight(location, date, dawn=True):
    one_minute = timedelta(minutes=1)
    timezone = pytz.timezone(location.timezone)
    date = timezone.localize(date)
    current_time = date.replace(hour=0, minute=0) if dawn else date.replace(hour=23, minute=59)

    while True:
        altitude = solar.get_altitude(location.observer.latitude, location.observer.longitude, current_time)
        if (-12 <= altitude <= -6) == dawn:
            break
        current_time += one_minute if dawn else -one_minute

    return current_time

def get_sun_position(date, address):
    location = LocationInfo(address)
    observer = location.observer
    s = sun(observer, date=date)
    
    # print all keys from s
    print(s.keys())
    print(s.values())

    timezone = pytz.timezone(location.timezone)
    nautical_dawn = approximate_nautical_twilight(location, date, dawn=True)
    nautical_dusk = approximate_nautical_twilight(location, date, dawn=False)

    dawn = s['dawn'].astimezone(timezone)
    dusk = s['dusk'].astimezone(timezone)
    sunrise = s['sunrise'].astimezone(timezone)
    sunset = s['sunset'].astimezone(timezone)
    solar_noon = s['noon'].astimezone(timezone)
    solar_midnight = s['midnight'].astimezone(timezone)

    golden_hour_start = sunrise - timedelta(hours=1)
    golden_hour_end = sunrise + timedelta(hours=1)
    blue_hour_start = golden_hour_start - timedelta(minutes=30)
    blue_hour_end = golden_hour_end + timedelta(minutes=30)

    return {
        'Night': (solar_midnight, dawn),
        'Astronomical_Twilight': (nautical_dawn - timedelta(minutes=30), nautical_dusk + timedelta(minutes=30)),
        'Nautical_Twilight': (nautical_dawn, nautical_dusk),
        'Civil_Twilight': (dawn, dusk),
        'Dawn': (dawn, sunrise),
        'Golden_Hour_Morning': (golden_hour_start, golden_hour_end),
        'Blue_Hour_Morning': (blue_hour_start, blue_hour_end),
        'Midday': (solar_noon - timedelta(hours=2), solar_noon + timedelta(hours=2)),
        'Blue_Hour_Evening': (sunset - timedelta(minutes=30), sunset + timedelta(minutes=30)),
        'Golden_Hour_Evening': (sunset - timedelta(hours=1), sunset + timedelta(hours=1)),
        'Dusk': (sunset, dusk)
    }



def get_day_section(date, address):
    sun_positions = get_sun_position(date, address)

    for section, subsections in DAY_SECTIONS.items():
        for subsection, sub_subsections in subsections.items():
            if not sub_subsections:
                start, end = sun_positions[subsection]
                if start <= date <= end:
                    return section, subsection
            else:
                for sub_subsection in sub_subsections:
                    start, end = sun_positions[sub_subsection]
                    if start <= date <= end:
                        return section, subsection, sub_subsection
    return "Night", "Night"

if __name__ == "__main__":
    date = datetime.now()
    address = "San Francisco, CA"
    section = get_day_section(date, address)
    print(f"At {date}, the current section in {address} is: {section}")
