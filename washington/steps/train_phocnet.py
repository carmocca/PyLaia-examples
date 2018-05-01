#!/usr/bin/env python
from __future__ import division

import os
from argparse import FileType

import laia.logging as log
import laia.utils
import torch
from dortmund_utils import (build_dortmund_model, DortmundImageToTensor,
                            ModelCheckpointKeepLastSaver)
from laia.engine.engine import ON_EPOCH_START, ON_EPOCH_END
from laia.engine.phoc_engine_wrapper import PHOCEngineWrapper
from laia.hooks import Hook, HookCollection
from laia.hooks.conditions import GEqThan, Highest
from laia.plugins.arguments import add_argument, add_defaults, args

if __name__ == '__main__':
    add_defaults('gpu', 'max_epochs', 'max_updates', 'samples_per_epoch',
                 'valid_samples_per_epoch', 'seed', 'save_path',
                 # Override default values for these arguments, but use the
                 # same help/checks:
                 batch_size=1,
                 learning_rate=0.015,
                 momentum=0.9,
                 iterations_per_update=10,
                 show_progress_bar=True,
                 use_distortions=True,
                 weight_l2_penalty=0.00005)
    add_argument('--phoc_levels', type=int, default=[1, 2, 3, 4, 5], nargs='+',
                 help='PHOC levels used to encode the transcript')
    add_argument('--exclude_words_ap', type=FileType('r'),
                 help='List of words to exclude in the Average Precision '
                      'computation')
    add_argument('syms', help='Symbols table mapping from strings to integers')
    add_argument('tr_img_dir', help='Directory containing word images')
    add_argument('tr_txt_table',
                 help='Character transcriptions of each training image')
    add_argument('va_txt_table',
                 help='Character transcriptions of each validation image')
    args = args()

    laia.random.manual_seed(args.seed)

    syms = laia.utils.SymbolsTable(args.syms)

    phoc_size = sum(args.phoc_levels) * len(syms)
    model = build_dortmund_model(phoc_size)
    model = model.cuda(args.gpu - 1) if args.gpu > 0 else model.cpu()
    log.info('Model has {} parameters',
             sum(param.data.numel() for param in model.parameters()))

    optimizer = torch.optim.SGD(params=model.parameters(),
                                lr=args.learning_rate,
                                momentum=args.momentum,
                                weight_decay=args.weight_l2_penalty)

    # If --use_distortions is given, apply the same affine distortions used by
    # Dortmund University.
    if args.use_distortions:
        tr_img_transform = DortmundImageToTensor()
    else:
        tr_img_transform = laia.utils.ImageToTensor()

    # Training data
    tr_ds = laia.data.TextImageFromTextTableDataset(
        args.tr_txt_table, args.tr_img_dir, img_transform=tr_img_transform)
    if args.samples_per_epoch is None:
        tr_ds_loader = torch.utils.data.DataLoader(
            tr_ds, batch_size=args.batch_size, num_workers=8, shuffle=True,
            collate_fn=laia.data.PaddingCollater({
                'img': [1, None, None],
            }, sort_key=lambda x: -x['img'].size(2)))
    else:
        tr_ds_loader = torch.utils.data.DataLoader(
            tr_ds, batch_size=args.batch_size, num_workers=8,
            sampler=laia.data.FixedSizeSampler(tr_ds,
                                               args.samples_per_epoch),
            collate_fn=laia.data.PaddingCollater({
                'img': [1, None, None],
            }, sort_key=lambda x: -x['img'].size(2)))

    # Validation data
    va_ds = laia.data.TextImageFromTextTableDataset(
        args.va_txt_table, args.tr_img_dir,
        img_transform=laia.utils.ImageToTensor())
    if args.valid_samples_per_epoch is None:
        va_ds_loader = torch.utils.data.DataLoader(
            va_ds, args.batch_size, num_workers=8,
            collate_fn=laia.data.PaddingCollater({
                'img': [1, None, None],
            }, sort_key=lambda x: -x['img'].size(2)))
    else:
        va_ds_loader = torch.utils.data.DataLoader(
            va_ds, batch_size=args.batch_size, num_workers=8,
            sampler=laia.data.FixedSizeSampler(va_ds,
                                               args.valid_samples_per_epoch),
            collate_fn=laia.data.PaddingCollater({
                'img': [1, None, None],
            }, sort_key=lambda x: -x['img'].size(2)))

    trainer = laia.engine.Trainer(
        model=model,
        # Note: Criterion will be set automatically by the wrapper
        criterion=None,
        optimizer=optimizer,
        data_loader=tr_ds_loader,
        progress_bar='Train' if args.show_progress_bar else False)
    trainer.iterations_per_update = args.iterations_per_update

    evaluator = laia.engine.Evaluator(
        model=model,
        data_loader=va_ds_loader,
        progress_bar='Valid' if args.show_progress_bar else False)

    if args.exclude_words_ap:
        exclude_words_ap = set([x.strip() for x in args.exclude_words_ap])
    else:
        exclude_words_ap = None

    engine_wrapper = PHOCEngineWrapper(
        symbols_table=syms,
        phoc_levels=args.phoc_levels,
        train_engine=trainer,
        valid_engine=evaluator,
        gpu=args.gpu,
        exclude_labels=exclude_words_ap)

    highest_gap_saver = ModelCheckpointKeepLastSaver(
        model,
        os.path.join(args.save_path, 'model.ckpt-highest-valid-gap'))
    highest_map_saver = ModelCheckpointKeepLastSaver(
        model,
        os.path.join(args.save_path, 'model.ckpt-highest-valid-map'))

    # Set hooks
    trainer.add_hook(ON_EPOCH_END, HookCollection(
        Hook(Highest(engine_wrapper.valid_ap(), key=0, name='Highest gAP'),
             highest_gap_saver),
        Hook(Highest(engine_wrapper.valid_ap(), key=1, name='Highest mAP'),
             highest_map_saver)))
    if args.max_epochs and args.max_epochs > 0:
        trainer.add_hook(ON_EPOCH_START,
                         Hook(GEqThan(trainer.epochs, args.max_epochs),
                              trainer.stop))

    # Launch training
    engine_wrapper.run()

    # Save model parameters after training
    torch.save(model.state_dict(), os.path.join(args.save_path, 'model.ckpt'))
