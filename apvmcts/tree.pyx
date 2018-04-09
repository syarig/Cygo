# cython: boundscheck=False
# cython: wraparound=False
# cython: cdivision=True

import threading

from libc.stdio cimport printf
from libc.math cimport sqrt
from libcpp.vector cimport vector
from libcpp.algorithm cimport sort
from libcy.algorithm cimport min as cmin
from libcy.algorithm cimport IndexComp
from libcy.numeric cimport iota

(
    PARENT_OF_ROOT,
    NODE_NOT_FOUND,
    NODE_EMPTY,
) = range(-1, -4, -1)

cdef:
    long _PARENT_OF_ROOT = PARENT_OF_ROOT
    long _NODE_NOT_FOUND = NODE_NOT_FOUND
    long _NODE_EMPTY = NODE_EMPTY
    long N_VL = 1
    long C_PUCT = 5

cdef class PyChild:
    pass

cdef class Child:
    pass

cdef class Node:
    def __init__(self, child_max):
        self.children = [Child() for _ in range(child_max)]

cdef class Tree:
    def __init__(self, lambda_val: float, node_max: int, child_max: int):
        self.current_node_idx = 0
        self.node_max = node_max
        self.lambda_val = lambda_val
        self.hash_dict = {}
        self.hash_list = [None for _ in range(node_max)]
        self.nodes = [Node(child_max) for _ in range(node_max)]
        self.nlocks = [threading.Lock() for _ in range(node_max)]
        self.elock = threading.Lock()

    def lock_expand(self):
        self.elock.acquire()

    def unlock_expand(self):
        self.elock.release()

    def lock_node(self, long ni):
        self.nlocks[ni].acquire()

    def unlock_node(self, long ni):
        self.nlocks[ni].release()

    def clear(self):
        self.current_node_idx = 0
        self.hash_dict.clear()

    def check_expanded(self, long pni, long pci, tuple ch):
        cdef Node n
        ni = self.hash_dict.get(ch, _NODE_NOT_FOUND)
        if ni != _NODE_NOT_FOUND:
            n = self.nodes[ni]
            n.pni = pni
            n.pci = pci

        return ni

    def ready(self, tuple ch):
        cdef Node n
        ni = self.hash_dict.get(ch, _NODE_NOT_FOUND)
        if ni != _NODE_NOT_FOUND:
            n = self.nodes[ni]
            n.pni = _PARENT_OF_ROOT
            n.pci = _PARENT_OF_ROOT

        return ni


    def set_child(self, long ni, long ci, dict values):
        cdef Child c = self.nodes[ni].children[ci]
        c.next = values.get('next', c.next)

    def set_node(self, long ni, dict values):
        n = self.nodes[ni]
        n.pni = values.get('pni', n.pni)
        n.pci = values.get('pci', n.pci)

    def get_path(self, long ni, long ci):
        cdef:
            Node n = self.nodes[ni]
            long pni = n.pni
            long pci = n.pci
            list path = [(ni, ci)]

        while pni != PARENT_OF_ROOT and pci != PARENT_OF_ROOT:
            n = self.nodes[pni]
            path.append((pni, pci))
            pni, pci = n.pni, n.pci

        return path

    cdef PyChild get_child(self, Child c):
        cdef PyChild pc = PyChild()
        pc.idx = c.idx
        pc.x = c.x
        pc.y = c.y
        pc.P = c.P
        pc.Q = c.Q
        pc.R = c.R
        pc.next = c.next
        pc.Nr = c.Nr.load()
        pc.Wr = c.Wr.load()
        pc.Nv = c.Nv.load()
        pc.Wv = c.Wv.load()
        return pc

    def set_current_node_idx(self, long num):
        self.current_node_idx = num

    def update_virtual_loss(self, long ni, long ci, long col):
        cdef:
            Node n = self.nodes[ni]
            Child c = n.children[ci]
        c.Nr.fetch_add(N_VL)
        c.Wr.fetch_add(N_VL * (1 - col))
        n.Nr_sum.fetch_add(N_VL)
        c.R = self.lambda_val * c.Wr.load() / c.Nr.load()

    def update_rollout(self, long ni, long ci, long col, long z):
        cdef:
            Node n = self.nodes[ni]
            Child c = n.children[ci]
        c.Nr.fetch_add(1 - N_VL)
        c.Wr.fetch_add(z - N_VL * (1 - col))
        n.Nr_sum.fetch_add(1 - N_VL)
        c.R = self.lambda_val * c.Wr.load() / c.Nr.load()

    def update_value(self, list path, double v):
        cdef:
            Node n
            Child c
            long ni, ci

        for ni, ci in path:
            n = self.nodes[ni]
            c = n.children[ci]
            c.Nv.fetch_add(1)
            expected = c.Wv.load()
            while not c.Wv.compare_exchange_weak(expected, expected + v):
                pass
            c.Q = (1 - self.lambda_val) * c.Wv.load() / c.Nv.load()


    def select_games(self, long ni):
        cdef:
            Node n = self.nodes[ni]
            Child c
            long max_games = -999
            long ci, selected = -1

        for ci in range(n.child_num):
            c = n.children[ci]
            if c.Nr.load() > max_games:
                max_games = c.Nr.load()
                selected = ci

        return self.get_child(n.children[selected])

    def select_value(self, long ni):
        cdef:
            Node n = self.nodes[ni]
            Child c
            double max_value = -999
            long ci, selected = -1
            double u, value

        for i in range(cmin(n.width, n.child_num)):
            ci = n.sorted_ci[i]
            c = n.children[ci]

            u = C_PUCT * c.P * sqrt(n.Nr_sum.load()) / (1 + c.Nr.load())

            value = c.Q + c.R + u
            if value > max_value:
                max_value = value
                selected = ci

        return self.get_child(n.children[selected])

    def get_next_node_idx(self):
        return self.current_node_idx - 1

    def prepare_next_node(self, long ni, long ci):
        cdef:
            long next_ni = self.current_node_idx - 1
            Node n = self.nodes[ni]
            Child c = n.children[ci]
        c.next = next_ni
        return next_ni

    cdef add_child(self, long ni, long x, long y, double prior_p):
        cdef:
            Node n = self.nodes[ni]
            long ci = n.child_num
            Child c = n.children[ci]
        c.idx = ci
        c.x = x
        c.y = y
        c.Nr.store(0)
        c.Wr.store(0)
        c.Nv.store(0)
        c.Wv.store(0)
        c.P = prior_p
        c.Q = 0.0
        c.R = 0.0
        c.next = _NODE_EMPTY
        n.child_num += 1

    def expand(self, long pni, long pci, tuple ch, long num, object move_probs):
        if self.current_node_idx >= self.node_max:
            self.current_node_idx = 0

        cdef:
            vector[double] v
            long ni = self.current_node_idx
            Node n = self.nodes[ni]
            Child c
            tuple m
            double prob

        n.child_num = 0
        n.Nr_sum.store(0)
        n.pni = pni
        n.pci = pci
        n.width = num

        self.hash_dict.pop(self.hash_list[ni], -1)
        self.hash_dict[ch] = ni
        self.hash_list[ni] = ch

        for m, prob in move_probs:
            self.add_child(ni, m[0]+1, m[1]+1, prob)

        # self.add_child(ni, 0, 0, 0.0)

        for ci in range(n.child_num):
            c = n.children[ci]
            v.push_back(c.P)
        n.sorted_ci = vector[long](v.size())
        iota(n.sorted_ci.begin(), n.sorted_ci.end(), 0)
        sort(n.sorted_ci.begin(), n.sorted_ci.end(), IndexComp(v))

        self.current_node_idx += 1

    def print_nodes(self, num):
        for i, n in enumerate(self.nodes):
            print("id: {} | width: {} | nrSum: {} | pni: {} | pci: {}".format(
                i, n.width, n.Nr_sum.load(), n.pni, n.pci
            ))
            if i == num: break

    def print_children(self, long ni):
        cdef:
            Node n = self.nodes[ni]
            Child c
        for ci in range(n.child_num):
            c = n.children[ci]

            printf("(%ld, %ld) | Nr: %ld | P: %lf | next: %ld\n",
                   c.x, c.y, c.Nr.load(), c.P, c.next)

