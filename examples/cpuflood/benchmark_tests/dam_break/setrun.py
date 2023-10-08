# ----------------------------------------------
# @author:  Brian Kyanjo
# @contact: briankyanjo@u.boisestate.edu
# @date:    2022-10-16
# @version: 1.4
# ------------------------------------------------

'''
Test 6A: is the original test proposed in Soares-Frazao and Zech 2002, where the physical dimensions are those of the laboratory model.

Test 6B: is identical to Test 6A although all physical dimensions have been multiplied by 20 to reflect realistic dimensions encountered in practical flood inundation modelling applications.
'''
import os
import sys
import numpy as np
from pdb import *

import tools

#===============================================================================
# Importing scripts dictionary
#===============================================================================
sys.path.append('../../../../scripts')
import geoflood # -- importing geoflood.py
import data
from geoclaw.topotools import Topography

#===============================================================================
# scratch directory
#===============================================================================
scratch_dir = os.path.join('scratch')

#===============================================================================
# User specified parameters
#===============================================================================
#------------------ Time stepping------------------------------------------------
initial_dt = 0.01  # Initial time step
fixed_dt = False  # Take constant time step

# -------------------- Output files -------------------------------------------------
output_style = 1

if output_style == 1:
    # Total number of frames will be frames_per_minute*60*n_hours

    n_hours = 0.5         #<-- 2 minutes for test 6A and 30 minutes for test 6B
    
    frames_per_minute = 1  # (1 frame every 30 seconds)

if output_style == 2:
    output_times = [1,2,3]    # Specify exact times to output files

if output_style == 3:
    step_interval = 10   # Create output file every 10 steps
    total_steps = 1000   # ... for a total of 500 steps (so 50 output files total)

#-------------------  Computational coarse grid ---------------------------------------
# grid_resolution = 5  # meters ~ 80000 nodes
# mx = int(clawdata.upper[0] - clawdata.lower[0]) /grid_resolution
# my = int(clawdata.upper[1] - clawdata.lower[1])/grid_resolution
mx = 54  #<--- 18 for test 6A and 55 for test 6B
my = 54  #<--- 18 for test 6A and 2 for test 6B

mi = 18  #<--- 54 for test 6A and 55 for test 6B
mj = 1   #<--- 3 for test 6A and 3 for test 6B

minlevel = 1 
maxlevel = 3 #resolution based on levels 
ratios_x = [2]*(maxlevel)
ratios_y = [2]*(maxlevel)
ratios_t = [2]*(maxlevel)
 
#-------------------manning coefficient -----------------------------------------------
manning_coefficient = 0.05 # <-- 0.01 for test 6A and 0.05 for test 6B

#-------------------  Number of dimensions ---------------------------------------
num_dim = 2


# --------------------- guage data -----------------------------------------------
# gauge_loc = "./scratch/gauge_locA.csv" # <-- for test 6A
gauge_loc = "./scratch/gauge_locB.csv" # <-- for test 6B


# topo_file = './scratch/Test6ADEM.asc' # <-- for test 6A
topo_file = './scratch/Test6BDEM.asc' # <-- for test 6B

