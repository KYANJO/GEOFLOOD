/*
  Copyright (c) 2012-2022 Carsten Burstedde, Donna Calhoun, Scott Aiton
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

#include "filling_depressions_user.h"

#include <fc2d_cuda_profiler.h>
#include <fclaw2d_include_all.h>

#include <fclaw2d_clawpatch.h>
#include <fclaw2d_clawpatch_options.h>

#include <fc2d_cpucuda.h>

static
fclaw2d_domain_t* create_domain(sc_MPI_Comm mpicomm, fclaw_options_t* fclaw_opt)
{
    /* Mapped, multi-block domain */
    p4est_connectivity_t     *conn = NULL;
    fclaw2d_domain_t         *domain;
    fclaw2d_map_context_t    *cont = NULL, *brick = NULL;

    int mi,mj,a,b;

    mi = fclaw_opt->mi;
    mj = fclaw_opt->mj;
    a = 0; /* non-periodic */
    b = 0;

    /* Rectangular brick domain */
    conn = p4est_connectivity_new_brick(mi,mj,a,b);
    brick = fclaw2d_map_new_brick_conn(conn,mi,mj);
    cont = fclaw2d_map_new_nomap_brick(brick);

    domain = fclaw2d_domain_new_conn_map (mpicomm, fclaw_opt->minlevel, conn, cont);
    fclaw2d_domain_list_levels(domain, FCLAW_VERBOSITY_ESSENTIAL);
    fclaw2d_domain_list_neighbors(domain, FCLAW_VERBOSITY_DEBUG);

    return domain;
}



static
void run_program(fclaw2d_global_t* glob)
{

    /* ---------------------------------------------------------------
       Set domain data.
       --------------------------------------------------------------- */
    fclaw2d_domain_data_new(glob->domain);
    fc2d_cpucuda_options_t* geo_opt = fc2d_cpucuda_get_options(glob);
    user_options_t* user_opt = geoflood_get_options(glob);
    /* Initialize virtual table for ForestClaw */
    fclaw2d_vtables_initialize(glob);
    
    if(user_opt->cuda != 0)
    {
        /* Initialize virtual tables for solvers */
        fc2d_cudaclaw_initialize_GPUs(glob);

        /* this has to be done after GPUs have been initialized */
        cudaclaw_set_method_parameters(geo_opt->order, 
                                    geo_opt->mthlim, 
                                    geo_opt->mwaves,
                                    geo_opt->use_fwaves);
    }

     /* Calls either the CPU or GPU solvers depending on user_opt->cuda */
    fc2d_geoclaw_solver_initialize(glob);

    filling_depressions_link_solvers(glob);

    fc2d_geoclaw_module_setup(glob);

    /* ---------------------------------------------------------------
       Initialize, run and finalize
       --------------------------------------------------------------- */
    if(user_opt->cuda != 0)
    {
        PROFILE_CUDA_GROUP("Allocate GPU and GPU buffers",1);
        fc2d_cudaclaw_allocate_buffers(glob);
    }
    
    fclaw2d_initialize(glob);
    // fclaw2d_run(glob);
    fc2d_geoclaw_run(glob);
    
     if(user_opt->cuda != 0)
    {
        PROFILE_CUDA_GROUP("De-allocate GPU and GPU buffers",1);
        fc2d_cudaclaw_deallocate_buffers(glob);
    }
    
    fclaw2d_finalize(glob);
}

int
main (int argc, char **argv)
{
    fclaw_app_t *app;
    int first_arg;
    fclaw_exit_type_t vexit;

    /* Options */
    sc_options_t                *options;
    user_options_t              *user_opt;
    fclaw_options_t             *fclaw_opt;
    fclaw2d_clawpatch_options_t *clawpatch_opt;
    fc2d_cpucuda_options_t      *geoclaw_opt;

    fclaw2d_global_t            *glob;
    fclaw2d_domain_t            *domain;
    sc_MPI_Comm mpicomm;

    int retval;
    // printf("cuda = %d\n",user_opt->cuda);
    /* Initialize application */
    app = fclaw_app_new (&argc, &argv, NULL);

    fclaw_opt       =             fclaw_options_register(app,  NULL,       "fclaw_options.ini");
    clawpatch_opt   = fclaw2d_clawpatch_options_register(app, "clawpatch", "fclaw_options.ini");
    geoclaw_opt     =      fc2d_cpucuda_options_register(app, "geoclaw",   "fclaw_options.ini");
    user_opt =                geoflood_options_register(app,  "user",       "fclaw_options.ini"); 

    /* Read configuration file(s) and command line, and process options */
    options = fclaw_app_get_options (app);
    retval = fclaw_options_read_from_file(options);
    vexit =  fclaw_app_options_parse (app, &first_arg,"fclaw_options.ini.used");
    /* Run the program */
    if (!retval & !vexit)
    {
        mpicomm = fclaw_app_get_mpi_size_rank (app, NULL, NULL);
        domain = create_domain(mpicomm, fclaw_opt);
    
        /* Create global structure which stores the domain, timers, etc */
        glob = fclaw2d_global_new();
        fclaw2d_global_store_domain(glob, domain);

        /* Store option packages in glob */
        fclaw2d_options_store           (glob, fclaw_opt);
        fclaw2d_clawpatch_options_store (glob, clawpatch_opt);
        fc2d_cpucuda_options_store      (glob, geoclaw_opt);
        geoflood_options_store          (glob, user_opt);
        
        run_program(glob);
        
        fclaw2d_global_destroy(glob);
    }

    fclaw_app_destroy (app);

    return 0;
}
