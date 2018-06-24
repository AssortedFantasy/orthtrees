# Orthtrees

## Summary

An orthant or hyper octant is the n-dimensional generalization of quadrants
and octants, subdivisions of rectangular space.

An orthtree is a tree like data structure which stores n-dimensional point-like
elements in a spatially aware manner and implements a method for querying
a subregion in an efficient manner.

Best case inserts and queries are O(1) and O(log(n)) respectively.
Worse case they are O(n) and O(n)

This project provides an incredibly fast, memory safe, orthtree class written
entirely in Cython which implements an orthtree.


## Usage

### Documentation

**Class** orthtree.Orthtree( position_1, position_2, bucket_size=8)

Constructor for the orthtree object, position_1 and position_2 can be any
iterable. They must only contain elements which can be converted to floats
and must be of the same length. This length can indeed be zero but it is
rather pointless to do so and acts as a slow limit functionality list.
Bucket size determines the maximum number of elements which a given node
can hold, you can Read the [Wikipedia Article](https://en.wikipedia.org/wiki/Quadtree)
on quadtrees to learn more about buckets. Buck size must be a positive integer.


#### Orthtree objects

Orthtree.**number_of_objects**
int, is the the number of items in the tree.


Orthtree.**number_of_dims**
int, number of dimensions of the tree.


Orthtree.**bucket_size**
int, bucket size of the nodes.


Orthtree.**position_1**
Orthtree.**position_2**

tuples of the positions passed to \_\_init\_\_. Purely decorative and aren't
actually used in the implementation.


Orthtree.**insert**(item, position)

Inserts an item with a given position into the tree. Position can be any
iterable and the elements of position must be able to be converted into floats.
Returns True if the object was successfully inserted, False otherwise, i.e
the item's position was not inside the tree.


Orthtree.**query**(position_1, position_2)

Returns a list of all elements in the tree between those two points. It does not need
to be a subset of the space inside the tree. Does not contain position information.
Items return in a deterministic order, but it is not a useful one.


Orthtree.**to_list**()

Returns a list of all elements inside the tree, equivalent to calling query on
a superset of the tree. Much faster than using list(Orthtree).


### Examples

```python
from orthtree import Orthtree as or
import random

my_tree = or([0, 0], [1, 1]) # Creating a 2D(Quad) Tree

my_tree.insert("I'm in the middle!", (.5, .5))     # Returns True
my_tree.insert("I'm sitting on the edge!", (0, 1)) # Returns True
my_tree.insert("I'm not inside!", (0, -1))         # Returns False

try:
    my_tree.insert("Higher dimensional being", (0, 0, 0)) # Raises index error)
except IndexError:
    pass

for i in range(10000):
    my_tree.insert( i, (random.random(), random.random())) # Blazing fast

some_points = my_tree.query([0,0],[0.5,0.5]) # Returns any elements in the bottom left corner

for point in my_tree:  # Supports iteration protocol.
    pass

my_tree_list = list(my_tree) # Slow
my_tree_list = my_tree.to_list() # Fast
```

### Missing Features

#### Moving and Removing Items

Orthtrees don't support removing regions or items, I may add support but
the orthtree is designed to be so fast that you can simply recreate it after
performing a transformation on your items.

Moving will never be implemented. Feel free to try doing so though in a fork.

#### Returning with the coordinates

I could, but its probably better to just have the items be objects which have
position data already inside them.

#### Internal Structure being Python-Visible

Internally it is all structs and pointers so that its memory efficient and
fast. I could create a wrapper of sorts which allows you to browse around but currently
it is entirely a black box which magically handles items.