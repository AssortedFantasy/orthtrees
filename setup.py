from setuptools import setup

use_cython = False

with open('README.md', 'r') as readme:
    long_description = readme.read()

if use_cython:
    from Cython.Build import cythonize
    extensions = None
else:
    extensions = None


setup(
    name="orthtree",
    version="1.0.0",
    url="https://github.com/AssortedFantasy/orthtrees",
    author="Assorted Fantasy",
    author_email="jehanzeb.mirza@yahoo.com",
    description="Fast orthtree container type",
    long_description=long_description,
    ext_modules=extensions,
    classifiers=(
        "Programming Language :: Cython"
        "License :: OSI Approved :: MIT License"
        "Operating System :: OS Independent",
    )
)
