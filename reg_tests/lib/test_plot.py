#
# Copyright 2017 National Renewable Energy Laboratory
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""
    This program plots the output vectors (vs. time) of a given solution attribute
    for two OpenFAST solutions, with the second solution assumed to be the baseline for
    comparison. It reads two OpenFAST binary output files (.outb), and
    generates three plots of the given attribute (1) comparing the two tests' respective
    values, (2) showing the difference in values, and (3) showing relative difference,
    as compared to the baseline solution.

    Usage: python3 pass_fail.py solution1 solution2 attribute
    Example: python3 pass_fail.py output-local/Test01.outb output-baseline/Test01.outb Wind1VelX
"""
import sys, os
import numpy as np
from numpy import linalg as LA
from fast_io import load_output
import matplotlib.pyplot as plt

def exitWithError(error):
    print(error)
    sys.exit(1)

# validate input arguments
nArgsExpected = 4
if len(sys.argv) < nArgsExpected:
    exitWithError("Error: {} arguments given, expected {}\n".format(len(sys.argv), nArgsExpected) +
        "Usage: {} solution1 solution2 attribute".format(sys.argv[0]))

solutionFile1 = sys.argv[1]
solutionFile2 = sys.argv[2]
attribute = sys.argv[3]

if not os.path.isfile(solutionFile1):
    exitWithError("Error: solution file does not exist at {}".format(solutionFile1))

if not os.path.isfile(solutionFile2):
    exitWithError("Error: solution file does not exist at {}".format(solutionFile2))

# try:
#     solutionTolerance = float(solutionTolerance)
# except ValueError:
#     exitWithError("Error: invalid tolerance given, {}".format(solutionTolerance))

# parse the FAST solution files
try:
    dict1, info1 = load_output(solutionFile1)
    dict2, info2 = load_output(solutionFile2)
except Exception as e:
    exitWithError("Error: {}".format(e))

try:
    channel = info1['attribute_names'].index(attribute)
except Exception as e:
    exitWithError("Error: Invalid channel name--{}".format(e))

# get test name -- this could break if .outb file is not used, or if
# test number gets to three digits
testname = solutionFile1.split("/")[-1]
testname = testname.split(".")[-2]

timevec = dict1[:, 0]
diff = dict1[:, channel] - dict2[:, channel]
a = np.array(dict1[:, channel], dtype = np.float)
b = np.array(dict2[:, channel], dtype = np.float)
reldiff = (a - b) / b

plt.figure(1)
plt.subplot(311)
plt.title('File Comparisons for ' + testname + '\nNew: ' +
          solutionFile1 + '\n Old: ' + solutionFile2)
plt.grid(True)
plt.ylabel(attribute + '\n' + '(' + info1['attribute_units'][channel] + ')')
plt.plot(timevec, dict1[:, channel], label = 'New')
plt.plot(timevec, dict2[:, channel], label = 'Old')
plt.legend()
plt.subplot(312)
plt.grid(True)
plt.plot(timevec, diff)
plt.ylabel('Difference\n' + '(Old - New)\n' + '(' + info1['attribute_units'][channel] + ')')
plt.subplot(313)
plt.grid(True)
plt.plot(timevec, reldiff)
plt.ylabel('Relative\n Difference\n' + '(%)')
plt.xlabel('Times (s)')
plt.show()
