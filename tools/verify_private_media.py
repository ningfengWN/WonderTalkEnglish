#!/usr/bin/env python3
"""Verify local private WonderTalk media before building the iOS app.

Run: python3 tools/verify_private_media.py
Private transcripts/audio are never sent to GitHub by this script.
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "WonderTalkEnglish/Lessons/learning_catalog_v1.json"
MANIFEST = ROOT / "WonderTalkEnglish/Lessons/private_course_media.json"
AUDIO = ROOT / "WonderTalkEnglish/Audio"
RETIRED = {"e17", "e20", "rates", "renaissance"}

def fail(message):
    print("ERROR:", message, file=sys.stderr)
    sys.exit(1)

if not CATALOG.exists():
    fail(f"Missing catalog: {CATALOG}")
catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
by_id = {x["id"]: x for x in catalog}
if len(by_id) != len(catalog):
    fail("Duplicate course IDs in catalog")
if RETIRED & by_id.keys():
    fail(f"Retired courses still in catalog: {sorted(RETIRED & by_id.keys())}")
print(f"Public catalog: {len(catalog)} courses")
if not MANIFEST.exists():
    fail("Private media missing. Install the V5 private resource ZIP first.")
manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
if manifest.get("formatVersion") != 1:
    fail("Unsupported private manifest format")
items = manifest.get("items", [])
if not items:
    fail("Private media manifest has no items")
ids = set()
hashes = {}
with_transcript = 0
with_audio = 0
for item in items:
    id = item["id"]
    if id in ids:
        fail(f"Duplicate private item: {id}")
    ids.add(id)
    if id not in by_id:
        fail(f"Unknown or retired course: {id}")
    if item["sourceURL"] != by_id[id]["sourceURL"]:
        fail(f"Source URL mismatch for {id}")
    lines = item.get("lines") or []
    if lines:
        with_transcript += 1
    stem = item.get("bundledAudioStem")
    if stem:
        audio = AUDIO / f"{stem}_full.mp3"
        if not audio.is_file() or audio.stat().st_size < 1000:
            fail(f"Missing/empty audio: {audio}")
        digest = hashlib.sha256(audio.read_bytes()).hexdigest()
        if digest in hashes:
            fail(f"Duplicate audio: {id} and {hashes[digest]}")
        hashes[digest] = id
        with_audio += 1
    duration = item.get("durationSeconds")
    if duration is not None and (not isinstance(duration, (float, int)) or duration <= 0):
        fail(f"Invalid duration for {id}")
print(f"Private lessons: {len(items)}; transcripts: {with_transcript}; MP3s: {with_audio}")
print("Removed courses absent; source URLs match; audio hashes unique.")
if {"e02", "e10"} - ids:
    fail("V5 should contain both e02 and e10")
if not any(x["id"] == "e10" and x.get("lines") for x in items):
    fail("V5 e10 transcript not found")
print("V5 verification PASSED")
