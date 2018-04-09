
# mt19937 mt_state
# uniform_int_distribution[int] uniform
# uniform = uniform_int_distribution[int](0, RAND_MAX)
# uniform(self.mt_state)
cdef extern from "<random>" namespace "std":
    cdef cppclass mt19937_64:
        mt19937_64() except +
        mt19937_64(unsigned int) except +

    cdef cppclass uniform_int_distribution[T]:
        uniform_int_distribution()
        uniform_int_distribution(int, int)

    cdef cppclass uniform_real_distribution[T]:
        uniform_real_distribution()
        uniform_real_distribution(double, double)

