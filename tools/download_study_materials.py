#!/usr/bin/env python3
"""Personal/offline acquisition helper for WonderTalkEnglish.

Only Open Yale Courses and ELLLO are enabled. This does not grant
redistribution/commercial rights. Never commit downloaded media or transcripts.
"""
import argparse
import html
import json
import re
import sys
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

USER_AGENT = "WonderTalkEnglishPersonalStudy/1.0 (personal educational use)"
ALLOWED = {
    "Open Yale Courses": ("oyc.yale.edu",),
    "ELLLO": ("elllo.org", "www.elllo.org"),
}

class MediaLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        for key in ("href", "src", "data-src", "data-audio"):
            if key in d and d[key]:
                self.links.append(d[key])

def get(url, max_bytes=16_000_000):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(max_bytes + 1)
        if len(data) > max_bytes:
            raise ValueError("Page exceeds size limit")
        return data, response.headers.get_content_type()

class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
        self.skip = 0
    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "noscript"):
            self.skip += 1
        if tag in ("p", "h1", "h2", "h3", "h4", "div", "br"):
            self.parts.append("\n")
    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript") and self.skip:
            self.skip -= 1
    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)
    def to_text(self):
        text = html.unescape(" ".join(self.parts))
        lines = [re.sub(r"\s+", " ", item).strip() for item in text.splitlines()]
        return "\n".join(item for item in lines if item)

def yale_transcript(page):
    extractor = TextExtractor()
    extractor.feed(page)
    text = extractor.to_text()
    start = re.search(r"Chapter\s*1[.：:]\s*", text, re.I)
    if not start:
        return None
    transcript = text[start.start():]
    transcript = re.split(r"\n\s*(?:Download|Related Resources|More about this course|Copyright)\b",
                          transcript, maxsplit=1, flags=re.I)[0]
    return transcript if len(transcript) > 1000 else None

def candidates(page, base):
    parser = MediaLinks()
    parser.feed(page)
    links = parser.links
    links += re.findall(r'["\']([^"\'\s<>]+\.mp3(?:\?[^"\'\s<>]*)?)["\']', page, flags=re.I)
    found = []
    for value in links:
        value = html.unescape(value).replace("\\/", "/")
        url = urllib.parse.urljoin(base, value)
        p = urllib.parse.urlsplit(url)
        if p.scheme == "https" and p.path.lower().endswith((".mp3", ".m4a")) and url not in found:
            found.append(url)
    return found

def save_media(url, destination):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as response, destination.open("wb") as file:
        length = 0
        while True:
            chunk = response.read(1024 * 256)
            if not chunk:
                break
            length += len(chunk)
            if length > 180_000_000:
                raise ValueError("Audio exceeds 180 MB limit")
            file.write(chunk)
    if destination.stat().st_size < 2048:
        raise ValueError("Audio file appears too small")
    return destination.stat().st_size

def main():
    ap = argparse.ArgumentParser(description="Download eligible personal study audio and source HTML.")
    ap.add_argument("--catalog", default="WonderTalkEnglish/Lessons/learning_catalog_v1.json")
    ap.add_argument("--ids", nargs="+", required=True, help="e.g. h01 h02 h03 e02")
    ap.add_argument("--output", default="PrivateStudyDownloads")
    ap.add_argument("--agree-noncommercial", action="store_true",
                    help="Confirm personal noncommercial use; downloaded files must not be committed.")
    args = ap.parse_args()
    if not args.agree_noncommercial:
        ap.error("Pass --agree-noncommercial for personal, noncommercial study downloads.")
    catalog = {item["id"]: item for item in json.loads(Path(args.catalog).read_text(encoding="utf-8"))}
    base = Path(args.output)
    base.mkdir(parents=True, exist_ok=True)
    (base / ".gitignore").write_text("*\n!.gitignore\n", encoding="utf-8")
    report = []
    for id in args.ids:
        record = catalog.get(id.lower())
        if not record:
            report.append({"id": id, "status": "unknown_lesson"})
            continue
        source = record["sourceName"]
        domain = urllib.parse.urlsplit(record["sourceURL"]).hostname or ""
        if source not in ALLOWED or domain not in ALLOWED[source]:
            report.append({"id": id, "status": "external_or_rights_not_cleared",
                           "url": record["sourceURL"]})
            continue
        folder = base / id.lower()
        folder.mkdir(parents=True, exist_ok=True)
        status = {"id": id, "status": "source_saved", "url": record["sourceURL"]}
        try:
            body, content_type = get(record["sourceURL"])
            if content_type not in ("text/html", "application/xhtml+xml"):
                raise ValueError("Expected an HTML source page")
            (folder / "source_page.html").write_bytes(body)
            if source == "Open Yale Courses":
                transcript = yale_transcript(body.decode("utf-8", errors="replace"))
                if transcript:
                    (folder / "transcript.txt").write_text(transcript, encoding="utf-8")
                    status["transcript_path"] = str(folder / "transcript.txt")
                else:
                    status["transcript_note"] = "No identifiable chapter transcript; see saved page."
            (folder / "metadata.json").write_text(
                json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
            links = candidates(body.decode("utf-8", errors="replace"), record["sourceURL"])
            status["audio_candidates"] = links
            if links:
                for link in links:
                    extension = Path(urllib.parse.urlsplit(link).path).suffix.lower()
                    audiofile = folder / ("audio" + extension)
                    try:
                        status["downloaded_bytes"] = save_media(link, audiofile)
                        status["audio_path"] = str(audiofile)
                        status["status"] = "audio_downloaded"
                        break
                    except Exception as exc:
                        audiofile.unlink(missing_ok=True)
                        status["last_audio_error"] = str(exc)
            if status["status"] != "audio_downloaded":
                status["note"] = "No usable audio direct link found: open official page and download manually."
        except Exception as exc:
            status["status"] = "failed"
            status["error"] = str(exc)
        report.append(status)
        print(f'{id}: {status["status"]}')
    (base / "download_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Report: {base / 'download_report.json'}")
    return 0 if all(x["status"] == "audio_downloaded" for x in report) else 1

if __name__ == "__main__":
    sys.exit(main())
