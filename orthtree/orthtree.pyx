# cython: language_level=3, cdivision=True


import cython
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.ref cimport PyObject, Py_XINCREF, Py_XDECREF

# This is the struct in which the objects inserted into the tree get stored
cdef struct container:
    PyObject* item
    double *pos

# This the the struct representing an individual nodes of the tree.
# The nodes are named tree and subnodes subtree because of bad naming. Might eventually fix it.
# The subtree pointer gets initialized to none until a tree needs to split.
cdef struct tree:
    tree *subtree
    container *bucket
    double *pos1
    double *pos2
    int number_of_elements


cdef bint is_within(int num_dims, double* position_1, double* position_2, double* position):
    # This function is a fast method to compute if a given point is within a bounding rectangular
    # hypervolume given by two other points.
    cdef int i
    cdef double a, b, p

    for i in range(num_dims):
        a = position_1[i]
        b = position_2[i]
        p = position[i]

        if a >= p >= b:
            continue
        elif b >= p >= a:
            continue
        else:
            return False
    return True

cdef void clean_up(tree* parent_ptr, int children):
    # Function which recursively frees up the memory used by a tree.
    cdef int i

    # First we free up pos2, our parent caller cleans pos1.
    PyMem_Free(parent_ptr[0].pos2)

    # Then we free any elements which may be in the tree's bucket.
    for i in range(parent_ptr[0].number_of_elements):
        Py_XDECREF(parent_ptr[0].bucket[i].item)
        PyMem_Free(parent_ptr[0].bucket[i].pos)

    # Free up the bucket itself!
    PyMem_Free(parent_ptr[0].bucket)

    # Recursively cleanup any children!
    if parent_ptr[0].subtree:
        for i in range(children):
            clean_up(&(parent_ptr[0].subtree[i]), children)

        # Then clean up the children themselves and the pos1 which they all share.
        PyMem_Free(parent_ptr[0].subtree[0].pos1)
        PyMem_Free(parent_ptr[0].subtree)


cdef bint subdivide(int num_dims, int bucket_size, tree* parent_ptr):
    # Subdivision function
    # May raise memory errors, but it will prevent leaks by clever handling.
    cdef int i, j
    cdef int number_of_children = 1 << num_dims
    cdef container *bucket
    cdef double *pos1
    cdef double *pos2
    cdef tree* subtree

    # Do not re-subdivide trees, the demons will come out!
    # This should never actually evaluate to true, any modern CPU will simply branch predict over it, so its entirely
    # free.
    if parent_ptr[0].subtree:
        return False

    # Allocating the array of tree structs, setting is done later in case we memory error.
    subtree = <tree*>PyMem_Malloc(sizeof(tree) * number_of_children)
    if not subtree:
        raise MemoryError('could not allocate memory for subtrees')

    # All subtrees share a single pos1, parent trees are responsible for cleaning it.
    pos1 = <double*>PyMem_Malloc(sizeof(double) * num_dims)
    if not pos1:
        PyMem_Free(subtree)
        raise MemoryError('could not allocate memory for midpoint')

    # pos1 is actually just the average of the two points of the tree
    for i in range(num_dims):
        pos1[i] = (parent_ptr[0].pos1[i] + parent_ptr[0].pos2[i]) / 2

    # This is the loop in which each of the children are initialized, 5 things need to be done!
    # If this memory errors it does some very clever handling to free up the mess it has made.
    for i in range(number_of_children):
        # First we set the sub subtrees to point to NULL.
        # And they also initially contain nothing.
        subtree[i].subtree = NULL
        subtree[i].number_of_elements = 0

        # Allocate the struct of containers: the bucket.
        bucket = <container*>PyMem_Malloc(sizeof(container) * bucket_size)
        if not bucket:
            # Clean up memory then raise an exception
            PyMem_Free(pos1)
            for j in range(i):
                PyMem_Free(subtree[j].bucket)
                PyMem_Free(subtree[j].pos2)
            PyMem_Free(subtree)
            raise MemoryError('could not allocate memory for subtree')

        # Allocate an array for pos2
        pos2 = <double*>PyMem_Malloc(sizeof(double) * num_dims)
        if not pos2:
            # Clean up memory then raise an exception, including bucket.
            PyMem_Free(bucket)
            PyMem_Free(pos1)
            for j in range(i):
                PyMem_Free(subtree[j].bucket)
                PyMem_Free(subtree[j].pos2)
            PyMem_Free(subtree)
            raise MemoryError('could not allocate memory for subtree')

        subtree[i].bucket = bucket
        subtree[i].pos1 = pos1
        subtree[i].pos2 = pos2

        # Computing the position of each child!
        for j in range(num_dims):
            # The second point on the child trees is actually every combination you can make choosing coordinates
            # From pos1 or pos2 of the parent.
            # Because its a binary choice we use a binary counter for this.
            # The i'th child's pos2's j'th bit is equal to the j'th bit of the parent's pos 1 or pos2 depending on if
            # the j'th bit of i in binary is a 0 or a 1.
            # Word explanation but it makes sense as an example.
            #
            # Consider the 5th child of a octree (3D), i = 5 -> 101
            # Its pos2 would then be (parent_pos2[0], parent_pos1[1], parent_pos2[2])
            # Because the 0th bit of 5 is 1, 1st is 0 and 2nd is 1. ( Read right-to-left)

            if i & (1 << j):
                pos2[j] = parent_ptr[0].pos1[j]
            else:
                pos2[j] = parent_ptr[0].pos2[j]

    # Now that the subtree has been completely created we may actually set it.
    parent_ptr[0].subtree = subtree
    return True


