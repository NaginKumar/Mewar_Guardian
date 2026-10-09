# =========================================================
# RESPONDER  –  distance calculation, nearest responder, ETA
# =========================================================

import math
from config.locations import responders


# -------------------------
# HAVERSINE DISTANCE
# -------------------------

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return great-circle distance in kilometres between two GPS points."""
    R = 6371  # Earth radius km

    lat1 = math.radians(lat1)
    lat2 = math.radians(lat2)

    dlat = lat2 - lat1
    dlon = math.radians(lon2 - lon1)

    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )

    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


# -------------------------
# NEAREST RESPONDER
# -------------------------

def find_nearest_responder(lat: float, lon: float) -> tuple[str, float]:
    """Return (responder_name, distance_km) for the closest response team."""
    nearest_responder = None
    minimum_distance = float("inf")

    for name, data in responders.items():
        distance = calculate_distance(lat, lon, data["lat"], data["lon"])
        if distance < minimum_distance:
            minimum_distance = distance
            nearest_responder = name

    return nearest_responder, minimum_distance


# -------------------------
# ESTIMATED RESPONSE TIME
# -------------------------

def estimate_response_minutes(distance_km: float, priority: str) -> int:
    """
    Demo ETA: dispatch preparation delay + campus travel estimate.

    Assumes approx. 18 km/h for an on-campus response vehicle.
    Capped at 20 minutes.
    """
    dispatch_buffer = {
        "CRITICAL": 2,
        "HIGH":     3,
        "MEDIUM":   4,
        "LOW":      5
    }.get(priority, 4)

    travel_minutes = max(1, math.ceil((distance_km / 18) * 60))
    return min(20, dispatch_buffer + travel_minutes)
