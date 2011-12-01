module output

  use ISO_FORTRAN_ENV

  use constants
  use cross_section_header, only: Reaction
  use datatypes,            only: dict_get_key
  use endf,                 only: reaction_name
  use geometry_header,      only: Cell, Universe, Surface
  use global
  use mesh_header,          only: StructuredMesh
  use string,               only: upper_case, int_to_str, real_to_str
  use tally_header,         only: TallyObject

  implicit none

  ! Short names for output and error units
  integer :: ou = OUTPUT_UNIT
  integer :: eu = ERROR_UNIT

contains

!===============================================================================
! TITLE prints the main title banner as well as information about the program
! developers, version, and date/time which the problem was run.
!===============================================================================

  subroutine title()

    character(10) :: today_date
    character(8)  :: today_time

    write(ou,*)
    write(ou,*) '       .d88888b.                             888b     d888  .d8888b.'
    write(ou,*) '      d88P" "Y88b                            8888b   d8888 d88P  Y88b'
    write(ou,*) '      888     888                            88888b.d88888 888    888'
    write(ou,*) '      888     888 88888b.   .d88b.  88888b.  888Y88888P888 888       '
    write(ou,*) '      888     888 888 "88b d8P  Y8b 888 "88b 888 Y888P 888 888       '
    write(ou,*) '      888     888 888  888 88888888 888  888 888  Y8P  888 888    888'
    write(ou,*) '      Y88b. .d88P 888 d88P Y8b.     888  888 888   "   888 Y88b  d88P'
    write(ou,*) '       "Y88888P"  88888P"   "Y8888  888  888 888       888  "Y8888P"'
    write(ou,*) '__________________888______________________________________________________'
    write(ou,*) '                  888'
    write(ou,*) '                  888'
    write(ou,*)

    ! Write version information
    write(ou,*) '     Developed At:    Massachusetts Institute of Technology'
    write(ou,*) '     Lead Developer:  Paul K. Romano'
    write(ou,100) VERSION_MAJOR, VERSION_MINOR, VERSION_RELEASE
100 format (6X,"Version:",9X,I1,".",I1,".",I1)

    ! Write the date and time
    call get_today(today_date, today_time)
    write(ou,101) trim(today_date), trim(today_time)
101 format (6X,"Date/Time:",7X,A,1X,A)
    write(ou,*)

  end subroutine title

!===============================================================================
! HEADER displays a header block according to a specified level. If no level is
! specified, it is assumed to be a minor header block (H3).
!===============================================================================

  subroutine header(msg, level, unit_file)

    character(*), intent(in) :: msg
    integer,      optional   :: level
    integer,      optional   :: unit_file

    integer :: header_level
    integer :: n, m
    integer :: unit
    character(75) :: line

    ! set default header level
    if (.not. present(level)) then
       header_level = 3
    else
       header_level = level
    end if

    ! set default unit
    if (present(unit_file)) then
       unit = unit_file
    else
       unit = ou
    end if

    ! Print first blank line
    write(unit,*)

    ! determine how many times to repeat '=' character
    n = (63 - len_trim(msg))/2
    m = n
    if (mod(len_trim(msg),2) == 0) m = m + 1

    ! convert line to upper case
    line = msg
    call upper_case(line)

    ! print header based on level
    select case (header_level)
    case (1)
       ! determine number of spaces to put in from of header
       write(unit,*) repeat('=', 75)
       write(unit,*) repeat('=', n) // '>     ' // trim(line) // '     <' // &
            & repeat('=', m)
       write(unit,*) repeat('=', 75)
    case (2)
       write(unit,*) trim(line)
       write(unit,*) repeat('-', 75)
    case (3)
       n = (63 - len_trim(line))/2
       write(unit,*) repeat('=', n) // '>     ' // trim(line) // '     <' // &
            & repeat('=', m)
    end select

    ! Print trailing blank line
    write(unit, *)

  end subroutine header

!===============================================================================
! WRITE_MESSAGE displays an informational message to the log file and the 
! standard output stream.
!===============================================================================

  subroutine write_message(level)

    integer, optional :: level

    integer :: n_lines
    integer :: i

    ! Only allow master to print to screen
    if (.not. master .and. present(level)) return

    if (.not. present(level) .or. level <= verbosity) then
       n_lines = (len_trim(message)-1)/79 + 1
       do i = 1, n_lines
          write(ou, fmt='(1X,A)') trim(message(79*(i-1)+1:79*i))
       end do
    end if

  end subroutine write_message

