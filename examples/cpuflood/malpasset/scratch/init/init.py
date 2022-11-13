#!/usr/bin/python

"""
   Create the grid necessary for initializing the Malpasset simulation in file qinit.xyz
"""

from numpy import *
from scipy import *
import datatools.iotools as iotools
import geotools.topotools as topotools

(X,Y,B)=topotools.topofile2griddata('../grids/malpasset_domaingrid_5m.topotype2',2)

#create an init surface of where eta is an indicator function (behind or in front of the dam):
# eta =  100m behind the dam
# eta = -100m behind the dam

def fofx (x):
    """
    fofx ():
    return value of a piecewise discontinuous function

    """
    x0=953.155e3
    x1=956.0e3
    x2=957.0e3
    x3=957.2e3
    x4=958.15e3
    x5=959.640e3

    y1=1844.5e3
    y2=1843.6e3
    y3=1844.5e3
    y4=1844.7e3
    y5=1845.7e3

    if x<x3:
         m=(y2-y1)/(x2-x1)
         y= y1 + m*(x-x1) 
    elif x3<=x<x4:
         y=y3
    else:
         m=(y5-y4)/(x5-x4)
         y = y4 + m*(x-x4)

    return y


initfile=open("init_h_5m.xyz",'w')
for i in xrange(shape(Y)[0]) :
    for j in xrange(shape(X)[1]):
        x=X[i,j]
        y=Y[i,j]
        b=B[i,j]
        f=fofx(x)

        if y>f:
            eta=100.0
        else:
            eta=-100.0

        h= max(eta-b,0)

        initfile.write("%s %s %s\n" % (x,y,h))

initfile.close()

initfile=open("init_eta_5m.xyz",'w')
for i in xrange(shape(Y)[0]) :
    for j in xrange(shape(X)[1]):
        x=X[i,j]
        y=Y[i,j]
        b=B[i,j]
        f=fofx(x)

        if y>f:
            eta = 100.0
        else:
            eta = 0.0

        h= max(eta-b,0)

        initfile.write("%s %s %s\n" % (x,y,eta))

initfile.close()
