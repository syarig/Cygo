from libcpp.vector cimport vector

cdef extern from "<algorithm>" namespace "std" nogil:
    T max[T](T a, T b)
    T min[T](T a, T b)

cdef extern from "src/index_sort.h" nogil:
    cppclass IndexComp:
        IndexComp(vector[double] _v)