!===============================================================================
! GET_TODAY determines the date and time at which the program began execution
! and returns it in a readable format
!===============================================================================

  subroutine get_today(today_date, today_time)

    character(10), intent(out) :: today_date
    character(8),  intent(out) :: today_time

    integer       :: val(8)
    character(8)  :: date_
    character(10) :: time_
    character(5)  :: zone

    call date_and_time(date_, time_, zone, val)
    ! val(1) = year (YYYY)
    ! val(2) = month (MM)
    ! val(3) = day (DD)
    ! val(4) = timezone
    ! val(5) = hours (HH)
    ! val(6) = minutes (MM)
    ! val(7) = seconds (SS)
    ! val(8) = milliseconds

    if (val(2) < 10) then
       if (val(3) < 10) then
          today_date = date_(6:6) // "/" // date_(8:8) // "/" // date_(1:4)
       else
          today_date = date_(6:6) // "/" // date_(7:8) // "/" // date_(1:4)
       end if
    else
       if (val(3) < 10) then
          today_date = date_(5:6) // "/" // date_(8:8) // "/" // date_(1:4)
       else
          today_date = date_(5:6) // "/" // date_(7:8) // "/" // date_(1:4)
       end if
    end if
    today_time = time_(1:2) // ":" // time_(3:4) // ":" // time_(5:6)

  end subroutine get_today

!===============================================================================
! PRINT_PARTICLE displays the attributes of a particle
!===============================================================================

  subroutine print_particle(p)

    type(Particle), pointer :: p

    type(Cell),     pointer :: c => null()
    type(Surface),  pointer :: s => null()
    type(Universe), pointer :: u => null()

    select case (p % type)
    case (NEUTRON)
       write(ou,*) 'Neutron ' // int_to_str(p % id)
    case (PHOTON)
       write(ou,*) 'Photon ' // int_to_str(p % id)
    case (ELECTRON)
       write(ou,*) 'Electron ' // int_to_str(p % id)
    case default
       write(ou,*) 'Unknown Particle ' // int_to_str(p % id)
    end select
    write(ou,*) '    x = ' // real_to_str(p % coord0 % xyz(1))
    write(ou,*) '    y = ' // real_to_str(p % coord0 % xyz(2))
    write(ou,*) '    z = ' // real_to_str(p % coord0 % xyz(3))
    write(ou,*) '    x local = ' // real_to_str(p % coord % xyz(1))
    write(ou,*) '    y local = ' // real_to_str(p % coord % xyz(2))
    write(ou,*) '    z local = ' // real_to_str(p % coord % xyz(3))
    write(ou,*) '    u = ' // real_to_str(p % coord0 % uvw(1))
    write(ou,*) '    v = ' // real_to_str(p % coord0 % uvw(2))
    write(ou,*) '    w = ' // real_to_str(p % coord0 % uvw(3))
    write(ou,*) '    Weight = ' // real_to_str(p % wgt)
    write(ou,*) '    Energy = ' // real_to_str(p % E)
    write(ou,*) '    x index = ' // int_to_str(p % coord % lattice_x)
    write(ou,*) '    y index = ' // int_to_str(p % coord % lattice_y)
    write(ou,*) '    IE = ' // int_to_str(p % IE)
    write(ou,*) '    Interpolation factor = ' // real_to_str(p % interp)

    if (p % coord % cell /= NONE) then
       c => cells(p % coord % cell)
       write(ou,*) '    Cell = ' // int_to_str(c % id)
    else
       write(ou,*) '    Cell not determined'
    end if

    if (p % surface /= NONE) then
       s => surfaces(p % surface)
       write(ou,*) '    Surface = ' // int_to_str(s % id)
    else
       write(ou,*) '    Surface = None'
    end if

    u => universes(p % coord % universe)
    write(ou,*) '    Universe = ' // int_to_str(u % id)
    write(ou,*)

  end subroutine print_particle

!===============================================================================
! PRINT_REACTION displays the attributes of a reaction
!===============================================================================

  subroutine print_reaction(rxn)

    type(Reaction), pointer :: rxn

    write(ou,*) 'Reaction ' // reaction_name(rxn % MT)
    write(ou,*) '    MT = ' // int_to_str(rxn % MT)
    write(ou,*) '    Q-value = ' // real_to_str(rxn % Q_value)
    write(ou,*) '    TY = ' // int_to_str(rxn % TY)
    write(ou,*) '    Starting index = ' // int_to_str(rxn % IE)
    if (rxn % has_energy_dist) then
       write(ou,*) '    Energy: Law ' // int_to_str(rxn % edist % law)
    end if
    write(ou,*)

  end subroutine print_reaction

