import os
import queue
import multiprocessing as mp
from apvmcts.tree import Tree
from ctypes import c_bool
from alphago.models.policy import CNNPolicy
from alphago.models.value import CNNValue
from config import (
    slpolicy_model, slpolicy_weight,
    value_model, value_weight
)



class ApvWorker(mp.Process):
    def __init__(self, apv_tree: Tree, pvque: mp.JoinableQueue,
                 rtque: mp.JoinableQueue, n_moves: int, using_hash: bool):

        super(ApvWorker, self).__init__()
        self._apv_tree = apv_tree
        self._pvque = pvque
        self._rtque = rtque
        self._using_hash = using_hash
        self._n_moves = n_moves
        self._skip_toggle = mp.Value(c_bool, False)

    def skip_on(self):
        self._skip_toggle.value = True

    def skip_off(self):
        self._skip_toggle.value = False

    def run(self):
        policy = CNNPolicy.load_model(slpolicy_model)
        policy.model.load_weights(os.path.join(slpolicy_weight, "weights.00001.hdf5"))
        value = CNNValue.load_model(value_model)
        value.model.load_weights(os.path.join(value_weight, "weights.00003.hdf5"))

        while True:
            if self._rtque.empty():
                try:
                    k = self._pvque.get(timeout=1)

                    if self._skip_toggle.value:
                        self._pvque.task_done()
                        continue

                    k['state'].current_player *= -1
                    v = value.eval_state(k['state'])
                    self._apv_tree.update_value(k['path'], v)
                    self._pvque.task_done()
                except queue.Empty:
                    continue
            else:
                k = self._rtque.get()
                state, ni, ci = k['state'], k['node_idx'], k['child_idx']
                current_hash = state.get_current_hash() if self._using_hash else None
                move_probs = policy.eval_state(state)
                self._apv_tree.expand(ni, ci, current_hash,
                                      self._n_moves, move_probs)

                self._rtque.task_done()


class PolicyWorker(mp.Process):
    def __init__(self, gpuid: int, apv_tree: Tree, queue: mp.JoinableQueue,
                 n_moves: int, using_hash: bool):

        super(PolicyWorker, self).__init__()
        self._gpuid = gpuid
        self._apv_tree = apv_tree
        self._queue = queue
        self._n_moves = n_moves
        self._using_hash = using_hash

    def run(self):

        #set enviornment
        os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID"
        os.environ["CUDA_VISIBLE_DEVICES"] = str(self._gpuid)


        policy = CNNPolicy.load_model(slpolicy_model)
        policy.model.load_weights(os.path.join(slpolicy_weight, "weights.00001.hdf5"))

        while True:
            k = self._queue.get()

            state, ni, ci = k['state'], k['node_idx'], k['child_idx']
            current_hash = state.get_current_hash() if self._using_hash else None
            move_probs = policy.eval_state(state)
            self._apv_tree.expand(ni, ci, current_hash,
                                  self._n_moves, move_probs)

            self._queue.task_done()


class ValueWorker(mp.Process):
    def __init__(self, gpuid: int, apv_tree: mp.JoinableQueue, queue: mp.JoinableQueue):
        super(ValueWorker, self).__init__()
        self._gpuid = gpuid
        self._apv_tree = apv_tree
        self._queue = queue
        self._skip_toggle = mp.Value(c_bool, False)

    def skip_on(self):
        self._skip_toggle.value = True

    def skip_off(self):
        self._skip_toggle.value = False

    def run(self):

        #set enviornment
        os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID"
        os.environ["CUDA_VISIBLE_DEVICES"] = str(self._gpuid)


        value = CNNValue.load_model(value_model)
        value.model.load_weights(os.path.join(value_weight, "weights.00003.hdf5"))

        while True:
            try:
                k = self._queue.get(timeout=1)

                if self._skip_toggle.value:
                    self._queue.task_done()
                    continue

                k['state'].current_player *= -1
                v = value.eval_state(k['state'])
                self._apv_tree.update_value(k['path'], v)
                self._queue.task_done()
            except queue.Empty:
                continue
