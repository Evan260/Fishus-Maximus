#!/usr/bin/env bash
# Paints the parallax style test's layers and fish with PixelLab. A layer already made is skipped, so a rerun only
# paints what is missing; delete a file to paint it again. A clear background allows at most 65,536 pixels of area.
cd "$(dirname "$0")/../.."
D=game/assets/art/coast
mkdir -p "$D"
STYLE="cozy pixel art, warm sunset palette, soft shading, no outlines"
paint() {
	out="$1"; size="$2"; clear="$3"; shift 3; desc="$*"
	[ -f "$D/$out" ] && return
	flag=""
	[ "$clear" = "clear" ] && flag="--transparent"
	for attempt in 1 2; do
		if timeout 280 python tools/art/pixellab.py pixen "$desc, $STYLE" "$size" --out "$D/$out" $flag --raw --view side --outline lineless --detail "highly detailed" 2>&1 | grep -q "cost:"; then
			echo "made $out"; return
		fi
		sleep 5
	done
	echo "FAILED $out"
}
paint far.png 640x72 clear "distant mountains on the horizon seen from the sea, the green cone of Mount Vesuvius on the right half, low hazy coastal hills on the left, faded by evening haze, flat straight bottom edge, nothing below the mountains"
paint mid.png 768x80 clear "a row of green coastal headlands seen from the sea at a middle distance, umbrella pines, dark cypress trees, olive groves and two white ancient Roman villas with red tiled roofs on the hills, warm evening light, flat straight bottom edge where the hills meet the sea"
paint town.png 480x120 clear "an ancient Roman harbour town of the first century seen from the sea, low houses with terracotta tiled roofs and plain plastered walls, a small temple with white columns, a tall stone lighthouse on the right end, umbrella pines and cypress trees, warm sunset light, flat straight bottom edge, no water"
paint cape.png 320x112 clear "a rocky cape seen from the sea, tall golden limestone cliffs with umbrella pines on top and a small ancient Roman stone watchtower, warm sunset light, flat straight bottom edge, no water"
paint quay.png 160x224 clear "cross-section of an ancient Roman stone harbour quay seen from the side: the top fifth above water is a stone pier with wooden mooring posts and clay amphorae, everything below is the quay wall of big square stone blocks going down into the sea, the underwater part blue-green with seaweed and barnacles, ending on sand at the bottom"
paint deep_far.png 512x128 clear "distant underwater rock formations and reef silhouettes seen through blue-green water haze, faded and soft, no fish, transparent water"
paint bed_harbour.png 320x200 clear "no border, no frame, underwater cross-section of a shallow harbour sea floor seen from the side, the sand floor running across the whole bottom edge from left to right: pale sand with green seagrass meadows, scattered stones, sea urchins and a broken clay amphora, the floor rises gently to the left, transparent water above"
paint bed_reef.png 256x256 clear "underwater cross-section seen from the side: a rocky reef with ledges and small dark caves that drops away steeply to the right into deep water, red sea fans, orange sponges and seaweed on the rocks, transparent water"
paint bed_deep.png 400x160 clear "underwater cross-section of a deep sea floor seen from the side: dark blue sand, big boulders and a few pale sea fans in dim light, transparent water above"
paint weeds_a.png 96x64 clear "a clump of tall swaying green seagrass strands growing from the bottom, underwater"
paint weeds_b.png 64x64 clear "a tuft of red and brown seaweed growing from a small rock, underwater"
paint mullet.png 48x32 clear "a small red mullet fish seen exactly from the side facing right, pink and red body with yellow stripes, two little chin barbels"
paint bream.png 48x32 clear "a gilt-head sea bream fish seen exactly from the side facing right, silver body with a gold band between the eyes"
paint sardine.png 32x32 clear "a very small sardine fish seen exactly from the side facing right, silver body with a blue-green back, small in the middle of the picture"
paint moray.png 64x32 clear "a moray eel seen exactly from the side facing right, long brown body speckled with yellow, mouth slightly open, natural and realistic"
paint octopus.png 48x48 clear "a realistic common octopus seen from the side, mottled reddish brown skin, small eyes, long curling arms, natural not cartoon"
paint grouper.png 64x48 clear "a big dusky grouper fish seen exactly from the side facing right, dark brown body with pale blotches, large mouth, realistic"
paint tuna.png 96x48 clear "a large bluefin tuna fish seen exactly from the side facing right, dark blue back, silver belly, small yellow finlets, realistic"
echo done
