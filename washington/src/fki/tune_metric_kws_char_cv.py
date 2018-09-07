#!/usr/bin/env python3

from __future__ import print_function

import argparse
import logging
import sys
from functools import lru_cache
from shlex import quote
import numpy as np

from compute_kws_metrics_char import (
    kws_assessment_column_index,
    kws_assessment_position_index,
    kws_assessment_segment_index,
    kws_assessment_utterance_index,
)
from hyperopt import fmin, tpe, hp

from laia.utils.symbols_table import SymbolsTable

if __name__ == "__main__":
    logging.basicConfig()
    logger = logging.getLogger("tune_kws_metric")
    logger.setLevel(logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument("--queries_pattern", type=str, default=None)
    parser.add_argument(
        "--index-type",
        choices=("utterance", "segment", "position", "column"),
        default="utterance",
    )
    parser.add_argument("--acoustic-scale-max", default=5.0, type=float)
    parser.add_argument("--acoustic-scale-min", default=0.1, type=float)
    parser.add_argument("--acoustic-scale-quant", default=0.05, type=float)
    parser.add_argument("--prior-scale-max", default=1.0, type=float)
    parser.add_argument("--prior-scale-min", default=0.0, type=float)
    parser.add_argument("--prior-scale-quant", default=0.1, type=float)
    parser.add_argument("--use-kws-eval", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--max-iters", type=int, default=400)
    parser.add_argument("--optimize-for", choices=("mAP", "gAP", "avg"), default="avg")
    parser.add_argument("--nbest", type=int, default=100)
    parser.add_argument("--max-states", type=int, default=None)
    parser.add_argument("--max-arcs", type=int, default=None)
    parser.add_argument("--seed", type=int, default=0x12345)
    parser.add_argument("--char-separator", type=str, default="")
    parser.add_argument("num_partitions", type=int)
    parser.add_argument("syms_pattern")
    parser.add_argument("kws_refs_pattern")
    parser.add_argument("lattice_ark_pattern")
    parser.add_argument("delimiters", type=int, nargs="+")
    args = parser.parse_args()
    logger.info("Command line: %s", " ".join([quote(x) for x in sys.argv[1:]]))

    if args.index_type == "utterance":
        if args.use_kws_eval:
            raise NotImplementedError
        else:
            func = kws_assessment_utterance_index
    elif args.index_type == "segment":
        if args.use_kws_eval:
            raise NotImplementedError
        else:
            func = kws_assessment_segment_index
    elif args.index_type == "position":
        if args.use_kws_eval:
            raise NotImplementedError
        else:
            func = kws_assessment_position_index
    elif args.index_type == "column":
        if args.use_kws_eval:
            raise NotImplementedError
        else:
            func = kws_assessment_column_index
    else:
        raise NotImplementedError

    # Configure hyperparamter search space
    space = []
    params_to_optimize = []
    if args.prior_scale_max != args.prior_scale_min:
        params_to_optimize.append("prior_scale")
        space.append(
            hp.quniform(
                "prior_scale",
                args.prior_scale_min,
                args.prior_scale_max,
                args.prior_scale_quant,
            )
        )
        prior_scale_global = None
        prior_scale_key = len(space) - 1
    else:
        prior_scale_global = args.prior_scale_max
        prior_scale_key = None

    if args.acoustic_scale_max != args.acoustic_scale_min:
        params_to_optimize.append("acoustic_scale")
        space.append(
            hp.quniform(
                "acoustic_scale",
                args.acoustic_scale_min,
                args.acoustic_scale_max,
                args.acoustic_scale_quant,
            )
        )
        acoustic_scale_global = None
        acoustic_scale_key = len(space) - 1
    else:
        acoustic_scale_global = args.acoustic_scale_max
        acoustic_scale_key = None

    syms = [ SymbolsTable(args.syms_pattern.format(cv=cv))
             for cv in range(args.num_partitions) ]

    @lru_cache(maxsize=None)
    def objective(params):
        if prior_scale_key is not None:
            prior_scale = params[prior_scale_key]
        else:
            prior_scale = prior_scale_global

        if acoustic_scale_key is not None:
            acoustic_scale = params[acoustic_scale_key]
        else:
            acoustic_scale = acoustic_scale_global

        result = {}
        for cv in range(1, args.num_partitions + 1):
            lattice_ark = args.lattice_ark_pattern.format(
                acoustic_scale=acoustic_scale, prior_scale=prior_scale,
                cv=cv,
            )
            queries = args.queries_pattern.format(cv=cv)
            kws_refs = args.kws_refs_pattern.format(cv=cv)
            logging.debug(
                "Trying acoustic_scale={:.2f} with lattic_ark={}".format(
                    acoustic_scale, lattice_ark
                )
            )
            for key, value in func(
                syms=syms[cv - 1],
                delimiters=args.delimiters,
                kws_ref=kws_refs,
                lattice_ark=lattice_ark,
                acoustic_scale=acoustic_scale,
                nbest=args.nbest,
                queries=queries,
                verbose=args.verbose,
                max_states=args.max_states,
                max_arcs=args.max_arcs,
                char_sep=args.char_separator,
            ).items():
                if key in result:
                    result[key] += value
                else:
                    result[key] = value

        for key, value in result.items():
            result[key] = value / args.num_partitions

        logger.info(
            "acoustic_scale = {:.2f}  prior_scale = {:.1f}  "
            "mAP = {}  gAP = {}".format(
                acoustic_scale, prior_scale, result["mAP"], result["gAP"],
            )
        )
        # Note: minimize -criterion
        if args.optimize_for == "mAP":
            return -result["mAP"]
        elif args.optimize_for == "gAP":
            return -result["gAP"]
        else:
            return -(result["mAP"] + result["gAP"]) / 2.0

    logger.info(
        "Optimizing {} for: {}".format(str(params_to_optimize), args.optimize_for)
    )
    best = fmin(
        fn=objective,
        space=space,
        algo=tpe.suggest,
        max_evals=args.max_iters,
        rstate=np.random.RandomState(args.seed),
    )
    print(best)
