!========================================================================
!
!                   S P E C F E M 2 D  Version 7 . 0
!                   --------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently maNZ_IMAGE_color more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This software is a computer program whose purpose is to solve
! the two-dimensional viscoelastic anisotropic or poroelastic wave equation
! using a spectral-element method (SEM).
!
! This software is governed by the CeCILL license under French law and
! abiding by the rules of distribution of free software. You can use,
! modify and/or redistribute the software under the terms of the CeCILL
! license as circulated by CEA, CNRS and Inria at the following URL
! "http://www.cecill.info".
!
! As a counterpart to the access to the source code and rights to copy,
! modify and redistribute granted by the license, users are provided only
! with a limited warranty and the software's author, the holder of the
! economic rights, and the successive licensors have only limited
! liability.
!
! In this respect, the user's attention is drawn to the risks associated
! with loading, using, modifying and/or developing or reproducing the
! software by the user in light of its specific status of free software,
! that may mean that it is complicated to manipulate, and that also
! therefore means that it is reserved for developers and experienced
! professionals having in-depth computer knowledge. Users are therefore
! encouraged to load and test the software's suitability as regards their
! requirements in conditions enabling the security of their systems and/or
! data to be ensured and, more generally, to use and operate it in the
! same conditions as regards security.
!
! The full text of the license is available in file "LICENSE".
!
!========================================================================

  subroutine write_movie_output()

! outputs snapshots for movies

  use specfem_par
  use specfem_par_gpu,only: Mesh_pointer,tmp_displ_2D,tmp_veloc_2D,tmp_accel_2D,NGLOB_AB
  use specfem_par_noise,only: NOISE_TOMOGRAPHY,output_wavefields_noise,mask_noise, &
                              surface_movie_y_noise,noise_output_rhokl,noise_output_array,noise_output_ncol

  implicit none

  ! local parameters
  integer :: ier
  logical :: ex, od
  character(len=MAX_STRING_LEN) :: noise_output_file

  ! checks if anything to do
  if (.not. (mod(it,NSTEP_BETWEEN_OUTPUT_IMAGES) == 0 .or. it == 5 .or. it == NSTEP)) return

  ! transfers arrays from GPU to CPU
  if (GPU_MODE) then
    ! Fields transfer for imaging
    ! acoustic domains
    if (any_acoustic ) then
      call transfer_fields_ac_from_device(NGLOB_AB,potential_acoustic,potential_dot_acoustic, &
                                          potential_dot_dot_acoustic,Mesh_pointer)
    endif
    ! elastic domains
    if (any_elastic) then
      call transfer_fields_el_from_device(NDIM*NGLOB_AB,tmp_displ_2D,tmp_veloc_2D,tmp_accel_2D,Mesh_pointer)
      if (p_sv) then
        ! P-SV waves
        displ_elastic(1,:) = tmp_displ_2D(1,:)
        displ_elastic(3,:) = tmp_displ_2D(2,:)
        veloc_elastic(1,:) = tmp_veloc_2D(1,:)
        veloc_elastic(3,:) = tmp_veloc_2D(2,:)
        accel_elastic(1,:) = tmp_accel_2D(1,:)
        accel_elastic(3,:) = tmp_accel_2D(2,:)
      else
        ! SH waves
        displ_elastic(2,:) = tmp_displ_2D(1,:)
        veloc_elastic(2,:) = tmp_veloc_2D(1,:)
        accel_elastic(2,:) = tmp_accel_2D(1,:)
      endif
    endif
  endif

  ! noise simulations
  if (.not. GPU_MODE) then
    if (NOISE_TOMOGRAPHY == 3 .and. output_wavefields_noise) then

      ! load ensemble forward source
      inquire(unit=500,exist=ex,opened=od)
      if (.not. od) then
        open(unit=500,file='OUTPUT_FILES/NOISE_TOMOGRAPHY/eta',access='direct',recl = nglob * CUSTOM_REAL, &
             action='write',iostat=ier)
        if (ier /= 0) call exit_MPI(myrank,'Error opening noise eta file')
      endif
      read(unit=500,rec=it) surface_movie_y_noise

      ! load product of fwd, adj wavefields
      call spec2glob(nspec,nglob,ibool,rho_kl,noise_output_rhokl)

      ! prepares array
      noise_output_array(1,:) = surface_movie_y_noise(:) * mask_noise(:)
      noise_output_array(2,:) = b_displ_elastic(2,:)
      noise_output_array(3,:) = accel_elastic(2,:)
      noise_output_array(4,:) = rho_k(:)
      noise_output_array(5,:) = noise_output_rhokl(:)

      !write text file
      write(noise_output_file,"('OUTPUT_FILES/snapshot_all_',i6.6)") it

      call snapshots_noise(noise_output_ncol,nglob,noise_output_file,noise_output_array)
    endif
  endif

  ! output_postscript_snapshot
  if (output_postscript_snapshot) then
    call write_postscript_snapshot()
  endif

  ! display color image
  if (output_color_image) then
    call write_color_image_snaphot()
  endif

  ! dump the full (local) wavefield to a file
  ! note: in the case of MPI, in the future it would be more convenient to output a single file
  !       rather than one for each myrank
  if (output_wavefield_dumps) then
    call write_wavefield_dumps()
  endif

  end subroutine write_movie_output


