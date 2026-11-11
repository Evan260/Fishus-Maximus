#!/usr/bin/env bash
# Runs the game windowed in each heavy scene and appends one line of JSON per scene to OUT (bench.jsonl by default).
# Usage: tools/bench.sh [OUT] [SECONDS] [SCENE...]
set -u
cd "${GAME_DIR:-$(dirname "$0")/../game}"
GODOT="${GODOT:-/c/Users/evand/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
OUT="${1:-$PWD/../bench.jsonl}"
SECONDS_EACH="${2:-20}"
shift 2 2>/dev/null || shift $#
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(harbour rocky_shore lucrine open_bay capri misenum deep night storm fight big_boat town shore map logbook strip minimised unfocused)
for scene in "${SCENES[@]}"; do
	case "$scene" in
		harbour|rocky_shore|lucrine|open_bay|capri|misenum) flags="--screen=coast --place=$scene --hour=10 --weather=clear" ;;
		deep) flags="--screen=coast --place=misenum --hour=10 --weather=clear --at=900,300" ;;
		night) flags="--screen=coast --place=harbour --hour=23 --weather=clear --aurora" ;;
		storm) flags="--screen=coast --place=open_bay --hour=15 --weather=storm" ;;
		fight) flags="--screen=coast --place=harbour --hour=10 --weather=clear --demo-cast --hook=tuna" ;;
		big_boat) flags="--screen=coast --place=misenum --hour=19 --weather=wind --boat=big_boat" ;;
		fishing) flags="--screen=coast --place=harbour --hour=10 --weather=clear --demo-cast" ;;
		town) flags="--screen=town --hour=10 --weather=clear" ;;
		shore) flags="--screen=shore --hour=10 --weather=clear" ;;
		map) flags="--screen=map --hour=10 --weather=clear" ;;
		logbook) flags="--screen=coast --place=harbour --hour=10 --weather=clear --panel=logbook" ;;
		strip) flags="--screen=coast --place=harbour --hour=10 --weather=clear --strip" ;;
		windows) flags="--screen=coast --place=harbour --hour=10 --weather=clear" ;;
		minimised|unfocused) flags="--screen=coast --place=harbour --hour=10 --weather=clear" ;;
		*) echo "unknown scene $scene"; continue ;;
	esac
	timeout $((SECONDS_EACH + 120)) "$GODOT" --path . -- --max-state --seed=7 --no-save --window=1440x810 $flags \
		--bench="$scene" --bench-seconds="$SECONDS_EACH" --bench-out="$OUT" 2>&1 | grep -E "^bench|ERROR|SCRIPT" | cut -c1-400 | head -20
done
