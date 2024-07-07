#include "../fc2d_cudaclaw_cuda.h"
#include "../fc2d_geoclaw_fort.h"
#include "variables.h"
#include <math.h>
#include <fc2d_cudaclaw_check.h>

/* Declare constant memory variables */
__constant__ GeofloodVars d_geofloodVars;

void setprob_cuda() {

    /*=== declare variables === */
    int coord_system_, num_manning_, friction_index_;
    // double dry_tol_;
    // int mcapa_;
    double grav_, earth_rad_, deg2rad_;
    double theta_0_, omega_, friction_depth_;
    bool coriolis_forcing_, friction_forcing_, variable_friction_;
    // double *manning_coeff_, *manning_break_;
    double manning_coeff_, manning_break_;

    GET_GEOCLAW_PARAMETERS(&coord_system_,&grav_, &earth_rad_,&deg2rad_, 
                           &theta_0_, &omega_, &coriolis_forcing_, &friction_forcing_, &friction_depth_,
                           &variable_friction_, &num_manning_, &friction_index_, &manning_coeff_, &manning_break_);

     /* === Create and populate structures on the host === */
    GeofloodVars geofloodVars;
    geofloodVars.gravity = grav_;
    // geofloodVars.dry_tolerance = dry_tol_;
    geofloodVars.earth_radius = earth_rad_;
    geofloodVars.coordinate_system = coord_system_;
    // geofloodVars.mcapa = mcapa_;
    geofloodVars.deg2rad = deg2rad_;
    geofloodVars.theta_0 = theta_0_;
    geofloodVars.omega = omega_;
    geofloodVars.coriolis_forcing = coriolis_forcing_;
    geofloodVars.friction_forcing = friction_forcing_;
    geofloodVars.friction_depth = friction_depth_;
    geofloodVars.variable_friction = variable_friction_;
    geofloodVars.num_manning = num_manning_;
    geofloodVars.friction_index = friction_index_;
    geofloodVars.manning_coefficent = manning_coeff_;
    geofloodVars.manning_break = manning_break_;

    /* === Copy structures to device (constant memory) === */
    CHECK(cudaMemcpyToSymbol(d_geofloodVars, &geofloodVars, sizeof(GeofloodVars)));

}
