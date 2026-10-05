"""Extract the small Gen 3 gender table from the bundled species extras."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
EXTRAS = ROOT / "data/species/generated/extras"
TARGET = ROOT / "data/species/generated/gender_rates.lua"
INDEX_RE = re.compile(r"^  ([A-Z0-9_]+) = \d+,$", re.MULTILINE)
RATE_RE = re.compile(r"^  ([A-Z0-9_]+) = \{.*?\bgenderRate = (-?\d+)", re.MULTILINE)


def main() -> None:
    names = set(INDEX_RE.findall((EXTRAS / "index.lua").read_text(encoding="utf-8")))
    rates = {}
    for shard in sorted(EXTRAS.glob("[0-9][0-9][0-9].lua")):
        for name, raw_rate in RATE_RE.findall(shard.read_text(encoding="utf-8")):
            if name in rates:
                raise ValueError(f"Duplicate gender rate: {name}")
            rate = int(raw_rate)
            if rate not in range(-1, 9):
                raise ValueError(f"Invalid gender rate for {name}: {rate}")
            rates[name] = rate
    if rates.keys() != names:
        raise ValueError(f"Gender rates missing: {sorted(names - rates.keys())}")

    lines = [
        "-- Generated from extras/*.lua by dex/tools/build_gender_rates.py.",
        "-- PokeAPI genderRate: female chance in eighths, -1 means genderless.",
        "return {",
    ]
    lines.extend(f"  {name} = {rates[name]}," for name in sorted(rates))
    lines.append("}")
    TARGET.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(rates)} gender rates to {TARGET}")


if __name__ == "__main__":
    main()
