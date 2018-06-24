from setuptools import setup
from Cython.Build import cythonize

setup(
    name="orthtree",
    version="0.0.1",
    url="none",
    author="me",
    author_email="",
    ext_modules=cythonize("orthtree.pyx"),
)
