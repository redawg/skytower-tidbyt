"""
Applet: SkyTower
Summary: Live flight dashboard
Description: Displays nearby aircraft from OpenSky Network ADS-B data. Rotates tower, radar, and route views.
Author: andre
"""

load("render.star", "render")
load("time.star", "time")
load("encoding/json.star", "json")
load("http.star", "http")
load("math.star", "math")
load("schema.star", "schema")

COLOR_BG = "#0a1628"
COLOR_AMBER = "#fca311"
COLOR_TEXT = "#fcf7c5"
COLOR_DIM = "#8a7f6b"
COLOR_GREEN = "#7cb342"

OPENSKY_STATES_URL = "https://opensky-network.org/api/states/all"
OPENSKY_TOKEN_URL = "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token"
OPENSKY_METADATA_URL = "https://opensky-network.org/api/metadata/aircraft/icao/"
OPENSKY_FLIGHTS_URL = "https://opensky-network.org/api/flights/aircraft"

CATEGORY_LABEL = {
    2: "Light",
    3: "Small",
    4: "Large",
    5: "HVort",
    6: "Heavy",
    7: "Perf",
    8: "Rotor",
    9: "Glider",
}

def screen(children):
    return render.Root(
        child = render.Stack(
            children = [
                render.Box(
                    child = render.Column(children = children),
                    width = 64,
                    height = 32,
                    color = COLOR_BG,
                ),
            ],
        ),
    )

def message(title, subtitle):
    return screen([
        render.Text(content = title, font = "5x8", color = COLOR_AMBER),
        render.Text(content = subtitle, font = "5x8", color = COLOR_DIM),
    ])

def fmt_int(v):
    if v == None:
        return "--"
    return str(v)

def fmt_vr(v):
    if v == None:
        return "--"
    if v > 0:
        return "+" + str(v)
    return str(v)

def metrics_line(plane, show_alt, show_spd, show_trk, show_vr):
    parts = []
    if show_alt:
        parts.append("Alt" + fmt_int(plane["alt_ft"]))
    if show_spd:
        parts.append("Spd" + fmt_int(plane["spd_mph"]))
    if show_trk:
        parts.append("Trk" + fmt_int(plane["trk"]))
    if show_vr:
        parts.append("Vr" + fmt_vr(plane["vr_fpm"]))
    if len(parts) == 0:
        return str(plane["dist_mi"]) + "mi " + plane["compass"]

    s = ""
    for part in parts:
        if s == "":
            s = part
        else:
            s = s + " " + part
    return s

def tower_screen(planes, total, max_rows):
    rows = [
        render.Row(
            children = [
                render.Text(content = "TOWER", font = "5x8", color = COLOR_AMBER),
                render.Text(content = str(total), font = "5x8", color = COLOR_GREEN),
            ],
        ),
    ]

    shown = planes[0:max_rows]
    for plane in shown:
        typ = plane["type"]
        if typ == "":
            typ = plane["category"]
        if typ == "":
            typ = "--"
        line = plane["callsign"] + " " + typ
        if len(line) > 14:
            line = plane["callsign"]
        rows.append(
            render.Text(
                content = line + " " + str(plane["dist_mi"]) + "mi",
                font = "5x8",
                color = COLOR_TEXT,
            ),
        )

    if len(shown) == 0:
        rows.append(render.Text(content = "Scanning airspace", font = "5x8", color = COLOR_DIM))

    return screen(rows)

def radar_screen(plane, show_alt, show_spd, show_trk, show_vr):
    typ = plane["type"]
    if typ == "":
        typ = plane["category"]
    if typ == "":
        typ = "--"

    return screen([
        render.Row(
            children = [
                render.Text(content = "RADAR", font = "5x8", color = COLOR_AMBER),
                render.Text(content = plane["callsign"], font = "5x8", color = COLOR_TEXT),
            ],
        ),
        render.Text(
            content = typ + " " + str(plane["dist_mi"]) + "mi " + plane["compass"],
            font = "5x8",
            color = COLOR_DIM,
        ),
        render.Marquee(
            child = render.Text(
                content = metrics_line(plane, show_alt, show_spd, show_trk, show_vr),
                font = "5x8",
                color = COLOR_GREEN,
            ),
            scroll_direction = "horizontal",
            width = 64,
            offset_start = 64,
            offset_end = 64,
        ),
    ])

