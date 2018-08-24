#include "openmc/settings.h"

#include "openmc/capi.h"
#include "openmc/constants.h"
#include "openmc/distribution.h"
#include "openmc/distribution_multi.h"
#include "openmc/distribution_spatial.h"
#include "openmc/error.h"
#include "openmc/source.h"
#include "openmc/string_utils.h"
#include "openmc/xml_interface.h"

namespace openmc {

//==============================================================================
// Global variables
//==============================================================================

namespace settings {

// Default values for boolean flags
bool assume_separate         {false};
bool check_overlaps          {false};
bool cmfd_run                {false};
bool confidence_intervals    {false};
bool create_fission_neutrons {true};
bool entropy_on              {false};
bool legendre_to_tabular     {true};
bool output_summary          {true};
bool output_tallies          {true};
bool particle_restart_run    {false};
bool photon_transport        {false};
bool reduce_tallies          {true};
bool res_scat_on             {false};
bool restart_run             {false};
bool run_CE                  {true};
bool source_latest           {false};
bool source_separate         {false};
bool source_write            {true};
bool survival_biasing        {false};
bool temperature_multipole   {false};
bool trigger_on              {false};
bool trigger_predict         {false};
bool ufs_on                  {false};
bool urr_ptables_on          {true};
bool write_all_tracks        {false};
bool write_initial_source    {false};

char* path_input;
char* path_statepoint;
char* path_sourcepoint;
char* path_particle_restart;
std::string path_cross_sections;
std::string path_multipole;
std::string path_output;
std::string path_source;

int32_t index_entropy_mesh {-1};
int32_t index_ufs_mesh {-1};

int electron_treatment {ELECTRON_TTB};
double energy_cutoff[4] {0.0, 1000.0, 0.0, 0.0};
int legendre_to_tabular_points {C_NONE};
int res_scat_method {RES_SCAT_ARES};
double res_scat_energy_min {0.01};
double res_scat_energy_max {1000.0};
int run_mode;
int temperature_method {TEMPERATURE_NEAREST};
double temperature_tolerance {10.0};
double temperature_default {293.6};
double temperature_range[2] {0.0, 0.0};
int verbosity {7};
double weight_cutoff {0.25};
double weight_survive {1.0};

} // namespace settings

//==============================================================================
// Functions
//==============================================================================

void read_settings(pugi::xml_node* root)
{
  using namespace settings;

  // Look for deprecated cross_sections.xml file in settings.xml
  if (check_for_node(*root, "cross_sections")) {
    warning("Setting cross_sections in settings.xml has been deprecated."
        " The cross_sections are now set in materials.xml and the "
        "cross_sections input to materials.xml and the OPENMC_CROSS_SECTIONS"
        " environment variable will take precendent over setting "
        "cross_sections in settings.xml.");
    path_cross_sections = get_node_value(*root, "cross_sections");
  }

  // Look for deprecated windowed_multipole file in settings.xml
  if (run_mode != RUN_MODE_PLOTTING) {
    if (check_for_node(*root, "multipole_library")) {
      warning("Setting multipole_library in settings.xml has been "
          "deprecated. The multipole_library is now set in materials.xml and"
          " the multipole_library input to materials.xml and the "
          "OPENMC_MULTIPOLE_LIBRARY environment variable will take "
          "precendent over setting multipole_library in settings.xml.");
      path_multipole = get_node_value(*root, "multipole_library");
    }
    if (!ends_with(path_multipole, "/")) {
      path_multipole += "/";
    }
  }

  // Check for output options
  if (check_for_node(*root, "output")) {

    // Get pointer to output node
    pugi::xml_node node_output = root->child("output");

    // Set output directory if a path has been specified
    if (check_for_node(node_output, "path")) {
      path_output = get_node_value(node_output, "path");
      if (!ends_with(path_output, "/")) {
        path_output += "/";
      }
    }
  }

  // Get temperature settings
  if (check_for_node(*root, "temperature_default")) {
    temperature_default = std::stod(get_node_value(*root, "temperature_default"));
  }
  if (check_for_node(*root, "temperature_method")) {
    auto temp_str = get_node_value(*root, "temperature_method", true, true);
    if (temp_str == "nearest") {
      temperature_method = TEMPERATURE_NEAREST;
    } else if (temp_str == "interpolation") {
      temperature_method = TEMPERATURE_INTERPOLATION;
    } else {
      fatal_error("Unknown temperature method: " + temp_str);
    }
  }
  if (check_for_node(*root, "temperature_tolerance")) {
    temperature_tolerance = std::stod(get_node_value(*root, "temperature_tolerance"));
  }
  if (check_for_node(*root, "temperature_multipole")) {
    temperature_multipole = get_node_value_bool(*root, "temperature_multipole");
  }
  if (check_for_node(*root, "temperature_range")) {
    auto range = get_node_array<double>(*root, "temperature_range");
    temperature_range[0] = range[0];
    temperature_range[1] = range[1];
  }

  // ==========================================================================
  // EXTERNAL SOURCE

  // Get point to list of <source> elements and make sure there is at least one
  for (pugi::xml_node node : root->children("source")) {
    external_sources.emplace_back(node);
  }

  // If no source specified, default to isotropic point source at origin with Watt spectrum
  if (external_sources.empty()) {
    SourceDistribution source {
      UPtrSpace{new SpatialPoint({0.0, 0.0, 0.0})},
      UPtrAngle{new Isotropic()},
      UPtrDist{new Watt(0.988, 2.249e-6)}
    };
    external_sources.push_back(std::move(source));
  }
}

} // namespace openmc
