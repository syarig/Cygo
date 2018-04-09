from libcy.atomic cimport atomic
from libcpp.vector cimport vector

cdef:
    long _PARENT_OF_ROOT
    long _NODE_NOT_FOUND
    long _NODE_EMPTY

cdef class PyChild:
    cdef:
        public long idx, x, y
        public double P, Q, R
        public long next
        public long Nr, Wr, Nv
        public double Wv

cdef class Child:
    cdef:
        long idx, x, y
        double P, Q, R
        long next
        atomic[long] Nr, Wr, Nv
        atomic[double] Wv

cdef class Node:
    cdef:
        long child_num
        long width
        list children
        list locks
        vector[long] sorted_ci
        long pni, pci
        atomic[long] Nr_sum

cdef class Tree:
    cdef:
        long current_node_idx
        long node_max
        float lambda_val
        dict hash_dict
        list hash_list
        list nodes, nlocks
        object elock

    cdef PyChild get_child(self, Child c)

    cdef add_child(self, long ni, long x, long y, double prior_p)

