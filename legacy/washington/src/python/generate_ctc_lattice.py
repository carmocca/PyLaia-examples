#!/usr/bin/env python3

from __future__ import print_function

import argparse

import torch

from laia.data import ImageDataLoader
from laia.data import TextImageFromTextTableDataset
from laia.losses.ctc_loss import transform_output
from laia.models.htr.dortmund_crnn import DortmundCRNN
from laia.plugins.arguments import add_argument, add_defaults, args
from laia.utils.symbols_table import SymbolsTable
import laia.data.transforms as transforms


def ctc_lattice(img_ids, outputs, fileout):
    for img_id, output in zip(img_ids, outputs):
        output = output.cpu()
        print(img_id, file=fileout)
        for t in range(output.size(0)):
            for k in range(output.size(1)):
                print(
                    "{:d}\t{:d}\t{:d}\t0,{:.10g},{:d}".format(
                        t, t + 1, k + 1, -float(output[t, k]), k + 1
                    ),
                    file=fileout,
                )
        print(output.size(0), file=fileout)
        print("", file=fileout)


if __name__ == "__main__":
    add_defaults("gpu")
    add_argument(
        "--image_sequencer",
        type=str,
        default="avgpool-16",
        help="Average adaptive pooling of the images before the LSTM layers",
    )
    add_argument("--lstm_hidden_size", type=int, default=128)
    add_argument("--lstm_num_layers", type=int, default=1)
    add_argument("--add_softmax", action="store_true")
    add_argument("syms", help="Symbols table mapping from strings to integers")
    add_argument("img_dir", help="Directory containing word images")
    add_argument("gt_file", help="")
    add_argument("checkpoint", help="")
    add_argument("output", type=argparse.FileType("w"))
    args = args()

    # Build neural network
    syms = SymbolsTable(args.syms)
    model = DortmundCRNN(
        num_outputs=len(syms),
        sequencer=args.image_sequencer,
        lstm_hidden_size=args.lstm_hidden_size,
        lstm_num_layers=args.lstm_num_layers,
    )

    # Load checkpoint
    ckpt = torch.load(args.checkpoint)
    if "model" in ckpt and "optimizer" in ckpt:
        model.load_state_dict(ckpt["model"])
    else:
        model.load_state_dict(ckpt)

    # Ensure parameters are in the correct device
    model.eval()
    if args.gpu > 0:
        model = model.cuda(args.gpu - 1)
    else:
        model = model.cpu()

    dataset = TextImageFromTextTableDataset(
        args.gt_file,
        args.img_dir,
        img_transform=transforms.vision.ToTensor(),
        txt_transform=transforms.text.ToTensor(syms),
    )
    dataset_loader = ImageDataLoader(dataset=dataset, image_channels=1, num_workers=8)

    import sys

    with torch.cuda.device(args.gpu - 1):
        for batch in dataset_loader:
            if args.gpu > 0:
                x = batch["img"].data.cuda(args.gpu - 1)
            else:
                x = batch["img"].data.cpu()
            y = model(torch.autograd.Variable(x))
            y = y.permute(1, 0, 2)
            if args.add_softmax:
                y = torch.nn.functional.log_softmax(y, dim=-1)
            ctc_lattice(batch["id"], y, args.output)
