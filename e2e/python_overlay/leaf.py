from pathlib import Path

def message():
    return Path(__file__).with_name("message.txt").read_text().strip()
