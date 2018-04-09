"""
This is a search worker. This algorithm is based on AlphaGo, But not the same.
I have make a some adjustments to algorithm for small resources.
"""

import gtp
from alphago import go
import multiprocessing as mp
from apvmcts import tree

from apvmcts.tree import Tree
from ray.wrapper import Ray
from typing import Optional, Tuple


def conv_pos(vertex: Tuple[int, int]):
    x, y = vertex
    return go.PASS if vertex == gtp.PASS else (x-1, y-1)

def conv_col(col: int):
    return col if col == go.BLACK else go.WHITE

def flip_color(col: int):
    return 3 - col

class SearchWorker(mp.Process):
    def __init__(self, apv_tree: Tree,
                 pvque: mp.JoinableQueue,
                 rtque: mp.JoinableQueue,
                 procque: mp.JoinableQueue,
                 ray: Ray,
                 tid: int,
                 nlocks: mp.Lock,
                 elock: mp.Lock,
                 expand_thr: int,
                 loops: int,
                 using_hash: bool):

        super(SearchWorker, self).__init__()
        self._apv_tree = apv_tree
        self._pvque = pvque
        self._rtque = rtque
        self._procque = procque
        self._ray = ray
        self._tid = tid
        self._nlocks = nlocks
        self._elock = elock
        self._expand_thr = expand_thr
        self._loops = loops
        self.func = self.search_hash if using_hash else self.search

    def search(self, po_state: go.GameState, col: int, ni: int,
               root_col: int, path: Optional[list]=None):

        if path is None:
            path = []

        self._nlocks[ni].acquire()
        c = self._apv_tree.select_value(ni)

        path.append((ni, c.idx))

        po_state.do_move(conv_pos((c.x, c.y)), conv_col(col))
        self._ray.put_stone(c.x, c.y, col, tid=self._tid, playout=True)

        un_col = flip_color(col)
        if c.Nr < self._expand_thr:
            self._apv_tree.update_virtual_loss(ni, c.idx, col)

            self._nlocks[ni].release()

            if c.Nv == 0:
                kwargs = {'state': po_state,
                          'path': path}
                self._pvque.put(kwargs)

            z = -self._ray.playout(un_col, root_col, self._tid)
        else:
            self._apv_tree.update_virtual_loss(ni, c.idx, col)

            if c.next == tree.NODE_EMPTY:
                self._elock.acquire()

                kwargs = {'state': po_state,
                          'node_idx': ni,
                          'child_idx': c.idx}
                self._rtque.put(kwargs)
                self._rtque.join()
                c.next = self._apv_tree.prepare_next_node(ni, c.idx)

                self._elock.release()

            self._nlocks[ni].release()
            z = -self.search(po_state, un_col, c.next, root_col, path)

        self._apv_tree.update_rollout(ni, c.idx, col, z)
        return z

    def search_hash(self, po_state: go.GameState, col: int, ni: int,
                    root_col: int, path: Optional[list]=None):

        if path is None:
            path = []

        self._nlocks[ni].acquire()
        c = self._apv_tree.select_value(ni)

        path.append((ni, c.idx))

        po_state.do_move(conv_pos((c.x, c.y)), conv_col(col))
        self._ray.put_stone(c.x, c.y, col, tid=self._tid, playout=True)

        un_col = flip_color(col)
        if c.Nr < self._expand_thr:
            self._apv_tree.update_virtual_loss(ni, c.idx, col)

            self._nlocks[ni].release()

            if c.Nv == 0:
                kwargs = {'state': po_state,
                          'path': path}
                self._pvque.put(kwargs)

            z = -self._ray.playout(un_col, root_col, self._tid)
        else:
            self._apv_tree.update_virtual_loss(ni, c.idx, col)

            if c.next == tree.NODE_EMPTY:
                self._elock.acquire()

                c.next = self._apv_tree.check_expanded(ni, c.idx, po_state.get_current_hash())
                if c.next == tree.NODE_NOT_FOUND:
                    kwargs = {'state': po_state,
                              'node_idx': ni,
                              'child_idx': c.idx}
                    self._rtque.put(kwargs)
                    self._rtque.join()
                    c.next = self._apv_tree.prepare_next_node(ni, c.idx)
                # else:
                #     print("{} node has already expanded.".format(c.next))

                self._elock.release()

            self._nlocks[ni].release()
            z = -self.search(po_state, un_col, c.next, root_col, path)

        self._apv_tree.update_rollout(ni, c.idx, col, z)
        return z

    def run(self):
        while True:
            state, root_col, ni = self._procque.get()
            self._ray.alloc_po_game(self._tid)

            for i in range(self._loops):
                po_state = state.copy()
                self._ray.copy_game(self._tid)
                self.func(po_state, root_col, ni, root_col)

            self._ray.free_po_game(self._tid)
            self._procque.task_done()
