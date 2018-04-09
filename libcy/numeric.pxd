cdef extern from "<numeric>" namespace "std" nogil:
    void iota[ForwardIterator, T](ForwardIterator first, ForwardIterator last, T value)
