"""Build the dependency-free TGA icon for DeleteCheapestItem."""

from pathlib import Path
import struct


SIZE = 128
OUTPUT = Path(__file__).resolve().parent.parent / "Media" / "icon.tga"


def icon_pixel(x, y):
    color = (16, 28 + y // 10, 42 + y // 11)
    edge = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
    if edge < 3:
        color = (165, 125, 64)
    elif edge < 6:
        color = (45, 54, 56)

    # Bin silhouette, rim, and three vertical panels.
    if 36 <= y <= 107 and 35 + (y - 36) // 15 <= x <= 93 - (y - 36) // 15:
        color = (106, 121, 126)
        if 39 + (y - 36) // 15 <= x <= 89 - (y - 36) // 15 and y < 103:
            color = (40, 56, 63)
        if 48 <= x <= 53 or 62 <= x <= 67 or 76 <= x <= 81:
            if 53 <= y <= 99:
                color = (97, 116, 120)
    if 26 <= x <= 102 and 35 <= y <= 43:
        color = (177, 176, 154)
    if 29 <= x <= 99 and 39 <= y <= 41:
        color = (104, 113, 110)
    if 53 <= x <= 75 and 27 <= y <= 34:
        color = (178, 176, 151)
    if 57 <= x <= 71 and 30 <= y <= 34:
        color = (56, 67, 68)

    # Copper coin in the foreground signals the item's low value.
    distance = ((x - 91) ** 2 + (y - 91) ** 2) ** 0.5
    if distance <= 22:
        color = (87, 49, 29)
    if distance <= 19:
        color = (201, 130, 60)
    if distance <= 15:
        color = (139, 79, 38)
    if distance <= 12:
        color = (188, 111, 49)
    if distance <= 12 and (x + y) % 9 < 2:
        color = (201, 128, 61)

    return bytes((color[2], color[1], color[0], 255))


def main():
    OUTPUT.parent.mkdir(exist_ok=True)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    with OUTPUT.open("wb") as image:
        image.write(header)
        for y in range(SIZE):
            for x in range(SIZE):
                image.write(icon_pixel(x, y))


if __name__ == "__main__":
    main()
