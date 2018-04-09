import os
import shutil
from alphago.training.reinforcement_policy_trainer import run_training
from config import slpolicy_model, slpolicy_weight, rlpolicy_weight
from util import ask_yn


def learn_weights(weight_SL):
    run_training(cmd_line_args=[
        slpolicy_model,
        weight_SL,
        rlpolicy_weight,
        "--save-every", "500",
        "--game-batch", "128",
        "--iterations", "10000",
        "--record-every", "50",
        "--move-limit", "400",
        "--verbose",
    ])


def resume_learning(weight_RL):
    run_training(cmd_line_args=[
        slpolicy_model,
        weight_RL,
        rlpolicy_weight,
        # "--save-every", "500",
        # "--game-batch", "20",
        # "--iterations", "10000",
        "--save-every", "100",
        "--game-batch", "1",
        "--iterations", "2",
        "--resume",
        "--verbose",
    ])


if __name__ == '__main__':
    flag = True
    if os.path.isdir(rlpolicy_weight):
        print("rlpolicy_weight is exists. Can I execute learn_weights?")
        flag = ask_yn()

    weight_SL = os.path.join(slpolicy_weight, "weights.00001.hdf5")
    if flag: learn_weights(weight_SL)
