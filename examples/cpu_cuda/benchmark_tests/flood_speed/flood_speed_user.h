/*
Copyright (c) 2012 Carsten Burstedde, Donna Calhoun
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifndef FLOOD_SPEED_USER_H
#define FLOOD_SPEED_USER_H

#include <fclaw2d_include_all.h>

#ifdef __cplusplus
extern "C"
{
#if 0
}
#endif
#endif

typedef struct user_options
{
    int cuda;
    int example;
    double gravity;
    double dry_tolerance;
    double earth_radius;
    double coordinate_system;
    int mcapa;
    int is_registered;
} user_options_t;

// --------------------------------------------
void flood_speed_link_solvers(fclaw2d_global_t *glob);
user_options_t* flood_speed_options_register (fclaw_app_t * app,
                                          const char *configfile);
void flood_speed_options_store (fclaw2d_global_t* glob, user_options_t* user);
user_options_t* flood_speed_get_options(fclaw2d_global_t* glob);

#define FLOOD_SPEED_QINIT  FCLAW_F77_FUNC(flood_speed_qinit, FLOOD_SPEED_QINIT)

void FLOOD_SPEED_QINIT(const int* meqn, const int* mbc,
                    const int* mx, const int* my,
                    const double* xlower, const double* ylower,
                    const double* dx, const double* dy,
                    double q[], const int* maux, double aux[]);

//  BC (Fortran to c)
#define FLOOD_SPEED_BC2   FCLAW_F77_FUNC(flood_speed_bc2, FLOOD_SPEED_BC2)

void FLOOD_SPEED_BC2(const int* meqn, const int* mbc,
                    const int* mx, const int* my,
                    const double* xlower, const double* ylower,
                    const double* dx, const double* dy,
                    const double q[], const int* maux,
                    const double aux[], const double* t,
                    const double* dt, const int mthbc[]);


/* Mappings */
fclaw2d_map_context_t* fclaw2d_map_new_nomap();

#ifdef __cplusplus
#if 0
{
#endif
}
#endif

#endif