def route_screen(plane):
    route = plane["route"]
    if route == "":
        route = plane["country"]

    return screen([
        render.Row(
            children = [
                render.Text(content = "ROUTE", font = "5x8", color = COLOR_AMBER),
                render.Text(content = plane["callsign"], font = "5x8", color = COLOR_TEXT),
            ],
        ),
        render.Marquee(
            child = render.Text(content = route, font = "5x8", color = COLOR_GREEN),
            scroll_direction = "horizontal",
            width = 64,
            offset_start = 64,
            offset_end = 64,
        ),
        render.Text(
            content = str(plane["dist_mi"]) + "mi " + plane["compass"] + " " + fmt_int(plane["alt_ft"]) + "ft",
            font = "5x8",
            color = COLOR_DIM,
        ),
    ])

def dashboard_rotate(planes, total, max_rows, show_alt, show_spd, show_trk, show_vr):
    if len(planes) == 0:
        return tower_screen(planes, total, max_rows)

    slot = (time.now().unix // 10) % 3
    hero = planes[0]

    if slot == 0:
        return tower_screen(planes, total, max_rows)
    if slot == 1:
        return radar_screen(hero, show_alt, show_spd, show_trk, show_vr)
    return route_screen(hero)

def get_bounding_box(lat, lng, radius_mi):
    R = 6371
    radius_km = radius_mi * 1.609
    x1 = lng - math.degrees(radius_km / R / math.cos(math.radians(lat)))
    x2 = lng + math.degrees(radius_km / R / math.cos(math.radians(lat)))
    y1 = lat + math.degrees(radius_km / R)
    y2 = lat - math.degrees(radius_km / R)
    return {
        "lamin": y2,
        "lomin": x1,
        "lamax": y1,
        "lomax": x2,
    }

def haversine_mi(lat1, lng1, lat2, lng2):
    R = 3958.8
    lat1r = math.radians(lat1)
    lat2r = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.pow(math.sin(dlat / 2), 2) + math.cos(lat1r) * math.cos(lat2r) * math.pow(math.sin(dlng / 2), 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return math.round(R * c * 10) / 10

def bearing(lat1, lng1, lat2, lng2):
    dlon = math.radians(lng2 - lng1)
    lat1r = math.radians(lat1)
    lat2r = math.radians(lat2)
    x = math.cos(lat2r) * math.sin(dlon)
    y = math.cos(lat1r) * math.sin(lat2r) - math.sin(lat1r) * math.cos(lat2r) * math.cos(dlon)
    deg = (math.degrees(math.atan2(x, y)) + 360) % 360
    return int(deg)

def compass(deg):
    if deg < 11:
        return "N"
    if deg < 34:
        return "NNE"
    if deg < 56:
        return "NE"
    if deg < 79:
        return "ENE"
    if deg < 101:
        return "E"
    if deg < 124:
        return "ESE"
    if deg < 146:
        return "SE"
    if deg < 169:
        return "SSE"
    if deg < 191:
        return "S"
    if deg < 214:
        return "SSW"
    if deg < 236:
        return "SW"
    if deg < 259:
        return "WSW"
    if deg < 281:
        return "W"
    if deg < 304:
        return "WNW"
    if deg < 326:
        return "NW"
    if deg < 349:
        return "NNW"
    return "N"

def get_token(client_id, client_secret):
    if client_id == "" or client_secret == "":
        return ""

    body = "grant_type=client_credentials&client_id=" + client_id + "&client_secret=" + client_secret
    resp = http.post(
        url = OPENSKY_TOKEN_URL,
        headers = {"Content-Type": "application/x-www-form-urlencoded"},
        body = body,
        ttl_seconds = 3500,
    )
    if resp.status_code != 200:
        return ""

    data = resp.json()
    return data.get("access_token", "")

def _headers(token):
    if token == "":
        return {}
    return {"Authorization": "Bearer " + token}

def parse_state(item, home_lat, home_lng):
    callsign = item[1]
    if callsign == None:
        callsign = ""
    callsign = callsign.strip()
    if callsign == "" or item[8]:
        return None

    lat = item[6]
    lng = item[5]
    if lat == None or lng == None:
        return None

    alt_m = item[13]
    if alt_m == None:
        alt_m = item[7]
    alt_ft = None if alt_m == None else int(alt_m * 3.28084)

    spd = None if item[9] == None else int(item[9] * 2.23694)
    trk = None if item[10] == None else int(item[10])
    vr = None if item[11] == None else int(item[11] * 196.85)

    category = item[17] if len(item) > 17 else None
    cat_label = CATEGORY_LABEL.get(category, "")

    return {
        "icao24": item[0],
        "callsign": callsign,
        "country": item[2],
        "lat": lat,
        "lng": lng,
        "dist_mi": haversine_mi(home_lat, home_lng, lat, lng),
        "bearing": bearing(home_lat, home_lng, lat, lng),
        "compass": compass(bearing(home_lat, home_lng, lat, lng)),
        "alt_ft": alt_ft,
        "spd_mph": spd,
        "trk": trk,
        "vr_fpm": vr,
        "category": cat_label,
        "type": "",
        "route": "",
    }

def fetch_nearby(home_lat, home_lng, radius_mi, token):
    bbox = get_bounding_box(home_lat, home_lng, radius_mi)
    params = {
        "lamin": str(math.round(bbox["lamin"] / 0.001) * 0.001),
        "lomin": str(math.round(bbox["lomin"] / 0.001) * 0.001),
        "lamax": str(math.round(bbox["lamax"] / 0.001) * 0.001),
        "lomax": str(math.round(bbox["lomax"] / 0.001) * 0.001),
    }

    resp = http.get(
        url = OPENSKY_STATES_URL,
        headers = _headers(token),
        params = params,
        ttl_seconds = 10,
    )
    if resp.status_code != 200:
        return None, resp.status_code

    data = resp.json()
    states = data.get("states") or []
    planes = []
    for item in states:
        plane = parse_state(item, home_lat, home_lng)
        if plane:
            planes.append(plane)

    planes = sorted(planes, key = lambda p: p["dist_mi"])
    return planes, 200

def fetch_type(icao24, token):
    resp = http.get(
        url = OPENSKY_METADATA_URL + icao24,
        headers = _headers(token),
        ttl_seconds = 86400,
    )
    if resp.status_code != 200:
        return ""

    data = resp.json()
    model = data.get("model", "")
    if model != "":
        return model
    return data.get("typecode", "")

def enrich_types(planes, token, max_lookup):
    count = 0
    for plane in planes:
        if count < max_lookup and plane["type"] == "":
            t = fetch_type(plane["icao24"], token)
            if t != "":
                plane["type"] = t
            count = count + 1
    return planes

def fetch_route(icao24, token):
    now = time.now().unix
    params = {
        "icao24": icao24,
        "begin": str(now - 43200),
        "end": str(now),
    }
    resp = http.get(
        url = OPENSKY_FLIGHTS_URL,
        headers = _headers(token),
        params = params,
        ttl_seconds = 300,
    )
    if resp.status_code != 200:
        return ""

    flights = resp.json()
    if len(flights) == 0:
        return ""

    latest = flights[len(flights) - 1]
    dep = latest.get("estDepartureAirport") or ""
    arr = latest.get("estArrivalAirport") or ""
    if dep == "" and arr == "":
        return ""
    if dep == "":
        return arr
    if arr == "":
        return dep
    return dep + ">" + arr

def enrich_routes(planes, token, max_lookup):
    count = 0
    for plane in planes:
        if count < max_lookup and plane["route"] == "":
            route = fetch_route(plane["icao24"], token)
            if route != "":
                plane["route"] = route
            count = count + 1
    return planes

def filter_min_alt(planes, min_alt_ft):
    out = []
    for plane in planes:
        alt = plane["alt_ft"]
        if alt == None or alt >= min_alt_ft:
            out.append(plane)
    return out

def find_by_callsign(planes, callsign):
    target = callsign.strip().upper()
    for plane in planes:
        if plane["callsign"].upper() == target:
            return plane
    return None

display = struct(
    message = message,
    tower_screen = tower_screen,
    radar_screen = radar_screen,
    route_screen = route_screen,
    dashboard_rotate = dashboard_rotate,
)

opensky = struct(
    get_token = get_token,
    fetch_nearby = fetch_nearby,
    filter_min_alt = filter_min_alt,
    enrich_types = enrich_types,
    enrich_routes = enrich_routes,
    find_by_callsign = find_by_callsign,
)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "lat",
                name = "Latitude",
                desc = "Your location latitude",
                icon = "locationDot",
            ),
            schema.Text(
                id = "lng",
                name = "Longitude",
                desc = "Your location longitude",
                icon = "locationDot",
            ),
            schema.Text(
                id = "radius",
                name = "Radius (mi)",
                desc = "Search radius in miles",
                icon = "ruler",
                default = "20",
            ),
            schema.Text(
                id = "mode",
                name = "Mode",
                desc = "dashboard, tower, radar, route, or track",
                icon = "tableList",
                default = "dashboard",
            ),
            schema.Text(
                id = "track_callsign",
                name = "Track callsign",
                desc = "Optional callsign for track mode (e.g. UAL1151)",
                icon = "plane",
            ),
            schema.Text(
                id = "max_planes",
                name = "Tower rows",
                desc = "Rows shown on tower screen (1-3)",
                icon = "list",
                default = "3",
            ),
            schema.Text(
                id = "min_altitude",
                name = "Min altitude (ft)",
                desc = "Ignore aircraft below this altitude",
                icon = "arrowUp",
                default = "500",
            ),
            schema.Text(
                id = "client_id",
                name = "OpenSky client ID",
                desc = "Free at opensky-network.org/account/request",
                icon = "person",
            ),
            schema.Text(
                id = "client_secret",
                name = "OpenSky client secret",
                desc = "Required for reliable API access",
                icon = "lock",
            ),
            schema.Toggle(id = "show_alt", name = "Show Alt", desc = "Show altitude on radar", icon = "arrowUp", default = True),
            schema.Toggle(id = "show_spd", name = "Show Spd", desc = "Show speed on radar", icon = "gauge", default = True),
            schema.Toggle(id = "show_trk", name = "Show Trk", desc = "Show track on radar", icon = "compass", default = True),
            schema.Toggle(id = "show_vr", name = "Show Vr", desc = "Show vertical rate on radar", icon = "arrowTrendUp", default = True),
        ],
    )

