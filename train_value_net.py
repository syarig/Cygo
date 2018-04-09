# coding:utf-8
from os import path
from alphago.models.value import CNNValue
import alphago.preprocessing.genarate_value_training as gvt
import alphago.training.reinforcement_value_trainer as rvt

from util import ask_yn
from config import (value_model, value_weight, value_selfplay, value_planes,
                    rlpolicy_weight, slpolicy_weight, slpolicy_model)


def generate_train_pair(weight_RL, weight_SL, features):
    gvt.handle_arguments(cmd_line_args=[
        weight_SL, weight_RL, slpolicy_model,
        "--outfile", value_planes,
        "--sgf-path", value_selfplay,
        # "--n-training-pair", "30000000",t
        # "--batch-size", "10",
        "--n-training-pair", "50",
        "--batch-size", "1",
        "--features", ','.join(features),
        "--verbose"
    ])

def generate_sgf(weight_RL, weight_SL, features):
    gvt.handle_arguments(cmd_line_args=[
        weight_SL, weight_RL, slpolicy_model,
        "--outfile", value_planes,
        "--sgf-path", value_selfplay,
        # "--n-training-pair", "30000000",
        # "--batch-size", "10",
        "--n-training-pair", "20000",
        "--batch-size", "10",
        "--features", ','.join(features),
        "--generate-sgf-only",
        "--verbose"
    ])

def generate_train_pair_from_sgf(weight_RL, weight_SL, features):
    gvt.handle_arguments(cmd_line_args=[
        weight_SL, weight_RL, slpolicy_model,
        "--outfile", value_planes,
        "--sgf-path", value_selfplay,
        # "--n-training-pair", "30000000",
        # "--batch-size", "10",
        "--n-training-pair", "20000",
        "--batch-size", "10",
        "--features", ','.join(features),
        "--sgf-from", value_selfplay,
        "--verbose",
    ])

def create_model(features):
    arch = {
        'filters_per_layer': 192,
        'layers': 12,
    }
    value = CNNValue(features, **arch)
    value.save_model(value_model)


def start_training():
    rvt.handle_arguments(cmd_line_args=[
        "train", value_weight, value_model, value_planes,
        "--minibatch", "16",
        "--epochs", "4",
        # "--train-val-test", "3",
        # "--max-validation", "3",
        "--verbose"
    ])

def resume_training(weight_RL):
    rvt.handle_arguments(cmd_line_args=[
        "resume", value_weight,
        "--weights", weight_RL,
        "--epochs", "10"
    ])


if __name__ == '__main__':
    flag = [True for _ in range(3)]
    if path.isfile(value_planes) or path.isfile(value_selfplay):
        print("value_planes or value_selfplay is exists. Can I execute generate_train_pair?")
        flag[0] = ask_yn()

    if path.isfile(value_model):
        print("value_model is exists. Can I execute create_model?")
        flag[1] = ask_yn()

    if path.isfile(value_weight):
        print("value_weight is exists. Can I execute start_training?")
        flag[2] = ask_yn()

    weight_SL = path.join(slpolicy_weight, "weights.00001.hdf5")
    weight_RL = path.join(rlpolicy_weight, "weights.00000.hdf5")

    features = [
        "board",
        "ones",
        "turns_since",
        "liberties",
        "capture_size",
        "self_atari_size",
        "liberties_after",
        "ladder_capture",
        "ladder_escape",
        "sensibleness",
        "color"
    ]

    if flag[0]: generate_train_pair(weight_RL, weight_SL, features)
    # if flag[0]: generate_sgf(weight_RL, weight_SL, features)
    # if flag[0]: generate_train_pair_from_sgf(weight_RL, weight_SL, features)

    if flag[1]: create_model(features)
    if flag[2]: start_training()