#------------------------------
def setrun(claw_pkg='geoclaw'):
#------------------------------

    """
    Define the parameters used for running Clawpack.

    INPUT:
        claw_pkg expected to be "geoclaw" for this setrun.

    OUTPUT:
        rundata - object of class ClawRunData

    """

    assert claw_pkg.lower() == 'geoclaw',  "Expected claw_pkg = 'geoclaw'"

   

    rundata = data.ClawRunData(claw_pkg, num_dim)

    #------------------------------------------------------------------
    # GeoClaw specific parameters:
    #------------------------------------------------------------------
    rundata = setgeo(rundata)

    #------------------------------------------------------------------
    # Standard Clawpack parameters to be written to claw.data:
    #   (or to amr2ez.data for AMR)
    #------------------------------------------------------------------
    clawdata = rundata.clawdata  # initialized when rundata instantiated


    # Set single grid parameters first.
    # See below for AMR parameters.


    # ---------------
    # Spatial domain:
    # ---------------

    # Number of space dimensions:
    clawdata.num_dim = num_dim
    
    def get_topo(topofile):
            m_topo,n_topo,xllcorner,yllcorner,cellsize = tools.read_topo_data(topofile)

            # Derived info from the topo map
            mx_topo = m_topo - 1
            my_topo = n_topo - 1
            xurcorner = xllcorner + cellsize*mx_topo
            yurcorner = yllcorner + cellsize*my_topo

            ll_topo = np.array([xllcorner, yllcorner])
            ur_topo = np.array([xurcorner, yurcorner])

            # ll_topo = np.array([957738.41,  1844520.8])
            # ur_topo = np.array([957987.1, 1844566.5])

        
            print("")
            print("Topo domain for %s:" % topofile)
            print("%-12s (%14.8f, %12.8f)" % ("Lower left",ll_topo[0],ll_topo[1]))
            print("%-12s (%14.8f, %12.8f)" % ("Upper right",ur_topo[0],ur_topo[1]))
            print("")

            # dims_topo = ur_topo - ll_topo

            dim_topo = ur_topo - ll_topo
            mdpt_topo = ll_topo + 0.5*dim_topo

            dim_comp = 0.975*dim_topo   # Shrink domain inside of given bathymetry.

            clawdata.lower[0] = mdpt_topo[0] - dim_comp[0]/2.0
            clawdata.upper[0] = mdpt_topo[0] + dim_comp[0]/2.0

            clawdata.lower[1] = mdpt_topo[1] - dim_comp[1]/2.0
            clawdata.upper[1] = mdpt_topo[1] + dim_comp[1]/2.0

            return dim_topo, clawdata.lower,clawdata.upper

    dims_topo, clawdata.lower, clawdata.upper = get_topo(topo_file)

    clawdata.num_cells[0] = mx
    clawdata.num_cells[1] = my

    print("")
    print("Computational domain")
    print("%-12s (%14.8f, %12.8f)" % ("Lower left",clawdata.lower[0],clawdata.lower[1]))
    print("%-12s (%14.8f, %12.8f)" % ("Upper right",clawdata.upper[0],clawdata.upper[1]))
    print("")

    dims_computed = np.array([clawdata.upper[0]-clawdata.lower[0], clawdata.upper[1]-clawdata.lower[1]])
    print("Computed aspect ratio    : {0:20.12f}".format(dims_computed[0]/dims_computed[1]))
   
    # ---------------
    # Size of system:
    # ---------------

    # Number of equations in the system:
    clawdata.num_eqn = 3

    # Number of auxiliary variables in the aux array (initialized in setaux)
    clawdata.num_aux = 1

    # Index of aux array corresponding to capacity function, if there is one:
    clawdata.capa_index = 0 #flag set to 0 if coordinate system = 1 otherwise 2

    # -------------
    # Initial time:
    # -------------

    clawdata.t0 = 0.0


    # Restart from checkpoint file of a previous run?
    # Note: If restarting, you must also change the Makefile to set:
    #    RESTART = True
    # If restarting, t0 above should be from original run, and the
    # restart_file 'fort.chkNNNNN' specified below should be in
    # the OUTDIR indicated in Makefile.

    clawdata.restart = False               # True to restart from prior results
    clawdata.restart_file = 'fort.chk00006'  # File to use for restart data

    # -------------
    # Output times:
    #--------------

    # Specify at what times the results should be written to fort.q files.
    # Note that the time integration stops after the final output time.
    # The solution at initial time t0 is always written in addition.

    clawdata.output_style = output_style

    if clawdata.output_style == 1:
        # Output nout frames at equally spaced times up to tfinal:
        # n_hours = 20.0
        # frames_per_minute = 1/30.0 # Frames every 5 seconds
        clawdata.num_output_times = int(frames_per_minute*60*n_hours)  # Plot every 10 seconds
        clawdata.tfinal = 60*60*n_hours
        clawdata.output_t0 = True  # output at initial (or restart) time?

    elif clawdata.output_style == 2:
        # Specify a list of output times.
        clawdata.output_times = [0.5, 1.0]

    elif clawdata.output_style == 3:
        # Output every iout timesteps with a total of ntot time steps:
        clawdata.output_step_interval = step_interval
        clawdata.total_steps = total_steps
        clawdata.output_t0 = True
        clawdata.tfinal = total_steps*fixed_dt

    clawdata.output_format = 'ascii'      # 'ascii' or 'netcdf'

    clawdata.output_q_components = 'all'   # could be list such as [True,True]
    clawdata.output_aux_components = 'none'  # could be list
    clawdata.output_aux_onlyonce = True    # output aux arrays only at t0



    # ---------------------------------------------------
    # Verbosity of messages to screen during integration:
    # ---------------------------------------------------

    # The current t, dt, and cfl will be printed every time step
    # at AMR levels <= verbosity.  Set verbosity = 0 for no printing.
    #   (E.g. verbosity == 2 means print only on levels 1 and 2.)
    clawdata.verbosity = 1



    # --------------
    # Time stepping:
    # --------------

    # if dt_variable==1: variable time steps used based on cfl_desired,
    # if dt_variable==0: fixed time steps dt = dt_initial will always be used.
    clawdata.dt_variable = not fixed_dt

    # Initial time step for variable dt.
    # If dt_variable==0 then dt=dt_initial for all steps:
    clawdata.dt_initial = initial_dt

    # Max time step to be allowed if variable dt used:
    clawdata.dt_max = 1e+99

    # Desired Courant number if variable dt used, and max to allow without
    # retaking step with a smaller dt:
    clawdata.cfl_desired = 0.9
    clawdata.cfl_max = 1.0

    # Maximum number of time steps to allow between output times:
    clawdata.steps_max = 5000

    # ------------------
    # Method to be used:
    # ------------------

    # Order of accuracy:  1 => Godunov,  2 => Lax-Wendroff plus limiters
    clawdata.order = 2

    # Use dimensional splitting? (not yet available for AMR)
    clawdata.dimensional_split = 'unsplit'

    # For unsplit method, transverse_waves can be
    #  0 or 'none'      ==> donor cell (only normal solver used)
    #  1 or 'increment' ==> corner transport of waves
    #  2 or 'all'       ==> corner transport of 2nd order corrections too
    clawdata.transverse_waves = 2

    # Number of waves in the Riemann solution:
    clawdata.num_waves = 3

    # List of limiters to use for each wave family:
    # Required:  len(limiter) == num_waves
    # Some options:
    #   0 or 'none'     ==> no limiter (Lax-Wendroff)
    #   1 or 'minmod'   ==> minmod
    #   2 or 'superbee' ==> superbee
    #   3 or 'mc'       ==> MC limiter
    #   4 or 'vanleer'  ==> van Leer
    clawdata.limiter = ['mc', 'mc', 'mc']

    clawdata.use_fwaves = True    # True ==> use f-wave version of algorithms

    # Source terms splitting:
    #   src_split == 0 or 'none'    ==> no source term (src routine never called)
    #   src_split == 1 or 'godunov' ==> Godunov (1st order) splitting used,
    #   src_split == 2 or 'strang'  ==> Strang (2nd order) splitting used,  not recommended.
    clawdata.source_split = 'godunov'


    # --------------------
    # Boundary conditions:
    # --------------------

    # Number of ghost cells (usually 2)
    clawdata.num_ghost = 2

    # Choice of BCs at xlower and xupper:
    #   0 => user specified (must modify bcN.f to use this option)
    #   1 => extrapolation (non-reflecting outflow)
    #   2 => periodic (must specify this at both boundaries)
    #   3 => solid wall for systems where q(2) is normal velocity

    clawdata.bc_lower[0] = 'wall'
    clawdata.bc_upper[0] = 'wall'

    clawdata.bc_lower[1] = 'wall'
    clawdata.bc_upper[1] = 'wall'

    # Specify when checkpoint files should be created that can be
    # used to restart a computation.

    clawdata.checkpt_style = 0

    if clawdata.checkpt_style == 0:
        # Do not checkpoint at all
        pass

    elif np.abs(clawdata.checkpt_style) == 1:
        # Checkpoint only at tfinal.
        pass

    elif np.abs(clawdata.checkpt_style) == 2:
        # Specify a list of checkpoint times.  
        clawdata.checkpt_times = [0.1,0.15]

    elif np.abs(clawdata.checkpt_style) == 3:
        # Checkpoint every checkpt_interval timesteps (on Level 1)
        # and at the final time.
        clawdata.checkpt_interval = 5

    # --------------------------------------------------------
    # GeoFlood parameters. 
    # These will overwrite any similar parameters listed above
    # --------------------------------------------------------

    geoflooddata = geoflood.GeoFlooddata()
    geoflooddata.minlevel = minlevel
    geoflooddata.maxlevel = maxlevel

    geoflooddata.refine_threshold = 0.01
    geoflooddata.coarsen_threshold = 0.005
    geoflooddata.smooth_refine = True
    geoflooddata.regrid_interval = 3
    geoflooddata.advance_one_step = False
    geoflooddata.ghost_patch_pack_aux = True
    geoflooddata.conservation_check = False

    geoflooddata.subcycle = True
    geoflooddata.output = True
    geoflooddata.output_gauges = True


    # Block dimensions for non-square domains
    geoflooddata.mi = mi
    geoflooddata.mj = mj

    # -----------------------------------------------
    # Tikz output parameters:
    # -----------------------------------------------
    geoflooddata.tikz_out = True
    geoflooddata.tikz_figsize = "36 2"
    geoflooddata.tikz_plot_prefix = "dam_break"
    geoflooddata.tikz_plot_suffix = "png"

    geoflooddata.user = {'example'     : 1}

    # Clawpatch tagging criteria
    # value       : value exceeds threshold
    # minmax      : qmax-qmin exceeds threshold
    # difference  : difference (e.g. dqx = q(i+1,j)-q(i-1,j)) exceeds threshold
    # gradient    : gradient exceeds threshold
    # user        : User defined criteria     
    geoflooddata.refinement_criteria = 'minmax' 

    # geoflood verbosity choices : 
    # 0 or 'silent'      : No output to the terminal
    # 1 or 'essential'   : Only essential output, including errors.
    # 2 or 'production'  : Production level output
    # 3 or 'info'        : More detailed output
    # 4 or 'debug'       : Includes detailed output from each processor
    geoflooddata.verbosity = 'production'

    # -----------------------------------------------
    # Hydrograph data:
    # -----------------------------------------------
    hydrographdata = geoflood.Hydrographdata()
   
    # -----------------------------------------------
    # AMR parameters:
    # -----------------------------------------------
    amrdata = rundata.amrdata

    amrdata.amr_levels_max = maxlevel    # Set to 3 for best results
    amrdata.refinement_ratios_x = ratios_x
    amrdata.refinement_ratios_y = ratios_y
    amrdata.refinement_ratios_t = ratios_t
    # rundata.tol = -1
    # rundata.tolsp = 0.001

    # Specify type of each aux variable in amrdata.auxtype.
    # This must be a list of length maux, each element of which is one of:
    #   'center',  'capacity', 'xleft', or 'yleft'  (see documentation).

    amrdata.aux_type = ['capacity']


    # Flag using refinement routine flag2refine rather than richardson error
    amrdata.flag_richardson = False    # use Richardson?
    amrdata.flag2refine = True
    amrdata.flag2refine_tol = 0.05
    amrdata.regrid_interval = 3
    amrdata.regrid_buffer_width  = 2
    amrdata.clustering_cutoff = 0.700000
    amrdata.verbosity_regrid = 0

    # To specify regions of refinement append lines of the form
    #    regions.append([minlevel,maxlevel,t1,t2,x1,x2,y1,y2])

    # -----------------------------------------------
    regions = rundata.regiondata.regions

    # Region containing initial reservoir
    # Test6A reservior -> 7.5m out of 99m in x and 3.6m in y. Test6B reservior -> 140m out of 1823m in x and 53m  in y 
    regions.append([maxlevel,maxlevel,0, 1e10, -128.0,0,-55.11250000,53.11250000]) #<-- Reservior minus gate
    # regions.append([maxlevel,maxlevel,0, 1e10, 0,16,26,46]) #<-- dam gate
    
   # Gauges ( append lines of the form  [gaugeno, x, y, t1, t2])
    gaugeno,x,y = tools.read_locations_data(gauge_loc)

    print('\nLocation of Gauges:')
    for i in range(gaugeno):
        print('\tGauge %s at (%s, %s)' % (i, x[i],y[i]))
        rundata.gaugedata.gauges.append([i, x[i],y[i], 0., 1e10])


    # -----------------------------------------------
    # == setflowgrades data values ==
    flowgrades_data = geoflood.Flowgradesdata()
    # this can be used to specify refinement criteria, for Overland flow problems.
    # for using flowgrades for refinement append lines of the form
    # [flowgradevalue, flowgradevariable, flowgradetype, flowgrademinlevel]
    # where:
    #flowgradevalue: floating point relevant flowgrade value for following measure:
    #flowgradevariable: 1=depth, 2= momentum, 3 = sign(depth)*(depth+topo) (0 at sealevel or dry land).
    #flowgradetype: 1 = norm(flowgradevariable), 2 = norm(grad(flowgradevariable))
    #flowgrademinlevel: refine to at least this level if flowgradevalue is exceeded.
    # flowgrades_data.flowgrades.append([1.e-3, 2, 1, maxlevel])
    # flowgrades_data.flowgrades.append([1e-3, 1, 1, maxlevel])
    flowgrades_data.flowgrades.append([0.4, 3, 1, maxlevel])

    #
    # -------------------------------------------------------
    # For developers
    #    -- Toggle debugging print statements:
    # -------------------------------------------------------
    amrdata.dprint = False      # print domain flags
    amrdata.eprint = False      # print err est flags
    amrdata.edebug = False      # even more err est flags
    amrdata.gprint = False      # grid bisection/clustering
    amrdata.nprint = False      # proper nesting output
    amrdata.pprint = False      # proj. of tagged points
    amrdata.rprint = False      # print regridding summary
    amrdata.sprint = False      # space/memory output
    amrdata.tprint = True      # time step reporting each level
    amrdata.uprint = False      # update/upbnd reporting


    return rundata, geoflooddata, hydrographdata,flowgrades_data
    # end of function setrun
    # ----------------------

