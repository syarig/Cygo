from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

cdef struct Bicycle:
    int gears
    double price
    short *ary

cdef class MyClass:
    cdef Bicycle *_data
    cdef long size

    def __init__(self):
        print('MyClass.__init__')

    cpdef dict get_data(self):
        """Serializes array to a bytes object"""
        if self._data == NULL:
            return None
        return {
            'data': self.data,
            'ary': <bytes>(<char *>self._data[0].ary)[:sizeof(short) * self.size]
        }

    cpdef void set_data(self, dict k, long size):
        """Deserializes a bytes object to an array"""
        free(self._data)
        self.size = size
        self.data = k['data']
        self._data[0].ary = <short*>malloc(sizeof(short) * self.size)
        if not self._data:
            raise MemoryError()
        memcpy(self._data[0].ary, <char *>k['ary'], sizeof(short) * self.size)

    property ary:
        def __get__(self):
            return [self._data[0].ary[i] for i in range(0, self.size)]

    property data:
        """Python interface to array"""
        def __get__(self):
            return [(self._data[i].gears, self._data[i].price) for i in range(0, self.size)]
        def __set__(self, values):
            self.size = len(values)
            self._data = <Bicycle*>malloc(sizeof(Bicycle) * self.size)
            self._data[0].ary = <short*>malloc(sizeof(short) * self.size)
            if not self._data:
                raise MemoryError()
            for i, (gears, price) in enumerate(values):
                self._data[i].gears = gears
                self._data[i].price = price
                self._data[0].ary[i] = gears

    def __getstate__(self):
        return (self.get_data(), self.size)

    def __setstate__(self, state):
        self.set_data(*state)

    def __dealloc__(self):
        free(self._data)

"""
from libcy import test
import pickle
mc = test.MyClass()
mc.data = [(1, 2), (3, 4), (5, 8)]
with open('mc.pkl', 'wb') as f:
    pickle.dump(mc, f)
    
import pickle
with open('mc.pkl', 'rb') as f:
    mc = pickle.load(f)
"""

