"""Shared helpers for the Python unit tests."""
import os


def write(folder, name, text):
    """Writes text to folder/name (creating folders) and returns the path."""
    path = os.path.join(folder, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path
