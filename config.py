
import os
from datetime import datetime

HOME = os.environ['HOME']
project_root = HOME + "Documents/PycharmProjects/alpha35/"

selfplay_dir = "data/selfplay/"
models_dir = "data/models/"
planes_dir = "data/planes/"
weights_dir = "data/weights/"
log_dir = "data/logs/"
ray_dir = "ray/"

model_info = "192filters_12layers"
dataset = "kgs"
dataset_dir = os.path.join('data', dataset)

slpolicy_info = '_'.join(['slpolicy', model_info, dataset])
slpolicy_planes = os.path.join(planes_dir, slpolicy_info + ".hdf5")
slpolicy_model = os.path.join(models_dir, slpolicy_info + ".json")
slpolicy_weight = os.path.join(weights_dir, slpolicy_info)

rlpolicy_info = "_".join(["rlpolicy", model_info, dataset])
rlpolicy_weight = os.path.join(weights_dir, rlpolicy_info)

value_info = '_'.join(['rlvalue', model_info, dataset])
value_selfplay = os.path.join(selfplay_dir, value_info)
value_planes = os.path.join(planes_dir, value_info + ".hdf5")
value_model = os.path.join(models_dir, value_info + ".json")
value_weight = os.path.join(weights_dir, value_info)
