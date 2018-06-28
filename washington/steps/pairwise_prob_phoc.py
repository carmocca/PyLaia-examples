from __future__ import division

import argparse

import torch
from torch.autograd import Variable
from torch.utils.data import DataLoader
from tqdm import tqdm

import laia
import laia.common.logging as log
from dortmund_utils import build_dortmund_model
from laia.data import TextImageFromTextTableDataset
from laia.common.arguments import add_argument, add_defaults, args
from laia.utils import ImageToTensor
from laia.utils.phoc import pphoc

if __name__ == '__main__':
    add_defaults('gpu')
    add_argument('--phoc_levels', type=int, default=[1, 2, 3, 4, 5], nargs='+',
                 help='PHOC levels used to encode the transcript')
    add_argument('syms', help='Symbols table mapping from strings to integers')
    add_argument('img_dir', help='Directory containing word images')
    add_argument('queries', help='Transcription of each query image')
    add_argument('model_checkpoint', help='Filepath of the model checkpoint')
    add_argument('output', type=argparse.FileType('w'),
                 help='Filepath of the output file')
    args = args()

    syms = laia.utils.SymbolsTable(args.syms)
    phoc_size = sum(args.phoc_levels) * len(syms)
    model = build_dortmund_model(phoc_size)
    log.info('Model has {} parameters',
             sum(param.data.numel() for param in model.parameters()))
    model.load_state_dict(torch.load(args.model_checkpoint))
    model = model.cuda(args.gpu - 1) if args.gpu > 0 else model.cpu()
    model.eval()

    queries_dataset = TextImageFromTextTableDataset(
        args.queries, args.img_dir, img_transform=ImageToTensor())
    queries_loader = DataLoader(queries_dataset)


    def process_image(sample):
        sample = Variable(sample, requires_grad=False)
        sample = sample.cuda(args.gpu - 1) if args.gpu > 0 else sample.cpu()
        phoc = torch.nn.functional.logsigmoid(model(sample))
        return phoc.data.cpu().squeeze()


    # Predict PHOC vectors
    phocs = []
    labels = []
    samples = []
    for query in tqdm(queries_loader):
        phocs.append(process_image(query['img']))
        labels.append(query['txt'][0])
        samples.append(query['id'][0])

    n = len(phocs)
    log.info('Computing pairwise relevance probabilities among {} queries', n)
    phocs = torch.stack(phocs).type('torch.DoubleTensor')
    logprobs = pphoc(phocs)
    for i in range(n):
        for j in range(i + 1, n):  # Note: this skips the pair (i, i)
            k = i * n - i * (i - 1) // 2 + (j - i)
            args.output.write('{} {} {}\n'.format(samples[i],
                                                  samples[j],
                                                  logprobs[k]))
            args.output.write('{} {} {}\n'.format(samples[j],
                                                  samples[i],
                                                  logprobs[k]))
    log.info('Done.')
