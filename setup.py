from setuptools import setup, Extension, find_packages

use_cython = False

with open('README.md', 'r') as readme:
    long_description = readme.read()

if use_cython:
    from Cython.Build import cythonize
    extensions = cythonize("orthtree/orthtree.pyx")
else:
    extensions = [Extension("orthtree", sources=["orthtree/orthtree.c"])]


setup(
    name="orthtree",
    version="1.0.0",
    url="https://github.com/AssortedFantasy/orthtrees",
    author="Assorted Fantasy",
    author_email="jehanzeb.mirza@yahoo.com",
    description="Fast orthtree container type",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    ext_modules=extensions,
    classifiers=(
        # No idea what else to add here, seems good?
        "Programming Language :: Python",
        "Programming Language :: Cython",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ),
)
