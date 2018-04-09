cdef extern from "<mutex>" namespace "std" nogil:
    cdef cppclass mutex:
        void lock()
        bint try_lock()
        void unlock()

    cdef cppclass lock_guard[T]
