#!/usr/bin/env python3
import shutil
from pathlib import Path
from typing import List, Optional, Union

import laia
import laia.data.transforms as transforms
import numpy as np
import torch
import torchvision
import tqdm

from seam_carving import seams_removal


root = Path("data")
invert = False
max_length = 80
N = {"tr": 900, "te": 100}
h, w = 28, 28
space_sym = "<space>"
should_seam_carve = True
seams_per_sample = 10
samples_per_space = 5
np.random.seed(12345)

lang_dir = root / "lang"
lang_dir.mkdir(parents=True, exist_ok=True)


def get_dataset(partition):
    return torchvision.datasets.MNIST(
        root,
        train=partition == "tr",
        transform=transforms.vision.ToImageTensor(mode="L", invert=invert),
        target_transform=None,
        download=True,
    )


def get_indices(
    max_length: int, space_sym: Optional[str] = None, samples_per_space: int = 5
) -> List[Union[str, int]]:
    n_samples = np.random.randint(1, high=max_length + 1)
    indices = list(np.random.choice(len(dataset), size=n_samples))
    if space_sym is not None and n_samples > samples_per_space:
        n_spaces = np.random.randint(0, high=(n_samples // samples_per_space) + 1)
        arange = np.arange(1, len(indices) - 1)  # no spaces at beginning or end
        space_indices = np.random.choice(arange, size=n_spaces, replace=False)
        n_samples += n_spaces
        for space_i in space_indices:
            indices.insert(space_i, "sp")
    return indices


def concatenate(dataset, indices: List[Union[str, int]], invert: bool):
    img = np.empty((h, w * len(indices)))
    txt = []
    # mask to avoid carving space pixels
    space_mask = np.zeros_like(img)
    for i, idx in enumerate(indices):
        w_slice = slice(w * i, w * (i + 1))
        if idx == "sp":
            # add space pixels
            img[:, w_slice] = bool(invert)
            txt.append(space_sym)
            space_mask[:, w_slice] = 1
        else:
            # add actual image
            x, y = dataset[idx]
            img[:, w_slice] = x.numpy()
            txt.append(str(y))
    txt = " ".join(txt)
    return img, txt, space_mask


# save symbols table
syms = laia.utils.SymbolsTable()
syms.add("<ctc>", 0)
for i in range(0, 10):
    syms.add(str(i), i + 1)
if space_sym is not None:
    syms.add(space_sym, 11)
with open(lang_dir / "syms.txt", mode="wb") as f:
    syms.save(f)

for partition in N.keys():
    # download MNIST
    dataset = get_dataset(partition)

    # prepare img directory
    imgs_dir = root / "imgs" / partition
    if imgs_dir.exists():
        shutil.rmtree(imgs_dir)
    imgs_dir.mkdir(parents=True, exist_ok=True)

    # generate data
    gt_file = open(lang_dir / f"{partition}.gt", mode="w")
    samples_file = open(imgs_dir.parent / f"{partition}_samples.txt", mode="w")

    for i in tqdm.trange(N[partition], desc=partition):
        indices = get_indices(
            max_length, space_sym=space_sym, samples_per_space=samples_per_space
        )
        img, txt, mask = concatenate(dataset, indices, invert)

        if should_seam_carve:
            # seams to remove per sample
            seams = len([idx for idx in indices if idx != "sp"]) * seams_per_sample
            assert img.shape[1] - seams >= 0
            img = seams_removal(img, seams, mask)

        # save line image
        img_id = f"{partition}-{i}"
        torchvision.utils.save_image(torch.from_numpy(img), imgs_dir / f"{img_id}.jpg")
        # save reference
        gt_file.write(f"{img_id} {txt}\n")
        # save indices used for each line
        samples_file.write(f"{img_id} {[str(idx) for idx in indices]}\n")

    gt_file.close()
    samples_file.close()