!===============================================================================
! PRINT_CELL displays the attributes of a cell
!===============================================================================

  subroutine print_cell(c)

    type(Cell), pointer :: c

    integer                 :: temp
    integer                 :: i
    character(MAX_LINE_LEN) :: string
    type(Universe), pointer :: u => null()
    type(Lattice),  pointer :: l => null()
    type(Material), pointer :: m => null()

    write(ou,*) 'Cell ' // int_to_str(c % id)
    temp = dict_get_key(cell_dict, c % id)
    write(ou,*) '    Array Index = ' // int_to_str(temp)
    u => universes(c % universe)
    write(ou,*) '    Universe = ' // int_to_str(u % id)
    select case (c % type)
    case (CELL_NORMAL)
       write(ou,*) '    Fill = NONE'
    case (CELL_FILL)
       u => universes(c % fill)
       write(ou,*) '    Fill = Universe ' // int_to_str(u % id)
    case (CELL_LATTICE)
       l => lattices(c % fill)
       write(ou,*) '    Fill = Lattice ' // int_to_str(l % id)
    end select
    if (c % material == 0) then
       write(ou,*) '    Material = NONE'
    else
       m => materials(c % material)
       write(ou,*) '    Material = ' // int_to_str(m % id)
    end if
    write(ou,*) '    Parent Cell = ' // int_to_str(c % parent)
    string = ""
    do i = 1, c % n_surfaces
       select case (c % surfaces(i))
       case (OP_LEFT_PAREN)
          string = trim(string) // ' ('
       case (OP_RIGHT_PAREN)
          string = trim(string) // ' )'
       case (OP_UNION)
          string = trim(string) // ' :'
       case (OP_DIFFERENCE)
          string = trim(string) // ' !'
       case default
          string = trim(string) // ' ' // int_to_str(c % surfaces(i))
       end select
    end do
    write(ou,*) '    Surface Specification:' // trim(string)
    write(ou,*)

  end subroutine print_cell

!===============================================================================
! PRINT_UNIVERSE displays the attributes of a universe
!===============================================================================

  subroutine print_universe(univ)

    type(Universe), pointer :: univ

    integer                 :: i
    character(MAX_LINE_LEN) :: string
    type(Cell), pointer     :: c => null()

    write(ou,*) 'Universe ' // int_to_str(univ % id)
    write(ou,*) '    Level = ' // int_to_str(univ % level)
    string = ""
    do i = 1, univ % n_cells
       c => cells(univ % cells(i))
       string = trim(string) // ' ' // int_to_str(c % id)
    end do
    write(ou,*) '    Cells =' // trim(string)
    write(ou,*)

  end subroutine print_universe

!===============================================================================
! PRINT_LATTICE displays the attributes of a lattice
!===============================================================================

  subroutine print_lattice(lat)

    type(Lattice), pointer :: lat

    write(ou,*) 'Lattice ' // int_to_str(lat % id)
    write(ou,*) '    n_x = ' // int_to_str(lat % n_x)
    write(ou,*) '    n_y = ' // int_to_str(lat % n_y)
    write(ou,*) '    x0 = ' // real_to_str(lat % x0)
    write(ou,*) '    y0 = ' // real_to_str(lat % y0)
    write(ou,*) '    width_x = ' // real_to_str(lat % width_x)
    write(ou,*) '    width_y = ' // real_to_str(lat % width_y)
    write(ou,*)

  end subroutine print_lattice

