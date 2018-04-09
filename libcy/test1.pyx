
from libcy.numeric cimport iota
from libcy.algorithm cimport IndexComp
from libcpp.vector cimport vector
from libcpp.algorithm cimport sort
from libc.stdio cimport printf

def comp():
    cdef:
        int i
        vector[double] v = [0.8, 0.7, 0.0, 0.6, 0.2, 0.9, 0.3, 0.1,  0.4, 0.5]
        vector[int] idx = [i for i in range(<int>v.size())]

    iota(idx.begin(), idx.end(), 0)
    sort(idx.begin(), idx.end(), IndexComp(v))

    for i in range(<int>v.size()):
        printf("%f\n", v[idx[i]])