cdef bint insert_object(tree* parent_ptr, int bucket_size, int num_dims, double* pos, PyObject* item):
    # Insert function calls this function. This does the work of actually inserting the item.
    cdef int i
    cdef int number_of_children = 1 << num_dims

    # First we check if it is within this tree!
    if not is_within(num_dims, parent_ptr[0].pos1, parent_ptr[0].pos2, pos):
        return False

    # If the parent has space add it and return
    if parent_ptr[0].number_of_elements < bucket_size:
        parent_ptr[0].bucket[parent_ptr[0].number_of_elements].item = item
        parent_ptr[0].bucket[parent_ptr[0].number_of_elements].pos = pos
        parent_ptr[0].number_of_elements += 1
        return True

    # No space, need to subdivide
    # If subdivide fails the python method will handle freeing pos.
    subdivide(num_dims, bucket_size, parent_ptr)

    for i in range(number_of_children):
        if insert_object(&(parent_ptr[0].subtree[i]), bucket_size, num_dims, pos, item):
            return True

    # We shouldn't ever arrive here, the point must be inside one of the children.
    raise AttributeError('could not insert item into tree')


cdef void complete_grab(list query_results, tree* parent_ptr, int number_of_children):
    # Complete acceptance function, skips all of the faff, this is the secret sauce to the speed.
    cdef int i

    # Grab every item in tree
    for i in range(parent_ptr[0].number_of_elements):
        query_results.append(<object>parent_ptr[0].bucket[i].item)

    # complete_grab every child of tree
    if parent_ptr.subtree:
        for i in range(number_of_children):
            complete_grab(query_results, &(parent_ptr[0].subtree[i]), number_of_children)


cdef void query(list query_results, int num_dims, int number_of_children, tree* parent_ptr, double* pos1, double* pos2):
    # Query Function, finds all points inside bounding box, number of children needs to be passed to avoid
    # Recomputing it each time, probably a premature optimization but whatever.
    cdef bint a, b
    cdef int i

    # First we check if both corners of the tree are within q, if this is true we can do a complete grab
    a = is_within(num_dims, pos1, pos2, parent_ptr[0].pos1)
    b = is_within(num_dims, pos1, pos2, parent_ptr[0].pos2)

    if a or b:
        if a & b:
            # Completely withing the bounding box
            complete_grab(query_results, parent_ptr, number_of_children)
        else:
            # Partial overlap with bounding box, check more slowly and verify for each object.
            for i in range(parent_ptr[0].number_of_elements):
                if is_within(num_dims, pos1, pos2, parent_ptr[0].bucket[i].pos):
                    query_results.append(<object>parent_ptr[0].bucket[i].item)

            # Recursively do the same for each child
            if parent_ptr[0].subtree:
                for i in range(number_of_children):
                    query(query_results, num_dims, number_of_children, &(parent_ptr[0].subtree[i]), pos1, pos2)

    # Neither points of the tree are within the query box, but the query box may still intersect the tree still.
    # An example of this is the query box being entirely within the tree.
    # This is the exact same check as the one for if one of the tree points is within the query box.
    else:
        a = is_within(num_dims, parent_ptr[0].pos1, parent_ptr[0].pos2, pos1)
        b = is_within(num_dims, parent_ptr[0].pos1, parent_ptr[0].pos2, pos2)
        if a or b:
            for i in range(parent_ptr[0].number_of_elements):
                if is_within(num_dims, pos1, pos2, parent_ptr[0].bucket[i].pos):
                    query_results.append(<object>parent_ptr[0].bucket[i].item)

            if parent_ptr[0].subtree:
                for i in range(number_of_children):
                    query(query_results, num_dims, number_of_children, &(parent_ptr[0].subtree[i]), pos1, pos2)
    return


# This class is just a holder which makes __iter__ work. Hidden by the decorator.
@cython.internal
cdef class TreePointer:
    cdef tree* ptr