#-------------------
def setgeo(rundata):
#-------------------
    """
    Set GeoClaw specific runtime parameters.
    For documentation see ....
    """

    try:
        geo_data = rundata.geo_data
    except:
        print("*** Error, this rundata has no geo_data attribute")
        raise AttributeError("Missing geo_data attribute")

    # == Physics ==
    geo_data.gravity = 9.81
    geo_data.coordinate_system = 1   # 1 - for cartesian x-y cordinates  2 - LatLong coordinates
    geo_data.earth_radius = 6367.5e3

    # == Forcing Options
    geo_data.coriolis_forcing = False #Not used in TELEmac

    # == Algorithm and Initial Conditions ==
    geo_data.sea_level = 0
    geo_data.dry_tolerance = 0.0001
    geo_data.friction_forcing = True
    geo_data.manning_coefficient = manning_coefficient
    geo_data.friction_depth = 500

    # Refinement data
    refinement_data = rundata.refinement_data
    refinement_data.wave_tolerance = 1.e-2
    refinement_data.speed_tolerance = [1.e-1]*6
    refinement_data.deep_depth = 0.4
    refinement_data.max_level_deep = maxlevel
    refinement_data.variable_dt_refinement_ratios = True

    # == settopo.data values ==
    topo_data = rundata.topo_data
    # for topography, append lines of the form
    #    [topotype, minlevel, maxlevel, t1, t2, fname]
    topo_data.topofiles.append([3, minlevel, minlevel, 0, 1e10, topo_file])

    # == setqinit.data values ==
    rundata.qinit_data.qinit_type = 0
    rundata.qinit_data.qinitfiles = []
    rundata.qinit_data.variable_eta_init = True
    # for qinit perturbations, append lines of the form: (<= 1 allowed for now!)
    #   [minlev, maxlev, fname]

    # rundata.qinit_data.qinitfiles.append([minlevel,minlevel,'init.xyz'])

    return rundata
    # end of function setgeo
    # ---------------------