!===============================================================================
! PRINT_SURFACE displays the attributes of a surface
!===============================================================================

  subroutine print_surface(surf)

    type(Surface), pointer :: surf

    integer :: i
    character(MAX_LINE_LEN) :: string

    write(ou,*) 'Surface ' // int_to_str(surf % id)
    select case (surf % type)
    case (SURF_PX)
       string = "X Plane"
    case (SURF_PY)
       string = "Y Plane"
    case (SURF_PZ)
       string = "Z Plane"
    case (SURF_PLANE)
       string = "Plane"
    case (SURF_CYL_X)
       string = "X Cylinder"
    case (SURF_CYL_Y)
       string = "Y Cylinder"
    case (SURF_CYL_Z)
       string = "Z Cylinder"
    case (SURF_SPHERE)
       string = "Sphere"
    case (SURF_BOX_X)
    case (SURF_BOX_Y)
    case (SURF_BOX_Z)
    case (SURF_BOX)
    case (SURF_GQ)
       string = "General Quadratic"
    end select
    write(ou,*) '    Type = ' // trim(string)

    string = ""
    do i = 1, size(surf % coeffs)
       string = trim(string) // ' ' // real_to_str(surf % coeffs(i), 4)
    end do
    write(ou,*) '    Coefficients = ' // trim(string)

    string = ""
    if (allocated(surf % neighbor_pos)) then
       do i = 1, size(surf % neighbor_pos)
          string = trim(string) // ' ' // int_to_str(surf % neighbor_pos(i))
       end do
    end if
    write(ou,*) '    Positive Neighbors = ' // trim(string)

    string = ""
    if (allocated(surf % neighbor_neg)) then
       do i = 1, size(surf % neighbor_neg)
          string = trim(string) // ' ' // int_to_str(surf % neighbor_neg(i))
       end do
    end if
    write(ou,*) '    Negative Neighbors =' // trim(string)
    select case (surf % bc)
    case (BC_TRANSMIT)
       write(ou,*) '    Boundary Condition = Transmission'
    case (BC_VACUUM)
       write(ou,*) '    Boundary Condition = Vacuum'
    case (BC_REFLECT)
       write(ou,*) '    Boundary Condition = Reflective'
    case (BC_PERIODIC)
       write(ou,*) '    Boundary Condition = Periodic'
    end select
    write(ou,*)

  end subroutine print_surface

!===============================================================================
! PRINT_MATERIAL displays the attributes of a material
!===============================================================================

  subroutine print_material(mat)

    type(Material), pointer :: mat

    integer                 :: i
    real(8)                 :: density
    character(MAX_LINE_LEN) :: string
    type(Nuclide),  pointer :: nuc => null()

    ! Write identifier for material
    write(ou,*) 'Material ' // int_to_str(mat % id)

    ! Write total atom density in atom/b-cm
    write(ou,*) '    Atom Density = ' // trim(real_to_str(mat % density)) &
         & // ' atom/b-cm'

    ! Write atom density for each nuclide in material
    write(ou,*) '    Nuclides:'
    do i = 1, mat % n_nuclides
       nuc => nuclides(mat % nuclide(i))
       density = mat % atom_density(i)
       string = '        ' // trim(nuc % name) // ' = ' // &
            & trim(real_to_str(density)) // ' atom/b-cm'
       write(ou,*) trim(string)
    end do

    ! Write information on S(a,b) table
    if (mat % has_sab_table) then
       write(ou,*) '    S(a,b) table = ' // trim(mat % sab_name)
    end if
    write(ou,*)

  end subroutine print_material

