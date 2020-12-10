import argparse
from pathlib import Path
import cv2

suffixes = (".png", ".jpg")


def main(gt, hyp, img_dir, img_idx=0):
    assert len(gt) == len(hyp)

    errors = []
    for id in hyp.keys():
        if gt[id] == hyp[id]:
            continue
        for suffix in suffixes:
            img_path = img_dir / (id + suffix)
            if img_path.exists():
                break
        else:
            raise ValueError(f'No image found: {img_path.with_suffix("")})')
        errors.append((img_path, gt[id], hyp[id]))

    i = img_idx
    while True:
        img_path, gt, hyp = errors[i]
        img = cv2.imread(str(img_path), -1)
        cv2.imshow("viewer", img)
        print(f"{i + 1}/{len(errors)} - {img_path}:")
        print(f'gt  = "{gt}"')
        print(f'hyp = "{hyp}"')
        print()

        k = cv2.waitKey(0)
        if k == 81 and i > 0:  # left arrow
            i -= 1
        elif k == 83 and i < len(errors) - 1:  # right arrow
            i += 1
        elif k == 27:  # ESC
            break
        cv2.destroyAllWindows()
    cv2.destroyAllWindows()
    exit(0)


def file_to_dict(file):
    d = {}
    for l in file.readlines():
        id, txt = l.split(" ", maxsplit=1)
        txt = txt.rstrip()
        d[id] = txt
    return d


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("gt", type=Path)
    parser.add_argument("hyp", type=Path)
    parser.add_argument("img_dir", type=Path)
    parser.add_argument("--img_idx", type=int, default=1)
    args = parser.parse_args()

    with open(args.gt) as f:
        gt = file_to_dict(f)
    with open(args.hyp) as f:
        hyp = file_to_dict(f)

    main(gt, hyp, args.img_dir, img_idx=args.img_idx - 1)