#------------------- generate qinit file -------------------
def generate_qinit():
#-------------------
    """
    Generate topo file for the current run
    """
    nxpoints = 2021
    nypoints = 112
    xlower = -146.25   #<-- -6.575 for test 6A and -128 for test 6B
    xupper =  1823.25000000   #<-- 0 for test 6A and 0 for test 6B
    yupper = 53.11250000      #<-- 5.4 for test 6A and 53 for test 6B
    ylower = -55.11250000     #<-- -7.31 for test 6A and -55 for test 6B
    outfile= "init.xyz"      

    qinitA = lambda x,y: np.where(x<0, 0.4, 0.02)
    qinitB = lambda x,y: np.where(x<0, 8, 0.4)

    # topography = Topography(topo_func=qinitA) #<-- Change to this for Test6A
    topography = Topography(topo_func=qinitB)   #<--  Change to this for Test6A
    topography.x = np.linspace(xlower,xupper,nxpoints)
    topography.y = np.linspace(ylower,yupper,nypoints)
    topography.write(outfile, topo_type=1)

if __name__ == '__main__':
    # Set up run-time parameters and write all data files.
    generate_qinit()         # generate topo file (generated before running setrun.py)
    rundata,geoflooddata,hydrographdata,flowgrades_data = setrun(*sys.argv[1:])
    rundata.write()

    geoflooddata.write(rundata)  # writes a geoflood geoflood.ini file
    hydrographdata.write()       # writes a geoflood hydrograph file
    flowgrades_data.write()  # writes a geoflood flowgrades file
    
