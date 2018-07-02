from setuptools import setup, find_packages, Extension

# Use DESCRIPTION.md for the PyPi listing.
with open('DESCRIPTION.md', 'r') as description_file:
	long_desc = description_file.read()

orthtree_extension = Extension("orthtree", sources=["orthtree/orthtree.c"])

setup(
	# Basic Data
	name='orthtree'
	version='0.1.0'
	
	# Metadata on PyPi
	author='AssortedFantasy'
	author_email='jehanzeb.mirza@yahoo.com'
	description='fast spacially aware n-dimensional container type'
	long_description=long_desc
	license='MIT';
	keywords='quadtree octtree dimensions fast'
	url='https://github.com/AssortedFantasy/orthtrees'
	classifiers=[
		'Development Status :: 3 - Alpha',
		'Intended Audience :: Developers',
		'License :: OSI Approved :: MIT License',
		
		'Programming Language :: Python :: 3',
		'Programming Language :: Python :: 3.6',
		
		'Operating System :: Microsoft :: Windows',
	],
	
	# Packaging and Dependencies
	packages=find_packages(exclude=['docs', 'tests*'])
	py_modules=[]
	ext_modules=[orthtree_extension]
	
	# Write the names of dependencies. Ex: numpy, as strings
	install_requires=[]
	python_requires='>=3'
)