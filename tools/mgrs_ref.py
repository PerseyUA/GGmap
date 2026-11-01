"""Independent reference: MGRS -> WGS84 (lat, lon), cell centre.

Used only to generate test vectors for the Dart implementation.
UTM inverse uses Krueger series (Karney 2011), WGS84 ellipsoid.
"""
import math
import sys

A = 6378137.0
F = 1 / 298.257223563
K0 = 0.9996

n = F / (2 - F)
A_ = A / (1 + n) * (1 + n**2 / 4 + n**4 / 64)
beta = [
    n / 2 - 2 * n**2 / 3 + 37 * n**3 / 96,
    n**2 / 48 + n**3 / 15,
    17 * n**3 / 480,
]
delta = [
    2 * n - 2 * n**2 / 3 - 2 * n**3,
    7 * n**2 / 3 - 8 * n**3 / 5,
    56 * n**3 / 15,
]

BANDS = "CDEFGHJKLMNPQRSTUVWX"
COLS = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
ROWS = "ABCDEFGHJKLMNPQRSTUV"


def utm_to_ll(zone, north, e, nn):
    x = e - 500000
    y = nn if north else nn - 10000000
    xi = y / (K0 * A_)
    eta = x / (K0 * A_)
    xi_ = xi - sum(b * math.sin(2 * (j + 1) * xi) * math.cosh(2 * (j + 1) * eta) for j, b in enumerate(beta))
    eta_ = eta - sum(b * math.cos(2 * (j + 1) * xi) * math.sinh(2 * (j + 1) * eta) for j, b in enumerate(beta))
    chi = math.asin(math.sin(xi_) / math.cosh(eta_))
    phi = chi + sum(d * math.sin(2 * (j + 1) * chi) for j, d in enumerate(delta))
    lon0 = math.radians((zone - 1) * 6 - 180 + 3)
    lam = lon0 + math.atan2(math.sinh(eta_), math.cos(xi_))
    return math.degrees(phi), math.degrees(lam)


def ll_to_northing(lat, zone):
    # forward UTM northing at central meridian (x=0): meridian arc
    alpha = [
        n / 2 - 2 * n**2 / 3 + 5 * n**3 / 16,
        13 * n**2 / 48 - 3 * n**3 / 5,
        61 * n**3 / 240,
    ]
    e = math.sqrt(F * (2 - F))
    phi = math.radians(lat)
    t = math.sinh(math.atanh(math.sin(phi)) - e * math.atanh(e * math.sin(phi)))
    xi_ = math.atan(t)
    xi = xi_ + sum(a * math.sin(2 * (j + 1) * xi_) for j, a in enumerate(alpha))
    y = K0 * A_ * xi
    return y if lat >= 0 else y + 10000000


def mgrs_centre(s):
    s = s.replace(" ", "").upper()
    i = 2 if s[1].isdigit() else 1
    zone = int(s[:i])
    band = s[i]
    col, row = s[i + 1], s[i + 2]
    digits = s[i + 3:]
    h = len(digits) // 2
    cell = 10 ** (5 - h)
    e_in = int(digits[:h]) * cell + cell / 2
    n_in = int(digits[h:]) * cell + cell / 2

    setn = (zone - 1) % 3
    e100 = (COLS[setn].index(col) + 1) * 100000
    roff = 0 if zone % 2 == 1 else 5
    n100 = ((ROWS.index(row) - roff) % 20) * 100000

    band_lat = -80 + BANDS.index(band) * 8
    band_min_n = ll_to_northing(band_lat, zone) - (0 if band_lat >= 0 else 0)
    north = band_lat >= 0
    if not north:
        band_min_n = ll_to_northing(band_lat, zone)
    nn = n100 + n_in
    base = band_min_n % 2000000
    k = math.floor(band_min_n / 2000000)
    while k * 2000000 + nn < band_min_n - 100000:
        k += 1
    northing = k * 2000000 + nn
    lat, lon = utm_to_ll(zone, north, e100 + e_in, northing)
    return lat, lon


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        lat, lon = mgrs_centre(arg)
        print(f"{arg}\t{lat:.7f}\t{lon:.7f}")
