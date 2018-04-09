cdef extern from "<atomic>" namespace "std" nogil:
    cdef cppclass atomic[T]:
        atomic() except +
        T load() const
        void store(T)
        T fetch_add(T)
        T fetch_sub(T)
        bint compare_exchange_weak(T, T)

