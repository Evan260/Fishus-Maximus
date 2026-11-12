"""The pond's seagrass: the harbour's seagrass without the coral and the dark plant its painting cut off at its lower
corners, which would stand on the pond's sand with straight sides. Writes game/assets/art/estate/pond_weed.png."""
from pathlib import Path

import numpy as np
import scipy.ndimage as nd
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "game" / "assets" / "art"
# Below this row the corner plants stand apart from the seagrass's own leaves, left and right of these columns.
LOW = 30
LEFT = 21
RIGHT = 82


def main() -> None:
    a = np.asarray(Image.open(ROOT / "places" / "harbour" / "seagrass.png").convert("RGBA")).copy()
    a[LOW:, :LEFT] = 0
    a[LOW:, RIGHT + 1:] = 0
    groups, count = nd.label(a[..., 3] > 127, structure=np.ones((3, 3)))
    if count > 1:
        sizes = nd.sum(np.ones_like(groups), groups, range(1, count + 1))
        a[(groups > 0) & (groups != 1 + int(np.argmax(sizes)))] = 0
    Image.fromarray(a).save(ROOT / "estate" / "pond_weed.png")


if __name__ == "__main__":
    main()