!===============================================================================
! PRINT_TALLY displays the attributes of a tally
!===============================================================================

  subroutine print_tally(t)

    type(TallyObject), pointer :: t

    integer                       :: i
    integer                       :: id
    character(MAX_LINE_LEN)       :: string
    type(Cell),           pointer :: c => null()
    type(Surface),        pointer :: s => null()
    type(Universe),       pointer :: u => null()
    type(Material),       pointer :: m => null()
    type(StructuredMesh), pointer :: sm => null()

    write(ou,*) 'Tally ' // int_to_str(t % id)

    if (t % n_bins(T_CELL) > 0) then
       string = ""
       do i = 1, t % n_bins(T_CELL)
          id = t % cell_bins(i) % scalar
          c => cells(id)
          string = trim(string) // ' ' // trim(int_to_str(c % id))
       end do
       write(ou, *) '    Cell Bins:' // trim(string)
    end if

    if (t % n_bins(T_SURFACE) > 0) then
       string = ""
       do i = 1, t % n_bins(T_SURFACE)
          id = t % surface_bins(i) % scalar
          s => surfaces(id)
          string = trim(string) // ' ' // trim(int_to_str(s % id))
       end do
       write(ou, *) '    Surface Bins:' // trim(string)
    end if

    if (t % n_bins(T_UNIVERSE) > 0) then
       string = ""
       do i = 1, t % n_bins(T_UNIVERSE)
          id = t % universe_bins(i) % scalar
          u => universes(id)
          string = trim(string) // ' ' // trim(int_to_str(u % id))
       end do
       write(ou, *) '    Material Bins:' // trim(string)
    end if

    if (t % n_bins(T_MATERIAL) > 0) then
       string = ""
       do i = 1, t % n_bins(T_MATERIAL)
          id = t % material_bins(i) % scalar
          m => materials(id)
          string = trim(string) // ' ' // trim(int_to_str(m % id))
       end do
       write(ou, *) '    Material Bins:' // trim(string)
    end if

    if (t % n_bins(T_MESH) > 0) then
       string = ""
       id = t % mesh
       sm => meshes(id)
       string = trim(string) // ' ' // trim(int_to_str(sm % dimension(1)))
       do i = 2, sm % n_dimension
          string = trim(string) // ' x ' // trim(int_to_str(sm % dimension(i)))
       end do
       write(ou, *) '    Mesh Bins:' // trim(string)
    end if

    if (t % n_bins(T_CELLBORN) > 0) then
       string = ""
       do i = 1, t % n_bins(T_CELLBORN)
          id = t % cellborn_bins(i) % scalar
          c => cells(id)
          string = trim(string) // ' ' // trim(int_to_str(c % id))
       end do
       write(ou, *) '    Birth Region Bins:' // trim(string)
    end if

    if (t % n_bins(T_ENERGYIN) > 0) then
       string = ""
       do i = 1, t % n_bins(T_ENERGYIN) + 1
          string = trim(string) // ' ' // trim(real_to_str(&
               t % energy_in(i)))
       end do
       write(ou,*) '    Incoming Energy Bins:' // trim(string)
    end if

    if (t % n_bins(T_ENERGYOUT) > 0) then
       string = ""
       do i = 1, t % n_bins(T_ENERGYOUT) + 1
          string = trim(string) // ' ' // trim(real_to_str(&
               t % energy_out(i)))
       end do
       write(ou,*) '    Outgoing Energy Bins:' // trim(string)
    end if

    if (t % n_macro_bins > 0) then
       string = ""
       do i = 1, t % n_macro_bins
          select case (t % macro_bins(i) % scalar)
          case (MACRO_FLUX)
             string = trim(string) // ' flux'
          case (MACRO_TOTAL)
             string = trim(string) // ' total'
          case (MACRO_SCATTER)
             string = trim(string) // ' scatter'
          case (MACRO_ABSORPTION)
             string = trim(string) // ' absorption'
          case (MACRO_FISSION)
             string = trim(string) // ' fission'
          case (MACRO_NU_FISSION)
             string = trim(string) // ' nu-fission'
          end select
       end do
       write(ou,*) '    Macro Reactions:' // trim(string)
    end if
    write(ou,*)

  end subroutine print_tally

!===============================================================================
! PRINT_GEOMETRY displays the attributes of all cells, surfaces, universes,
! surfaces, and lattices read in the input files.
!===============================================================================

  subroutine print_geometry()

    integer :: i
    type(Surface),     pointer :: s => null()
    type(Cell),        pointer :: c => null()
    type(Universe),    pointer :: u => null()
    type(Lattice),     pointer :: l => null()

    ! print summary of cells
    call header("CELL SUMMARY")
    do i = 1, n_cells
       c => cells(i)
       call print_cell(c)
    end do

    ! print summary of universes
    call header("UNIVERSE SUMMARY")
    do i = 1, n_universes
       u => universes(i)
       call print_universe(u)
    end do

    ! print summary of lattices
    if (n_lattices > 0) then
       call header("LATTICE SUMMARY")
       do i = 1, n_lattices
          l => lattices(i)
          call print_lattice(l)
       end do
    end if

    ! print summary of surfaces
    call header("SURFACE SUMMARY")
    do i = 1, n_surfaces
       s => surfaces(i)
       call print_surface(s)
    end do

  end subroutine print_geometry