cdef class Orthtree:
    """
    N-Dimensional Orthtree
    """
    cdef tree root
    cdef readonly int number_of_objects, number_of_dims, bucket_size
    cdef readonly tuple position_1, position_2

    def __init__(self, position_1, position_2, bucket_size = 8):
        cdef tuple tuple_position_1 = tuple(position_1)
        cdef tuple tuple_position_2 = tuple(position_2)
        cdef int i

        cdef double* pos1
        cdef double* pos2
        cdef container* bucket

        self.number_of_dims = len(tuple_position_1)
        self.number_of_objects = 0
        self.position_1 = tuple_position_1
        self.position_2 = tuple_position_2

        if len(tuple_position_1) != len(tuple_position_2):
            raise SyntaxError('dimensions of arguments are mismatched!')

        self.bucket_size = int(bucket_size)
        if self.bucket_size < 1:
            raise IndexError('bucket size must be greater than 0')

        # Beyond here we are actually creating the root tree struct!
        # Note that the subtrees array isn't allocated until needed!

        pos1 = <double*>PyMem_Malloc(sizeof(double) * self.number_of_dims)
        if not pos1:
            raise MemoryError('could not allocate memory for tree')

        pos2 = <double*>PyMem_Malloc(sizeof(double) * self.number_of_dims)
        if not pos2:
            PyMem_Free(pos1)
            raise MemoryError('could not allocate memory for tree')

        bucket = <container*>PyMem_Malloc(sizeof(container) * self.bucket_size)
        if not bucket:
            PyMem_Free(pos1)
            PyMem_Free(pos2)
            raise MemoryError('could not allocate memory for tree')

        # 5 Things need to be set whenever a subtree is created.
        self.root.subtree = NULL
        self.root.bucket = bucket
        self.root.pos1 = pos1
        self.root.pos2 = pos2
        self.root.number_of_elements = 0

        for i in range(self.number_of_dims):
            self.root.pos1[i] = float(tuple_position_1[i])
            self.root.pos2[i] = float(tuple_position_2[i])

    def __dealloc__(self):
        cdef int number_of_children = 1 << self.number_of_dims
        # Clean up the entire hierarchy, all except root's pos1
        clean_up(&(self.root), number_of_children)
        PyMem_Free(self.root.pos1)

    def insert(self, item, position):
        # Insert an item with a given position into the tree
        cdef PyObject* item_ptr = <PyObject*>item
        cdef tuple tuple_position = tuple(position)
        cdef double* pos
        cdef int i

        if len(tuple_position) != self.number_of_dims:
            raise IndexError('invalid position')

        pos = <double*>PyMem_Malloc(sizeof(double) * self.number_of_dims)
        if not pos:
            raise MemoryError('could not allocate space for position')

        for i in range(self.number_of_dims):
            pos[i] = float(position[i])

        # Calling our handy dandy C function to inset it into the tree!
        try:
            if insert_object(&(self.root), self.bucket_size, self.number_of_dims, pos, item_ptr):
                self.number_of_objects += 1
                Py_XINCREF(item_ptr)
                return True
            else:
                return False
        except(MemoryError, AttributeError):
            # In this case pos has not been stored, so it needs to be cleaned!
            PyMem_Free(pos)
            raise Exception

    def to_list(self):
        # Very simple method, returns all elements in the tree.
        # much faster than calling list() with the tree as an object.
        cdef list query_results = []
        cdef int number_of_children = 1 << self.number_of_dims
        complete_grab(query_results, &self.root, number_of_children)
        return query_results

    def __iter__(self):
        # Fancy generator of sorts.
        cdef int number_of_children = 1 << self.number_of_dims

        def recursive_yielding_generator(TreePointer pointer):
            cdef int i
            cdef TreePointer child_pointer
            for i in range(pointer.ptr[0].number_of_elements):
                yield <object>pointer.ptr[0].bucket[i].item

            if pointer.ptr[0].subtree:
                for i in range(number_of_children):
                    child_pointer = TreePointer()
                    child_pointer.ptr = &(pointer.ptr[0].subtree[i])
                    yield from recursive_yielding_generator(child_pointer)

        cdef TreePointer root = TreePointer()
        root.ptr = &(self.root)
        yield from recursive_yielding_generator(root)

    def query(self, position_1, position_2):
        # Very fast method which returns objects in a list which are inside the bounding box given by position_1
        # and position_2
        cdef tuple list_position_1 = tuple(position_1)
        cdef tuple list_position_2 = tuple(position_2)
        cdef double* pos1
        cdef double* pos2
        cdef list query_results = []
        cdef int i, number_of_children = 1 << self.number_of_dims

        if len(list_position_1) != len(list_position_2):
            raise IndexError('invalid position(s)')
        if len(list_position_1) != self.number_of_dims:
            raise IndexError('invalid position(s)')

        pos1 = <double*>PyMem_Malloc(sizeof(double) * self.number_of_dims)
        if not pos1:
            raise MemoryError('could not allocate memory for positions')

        pos2 = <double*>PyMem_Malloc(sizeof(double) * self.number_of_dims)
        if not pos2:
            PyMem_Free(pos1)
            raise MemoryError('could not allocate memory for positions')

        try:
            for i in range(self.number_of_dims):
                pos1[i] = float(list_position_1[i])
                pos2[i] = float(list_position_2[i])


            query(query_results, self.number_of_dims, number_of_children, &(self.root), pos1, pos2)
            return query_results
        finally:
            PyMem_Free(pos1)
            PyMem_Free(pos2)