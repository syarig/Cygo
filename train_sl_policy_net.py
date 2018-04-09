# coding:utf-8
from os import path, makedirs
from shutil import rmtree

from config import slpolicy_weight, slpolicy_model, slpolicy_planes, dataset_dir
from util import ask_yn


def sgf_to_tensor(features):
    from alphago.preprocessing.game_converter import run_game_converter
    run_game_converter([
        "-f", ','.join(features),
        "-o", slpolicy_planes,
        "-R",
        "-d", dataset_dir,
        # "-s", "19",
        "--verbose"
    ])


def create_model(features):
    from alphago.models.policy import CNNPolicy
    arch = {'filters_per_layer': 192, 'layers': 12}  # args to CNNPolicy.create_network()
    policy = CNNPolicy(features, **arch)
    policy.save_model(slpolicy_model)


def learn_weights():
    import alphago.training.supervised_policy_trainer as spt
    spt.handle_arguments(cmd_line_args=[
        "train",
        slpolicy_weight,
        slpolicy_model,
        slpolicy_planes,
        "--epochs", "2",
        # "--minibatch", "16",
        "--minibatch", "1",
        "--verbose",
    ])

def resume_learning():
    import alphago.training.supervised_policy_trainer as spt
    spt.handle_arguments(cmd_line_args=[
        "resume",
        slpolicy_weight,
        "--epochs", "10",
        "--verbose"
    ])


if __name__ == '__main__':
    flag = [True for _ in range(3)]
    if path.isfile(slpolicy_planes):
        print("slpolicy_planes is exists. Can I execute sgf_to_tensor?")
        flag[0] = ask_yn()

    if path.isfile(slpolicy_model):
        print("slpolicy_model is exists. Can I execute create_model?")
        flag[1] = ask_yn()

    if path.isdir(slpolicy_weight):
        print("slpolicy_weight is exists. Can I execute learn_weights?")
        flag[2] = ask_yn()

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
        "zeros"
    ]

    if flag[0]: sgf_to_tensor(features)
    if flag[1]: create_model(features)
    if flag[2]: learn_weights()
    # if flag[2]: resume_learning()