!===============================================================================
! PRINT_SUMMARY displays summary information about the problem about to be run
! after reading all input files
!===============================================================================

  subroutine print_summary()

    integer :: i
    character(15) :: string
    type(Material),    pointer :: m => null()
    type(TallyObject), pointer :: t => null()

    ! Display problem summary
    call header("PROBLEM SUMMARY")
    if (problem_type == PROB_CRITICALITY) then
       write(ou,100) 'Problem type:', 'Criticality'
       write(ou,101) 'Number of Cycles:', n_cycles
       write(ou,101) 'Number of Inactive Cycles:', n_inactive
    elseif (problem_type == PROB_SOURCE) then
       write(ou,100) 'Problem type:', 'External Source'
    end if
    write(ou,101) 'Number of Particles:', n_particles

    ! Display geometry summary
    call header("GEOMETRY SUMMARY")
    write(ou,101) 'Number of Cells:', n_cells
    write(ou,101) 'Number of Surfaces:', n_surfaces
    write(ou,101) 'Number of Materials:', n_materials

    ! print summary of all geometry
    call print_geometry()

    ! print summary of materials
    call header("MATERIAL SUMMARY")
    do i = 1, n_materials
       m => materials(i)
       call print_material(m)
    end do

    ! print summary of tallies
    if (n_tallies > 0) then
       call header("TALLY SUMMARY")
       do i = 1, n_tallies
          t=> tallies(i)
          call print_tally(t)
       end do
    end if

    ! print summary of unionized energy grid
    call header("UNIONIZED ENERGY GRID")
    write(ou,*) "Points on energy grid:  " // trim(int_to_str(n_grid))
    write(ou,*) "Extra storage required: " // trim(int_to_str(&
         n_grid*n_nuclides_total*4)) // " bytes"

    ! print summary of variance reduction
    call header("VARIANCE REDUCTION")
    if (survival_biasing) then
       write(ou,100) "Survival Biasing:", "on"
    else
       write(ou,100) "Survival Biasing:", "off"
    end if
    string = real_to_str(weight_cutoff)
    write(ou,100) "Weight Cutoff:", trim(string)
    string = real_to_str(weight_survive)
    write(ou,100) "Survival weight:", trim(string)
    write(ou,*)

    ! Format descriptor for columns
100 format (1X,A,T35,A)
101 format (1X,A,T35,I11)


  end subroutine print_summary

!===============================================================================
! PRINT_PLOT displays selected options for plotting
!===============================================================================

  subroutine print_plot()

    ! Display header for plotting
    call header("PLOTTING SUMMARY")

    ! Print plotting origin
    write(ou,100) "Plotting Origin:", trim(real_to_str(plot_origin(1))) // &
         " " // trim(real_to_str(plot_origin(2))) // " " // &
         trim(real_to_str(plot_origin(3)))

    ! Print plotting width
    write(ou,100) "Plotting Width:", trim(real_to_str(plot_width(1))) // &
         " " // trim(real_to_str(plot_width(2)))

    ! Print pixel width
    write(ou,100) "Pixel Width:", trim(real_to_str(pixel))
    write(ou,*)

    ! Format descriptor for columns
100 format (1X,A,T25,A)

  end subroutine print_plot

!===============================================================================
! PRINT_RUNTIME displays the total time elapsed for the entire run, for
! initialization, for computation, and for intercycle synchronization.
!===============================================================================

  subroutine print_runtime()

    integer(8)    :: total_particles
    real(8)       :: speed
    character(15) :: string

    ! display header block
    call header("Timing Statistics")

    ! display time elapsed for various sections
    write(ou,100) "Total time for initialization", time_initialize % elapsed
    write(ou,100) "  Reading cross sections", time_read_xs % elapsed
    write(ou,100) "  Unionizing energy grid", time_unionize % elapsed
    write(ou,100) "Total time in computation", time_compute % elapsed
    write(ou,100) "Total time between cycles", time_intercycle % elapsed
    write(ou,100) "  Accumulating tallies", time_ic_tallies % elapsed
    write(ou,100) "  Sampling source sites", time_ic_sample % elapsed
    write(ou,100) "  SEND/RECV source sites", time_ic_sendrecv % elapsed
    write(ou,100) "  Reconstruct source bank", time_ic_rebuild % elapsed
    write(ou,100) "Total time in inactive cycles", time_inactive % elapsed
    write(ou,100) "Total time in active cycles", time_active % elapsed
    write(ou,100) "Total time elapsed", time_total % elapsed

    ! display header block
    call header("Run Statistics")

    ! display calculate rate and final keff
    total_particles = n_particles * n_cycles
    speed = real(total_particles) / time_compute % elapsed
    string = real_to_str(speed)
    write(ou,101) "Calculation Rate", trim(string)
    write(ou,102) "Final Keff", keff, keff_std
    write(ou,*)

    ! format for write statements
100 format (1X,A,T35,"= ",ES11.4," seconds")
101 format (1X,A,T20,"= ",A," neutrons/second")
102 format (1X,A,T20,"= ",F8.5," +/- ",F8.5)
 
  end subroutine print_runtime

end module output