def main(config):
    lat_raw = config.get("lat")
    lng_raw = config.get("lng")
    if lat_raw == None or lng_raw == None or lat_raw == "" or lng_raw == "":
        return display.message("SkyTower", "Set lat & lng")

    lat = float(lat_raw)
    lng = float(lng_raw)
    radius = int(config.get("radius") or "20")
    if radius < 1:
        radius = 1
    if radius > 150:
        radius = 150

    mode = (config.get("mode") or "dashboard").lower()
    track_callsign = (config.get("track_callsign") or "").strip()
    max_planes = int(config.get("max_planes") or "3")
    if max_planes < 1:
        max_planes = 1
    if max_planes > 3:
        max_planes = 3

    min_alt = int(config.get("min_altitude") or "500")
    show_alt = config.get("show_alt", True)
    show_spd = config.get("show_spd", True)
    show_trk = config.get("show_trk", True)
    show_vr = config.get("show_vr", True)

    client_id = str(config.get("client_id") or "")
    client_secret = str(config.get("client_secret") or "")
    token = opensky.get_token(client_id, client_secret)

    planes, status = opensky.fetch_nearby(lat, lng, radius, token)
    if planes == None:
        return display.message("HTTP " + str(status), "OpenSky error")

    total = len(planes)
    planes = opensky.filter_min_alt(planes, min_alt)

    if len(planes) == 0:
        return display.message("Clear skies", str(radius) + "mi radius")

    planes = opensky.enrich_types(planes, token, 3)
    planes = opensky.enrich_routes(planes, token, 2)

    if mode == "track" and track_callsign != "":
        tracked = opensky.find_by_callsign(planes, track_callsign)
        if tracked == None:
            return display.message("Not in range", track_callsign)
        return display.radar_screen(tracked, show_alt, show_spd, show_trk, show_vr)

    if mode == "tower":
        return display.tower_screen(planes, total, max_planes)
    if mode == "radar":
        return display.radar_screen(planes[0], show_alt, show_spd, show_trk, show_vr)
    if mode == "route":
        return display.route_screen(planes[0])
    if mode == "dashboard":
        return display.dashboard_rotate(planes, total, max_planes, show_alt, show_spd, show_trk, show_vr)

    return display.dashboard_rotate(planes, total, max_planes, show_alt, show_spd, show_trk, show_vr)
