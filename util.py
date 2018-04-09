import os
from functools import wraps
import cProfile
import pstats
import matplotlib.pyplot as plt
import subprocess as sp


def ask_yn():
    yn_dict = {'y': True, 'yes': True, 'n': False, 'no': False}
    while True:
        inp = input('[Y]es/[N]o? >> ').lower()
        if inp in yn_dict:
            inp = yn_dict[inp]
            break
        print('Error! Input again.')

    return inp


def stopwatch(func) :
    @wraps(func)
    def wrapper(*args, **kargs):
        pr = cProfile.Profile()
        pr.enable()
        result = func(*args,**kargs)
        pr.disable()
        stats = pstats.Stats(pr)
        stats.sort_stats('time')
        stats.print_stats(20)
        return result

    return wrapper


def find_unique(name: str, ext: str, init: int=1) -> str:
    num = init

    while True:
        if 1 == num:
            filename = name + ext
        elif 2 <= num:
            filename = name + str(num) + ext
        else:
            raise ValueError(f"Can not use this number: {num}")

        if os.path.isfile(filename):
            num += 1
        else:
            return filename


def get_graph_saver(filename: str, title: str, xlabel: str, ylabel: str):
    def _save_graph(**lines: list):
        plt.figure()
        plt.title(title)
        plt.xlabel(xlabel)
        plt.ylabel(ylabel)
        plt.grid()

        for line in lines.values():
            plt.plot(line, marker='.')

        labels = list(lines.keys())
        plt.legend(labels, loc='upper left')

        name, ext = os.path.splitext(filename)
        if not ext == '':
            uniname = find_unique(name, ext)
            print(uniname)
            plt.savefig(uniname)
        else:
            raise NameError(f"Can not found extension.: {filename}")

    return _save_graph


def chunk_iter(it, n):
    it = iter(it)
    exhausted = [False]

    def subiter(it, n, exhausted):
        for i in range(n):
            try:
                yield next(it)
            except StopIteration:
                exhausted[0] = True
    while not exhausted[0]:
        yield subiter(it, n, exhausted)


def check_ext(ext: str):
    def _check(filename: str) -> bool:
        return os.path.splitext(filename)[1] == ext

    return _check


def find_file(ftype: str, directory: str='.', recurse: bool=True):
    ext = ftype if ftype.startswith('.') else '.' + ftype
    path = directory if not directory.endswith('/') else directory[:-1]
    cmd = ['find', path, '-type', 'f', '-name', f'*{ext}']

    if not recurse:
        cmd.extend(['-maxdepth', '1'])

    result = sp.Popen(cmd, stdout=sp.PIPE, encoding='utf-8')
    result.wait()

    while True:
        line = result.stdout.readline()
        if line == '':
            break

        yield line[:-1]