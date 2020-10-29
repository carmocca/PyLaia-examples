#!/usr/bin/env python

from __future__ import print_function

import argparse

import torch

from laia.data import ImageDataLoader
from laia.data import TextImageFromTextTableDataset
from laia.decoders import CTCGreedyDecoder
from laia.models.htr.dortmund_crnn import DortmundCRNN
from laia.plugins.arguments import add_argument, add_defaults, args
from laia.plugins.arguments_types import str2bool
from laia.utils import ImageToTensor, TextToTensor
from laia.utils.symbols_table import SymbolsTable

if __name__ == "__main__":
    add_defaults("gpu")
    add_argument(
        "--output_symbols",
        type=str2bool,
        nargs="?",
        const=True,
        default=False,
        help="Print the output with symbols instead of integers",
    )
    add_argument(
        "--image_sequencer",
        type=str,
        default="avgpool-16",
        help="Average adaptive pooling of the images before the LSTM layers",
    )
    add_argument("--lstm_hidden_size", type=int, default=128)
    add_argument("--lstm_num_layers", type=int, default=1)
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
        img_transform=ImageToTensor(),
        txt_transform=TextToTensor(syms),
    )
    dataset_loader = ImageDataLoader(dataset=dataset, image_channels=1, num_workers=8)

    decoder = CTCGreedyDecoder()
    with torch.cuda.device(args.gpu - 1):
        for batch in dataset_loader:
            if args.gpu > 0:
                x = batch["img"].data.cuda(args.gpu - 1)
            else:
                x = batch["img"].data.cpu()
            y = model(torch.autograd.Variable(x))
            y = decoder(y)
            if args.output_symbols:
                y = list(map(lambda i: syms[i], y[0]))
            else:
                y = list(map(lambda i: str(i), y[0]))
            print("{} {}".format(batch["id"][0], " ".join(y)), file=args.output)
