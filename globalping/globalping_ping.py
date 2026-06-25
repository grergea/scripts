#!/usr/bin/env python3
"""Globalping ping test - runs ping from a specified country (default: RU)."""

import argparse
import sys
import time

import requests

BASE_URL = "https://api.globalping.io"


def create_measurement(target: str, country: str, probes: int, token: str = None, city: str = None) -> str:
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    location = {"country": country}
    if city:
        location["city"] = city
    resp = requests.post(
        f"{BASE_URL}/v1/measurements",
        headers=headers,
        json={
            "type": "ping",
            "target": target,
            "limit": probes,
            "locations": [location],
            "measurementOptions": {"packets": 5},
        },
        timeout=10,
    )
    if resp.status_code in (422, 429):
        print(f"Error {resp.status_code}: {resp.json().get('error', {}).get('message', resp.text)}")
        sys.exit(1)
    resp.raise_for_status()
    return resp.json()["id"]


def wait_for_result(measurement_id: str) -> dict:
    while True:
        resp = requests.get(f"{BASE_URL}/v1/measurements/{measurement_id}", timeout=10)
        resp.raise_for_status()
        data = resp.json()
        if data["status"] != "in-progress":
            return data
        time.sleep(0.5)


def print_results(data: dict):
    results = data.get("results", [])
    if not results:
        print("No results returned.")
        return

    rows = []
    for r in results:
        probe = r["probe"]
        label = f"{probe['country']} / {probe['city']} / {probe['network']}"
        result = r["result"]
        if result["status"] != "finished":
            rows.append((label, "N/A", "N/A", "N/A", "N/A"))
            continue
        stats = result.get("stats", {})
        mn  = f"{stats['min']:.1f}" if stats.get("min") is not None else "N/A"
        avg = f"{stats['avg']:.1f}" if stats.get("avg") is not None else "N/A"
        mx  = f"{stats['max']:.1f}" if stats.get("max") is not None else "N/A"
        loss = f"{stats.get('loss', 'N/A')}%"
        rows.append((label, mn, avg, mx, loss))

    col_w = max(len(row[0]) for row in rows)
    col_w = max(col_w, len("Probe"))

    print(f"\n{'Probe':<{col_w}} {'Min':>8} {'Avg':>8} {'Max':>8} {'Loss':>8}")
    print("-" * (col_w + 36))
    for label, mn, avg, mx, loss in rows:
        print(f"{label:<{col_w}} {mn:>8} {avg:>8} {mx:>8} {loss:>8}")


def main():
    parser = argparse.ArgumentParser(description="Run ping via Globalping API")
    parser.add_argument("target", help="Hostname or IP to ping")
    parser.add_argument("--country", default="RU", help="Country code (default: RU)")
    parser.add_argument("--probes", type=int, default=3, help="Number of probes (default: 3)")
    parser.add_argument("--token", default=None, help="Globalping API token for higher limits")
    parser.add_argument("--city", default=None, help="City name to filter probes (e.g. Moscow)")
    args = parser.parse_args()

    location_desc = args.country + (f" / {args.city}" if args.city else "")
    print(f"Pinging {args.target} from {location_desc} ({args.probes} probes)...")
    measurement_id = create_measurement(args.target, args.country, args.probes, args.token, args.city)
    print(f"Measurement ID: {measurement_id}")

    data = wait_for_result(measurement_id)
    print_results(data)


if __name__ == "__main__":
    main()
