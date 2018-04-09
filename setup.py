import os
from Cython.Build import cythonize
from setuptools import setup, Extension
import numpy as np

os.environ["CC"] = "g++-6"
os.environ["CXX"] = "g++-6"

ray_src = [
    "ray/wrapper.pyx",
    "ray/src/DynamicKomi.cpp",
    "ray/src/GoBoard.cpp",
    "ray/src/Gtp.cpp",
    "ray/src/Ladder.cpp",
    "ray/src/Message.cpp",
    "ray/src/Nakade.cpp",
    "ray/src/Pattern.cpp",
    "ray/src/PatternHash.cpp",
    "ray/src/Playout.cpp",
    "ray/src/Point.cpp",
    "ray/src/Rating.cpp",
    "ray/src/Semeai.cpp",
    "ray/src/Simulation.cpp",
    "ray/src/UctRating.cpp",
    "ray/src/UctSearch.cpp",
    "ray/src/Utility.cpp",
    "ray/src/ZobristHash.cpp",
]


extensions = [
    Extension(
        'alphago.go',
        sources=["alphago/go.pyx"],
        language="c++",
        include_dirs=[np.get_include()]
    ),
    Extension(
        'alphago.ai',
        sources=["alphago/ai.pyx"],
    ),
    Extension(
        'alphago.util',
        sources=["alphago/util.pyx"],
    ),
    Extension(
        'alphago.training.reinforcement_policy_trainer',
        sources=["alphago/training/reinforcement_policy_trainer.pyx"],
    ),
    Extension(
        'alphago.preprocessing.game_converter',
        sources=["alphago/preprocessing/game_converter.pyx"],
    ),
    Extension(
        'alphago.preprocessing.genarate_value_training',
        sources=["alphago/preprocessing/genarate_value_training.pyx"],
    ),
    Extension(
        'alphago.preprocessing.preprocessing',
        sources=["alphago/preprocessing/preprocessing.pyx"],
    ),
    Extension(
        'ray.wrapper',
        sources=ray_src,
        language="c++",
        extra_compile_args=["-std=c++11"],
        extra_link_args=["-std=c++11"]
    ),
    Extension(
        'apvmcts.player',
        sources=["apvmcts/player.pyx"],
        language="c++",
        extra_compile_args=["-std=c++11"],
        extra_link_args=["-std=c++11"]
    ),
    Extension(
        'apvmcts.gpu_workers',
        sources=["apvmcts/gpu_workers.pyx"],
        language="c++",
        extra_compile_args=["-std=c++11"],
        extra_link_args=["-std=c++11"]
    ),
    Extension(
        'apvmcts.search_worker',
        sources=["apvmcts/search_worker.pyx"],
        language="c++",
        extra_compile_args=["-std=c++11"],
        extra_link_args=["-std=c++11"]
    ),
    Extension(
        'apvmcts.tree',
        sources=["apvmcts/tree.pyx"],
        language="c++",
        extra_compile_args=["-std=c++11"],
        extra_link_args=["-std=c++11"]
    ),
]

setup(
    name='Cygo',
    version='1.0',
    description='Go AI based on deep neural networks and tree search',
    author='syarig',
    author_email='syarig110@yahoo.co.jp',
    url='https://github.com/syarig/Cygo',
    ext_modules=cythonize(extensions),
)