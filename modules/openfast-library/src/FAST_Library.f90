!  FAST_Library.f90 
!
!  FUNCTIONS/SUBROUTINES exported from FAST_Library.dll:
!  FAST_Start  - subroutine 
!  FAST_Update - subroutine 
!  FAST_End    - subroutine 
!   
! DO NOT REMOVE or MODIFY LINES starting with "!DEC$" or "!GCC$"
! !DEC$ specifies attributes for IVF and !GCC$ specifies attributes for gfortran
!
!==================================================================================================================================  
MODULE FAST_Data

   USE, INTRINSIC :: ISO_C_Binding
   USE FAST_Subs   ! all of the ModuleName and ModuleName_types modules are inherited from FAST_Subs
                       
   IMPLICIT  NONE
   SAVE
   
      ! Local parameters:
   REAL(DbKi),     PARAMETER             :: t_initial = 0.0_DbKi     ! Initial time
   INTEGER(IntKi)                        :: NumTurbines 
   INTEGER(IntKi), PARAMETER             :: MAXOUTPUTS = 4000        ! Maximum number of outputs
   INTEGER(IntKi), PARAMETER             :: MAXInitINPUTS = 10       ! Maximum number of initialization values from Simulink
   INTEGER(IntKi), PARAMETER             :: NumFixedInputs = 8
   
   
      ! Global (static) data:
   TYPE(FAST_TurbineType), ALLOCATABLE   :: Turbine(:)               ! Data for each turbine
   INTEGER(IntKi)                        :: n_t_global               ! simulation time step, loop counter for global (FAST) simulation
   INTEGER(IntKi)                        :: ErrStat                  ! Error status
   CHARACTER(IntfStrLen-1)               :: ErrMsg                   ! Error message  (this needs to be static so that it will print in Matlab's mex library)
   
contains
!================================================================================================================================== 
subroutine FAST_AllocateTurbines(nTurbines, ErrStat_c, ErrMsg_c) BIND (C, NAME='FAST_AllocateTurbines')
   IMPLICIT NONE 
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_AllocateTurbines
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_AllocateTurbines
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: nTurbines
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen) 
   
   if (nTurbines .gt. 0) then
      NumTurbines = nTurbines
   end if
   
   if (nTurbines .gt. 10) then
      call wrscr1('Number of turbines is > 10! Are you sure you have enough memory?')
      call wrscr1('Proceeding anyway')
   end if

   allocate(Turbine(0:NumTurbines-1),Stat=ErrStat) !Allocate in C style because most of the other Turbine properties from the input file are in C style inside the C++ driver

   if (ErrStat /= 0) then
      ErrStat_c = ErrID_Fatal
      ErrMsg    = "Error allocating turbine data."//C_NULL_CHAR
   else
      ErrStat_c = ErrID_None
      ErrMsg = " "//C_NULL_CHAR
   end if
   ErrMsg_c  = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
   
end subroutine FAST_AllocateTurbines
!==================================================================================================================================
subroutine FAST_DeallocateTurbines(ErrStat_c, ErrMsg_c) BIND (C, NAME='FAST_DeallocateTurbines')
   IMPLICIT NONE
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_DeallocateTurbines
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_DeallocateTurbines
#endif
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen)

   if (Allocated(Turbine)) then
      deallocate(Turbine)
   end if

   ErrStat_c = ErrID_None
   ErrMsg_c = C_NULL_CHAR
end subroutine
!==================================================================================================================================
subroutine FAST_Sizes(iTurb, TMax, InitInpAry, InputFileName_c, AbortErrLev_c, NumOuts_c, dt_c, ErrStat_c, ErrMsg_c, ChannelNames_c) BIND (C, NAME='FAST_Sizes')
   IMPLICIT NONE 
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_Sizes
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_Sizes
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   REAL(C_DOUBLE),         INTENT(IN   ) :: TMax      
   REAL(C_DOUBLE),         INTENT(IN   ) :: InitInpAry(MAXInitINPUTS)      
   CHARACTER(KIND=C_CHAR), INTENT(IN   ) :: InputFileName_c(IntfStrLen)      
   INTEGER(C_INT),         INTENT(  OUT) :: AbortErrLev_c      
   INTEGER(C_INT),         INTENT(  OUT) :: NumOuts_c      
   REAL(C_DOUBLE),         INTENT(  OUT) :: dt_c      
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c      
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen) 
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ChannelNames_c(ChanLen*MAXOUTPUTS+1)
   
   ! local
   CHARACTER(IntfStrLen)               :: InputFileName   
   INTEGER                             :: i, j, k
   TYPE(FAST_ExternInitType)           :: ExternInitData
   
      ! transfer the character array from C to a Fortran string:   
   InputFileName = TRANSFER( InputFileName_c, InputFileName )
   I = INDEX(InputFileName,C_NULL_CHAR) - 1            ! if this has a c null character at the end...
   IF ( I > 0 ) InputFileName = InputFileName(1:I)     ! remove it
   
      ! initialize variables:   
   n_t_global = 0
   
   ExternInitData%TMax       = TMax
   ExternInitData%TurbineID  = -1        ! we're not going to use this to simulate a wind farm
   ExternInitData%TurbinePos = 0.0_ReKi  ! turbine position is at the origin
   ExternInitData%NumCtrl2SC = 0
   ExternInitData%NumSC2Ctrl = 0
   ExternInitData%SensorType = NINT(InitInpAry(1))   
   ! -- MATLAB Integration --
   ! Make sure fast farm integration is false
   ExternInitData%FarmIntegration = .false.

   IF ( NINT(InitInpAry(2)) == 1 ) THEN
      ExternInitData%LidRadialVel = .true.
   ELSE
      ExternInitData%LidRadialVel = .false.
   END IF
   
   
   
   CALL FAST_InitializeAll_T( t_initial, 1_IntKi, Turbine(iTurb), ErrStat, ErrMsg, InputFileName, ExternInitData )
                  
   AbortErrLev_c = AbortErrLev   
   NumOuts_c     = min(MAXOUTPUTS, 1 + SUM( Turbine(iTurb)%y_FAST%numOuts )) ! includes time
   dt_c          = Turbine(iTurb)%p_FAST%dt

   ErrStat_c     = ErrStat
   ErrMsg        = TRIM(ErrMsg)//C_NULL_CHAR
   ErrMsg_c      = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
   
#ifdef CONSOLE_FILE   
   if (ErrStat /= ErrID_None) call wrscr1(trim(ErrMsg))
#endif   
    
      ! return the names of the output channels
   IF ( ALLOCATED( Turbine(iTurb)%y_FAST%ChannelNames ) )  then
      k = 1;
      DO i=1,NumOuts_c
         DO j=1,ChanLen
            ChannelNames_c(k)=Turbine(iTurb)%y_FAST%ChannelNames(i)(j:j)
            k = k+1
         END DO
      END DO
      ChannelNames_c(k) = C_NULL_CHAR
   ELSE
      ChannelNames_c = C_NULL_CHAR
   END IF
      
end subroutine FAST_Sizes
!==================================================================================================================================
subroutine FAST_Start(iTurb, NumInputs_c, NumOutputs_c, InputAry, OutputAry, ErrStat_c, ErrMsg_c) BIND (C, NAME='FAST_Start')
   IMPLICIT NONE 
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_Start
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_Start
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   INTEGER(C_INT),         INTENT(IN   ) :: NumInputs_c      
   INTEGER(C_INT),         INTENT(IN   ) :: NumOutputs_c      
   REAL(C_DOUBLE),         INTENT(IN   ) :: InputAry(NumInputs_c)
   REAL(C_DOUBLE),         INTENT(  OUT) :: OutputAry(NumOutputs_c)
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c      
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen)      

   
   ! local
   CHARACTER(IntfStrLen)                 :: InputFileName   
   INTEGER                               :: i
   REAL(ReKi)                            :: Outputs(NumOutputs_c-1)
     
   INTEGER(IntKi)                        :: ErrStat2                                ! Error status
   CHARACTER(IntfStrLen-1)               :: ErrMsg2                                 ! Error message  (this needs to be static so that it will print in Matlab's mex library)
   
      ! initialize variables:   
   n_t_global = 0

#ifdef SIMULINK_DirectFeedThrough   
   IF(  NumInputs_c /= NumFixedInputs .AND. NumInputs_c /= NumFixedInputs+3 ) THEN
      ErrStat_c = ErrID_Fatal
      ErrMsg  = "FAST_Start:size of InputAry is invalid."//C_NULL_CHAR
      ErrMsg_c  = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
      RETURN
   END IF

   CALL FAST_SetExternalInputs(iTurb, NumInputs_c, InputAry, Turbine(iTurb)%m_FAST)

#endif      
   !...............................................................................................................................
   ! Initialization of solver: (calculate outputs based on states at t=t_initial as well as guesses of inputs and constraint states)
   !...............................................................................................................................  
   CALL FAST_Solution0_T(Turbine(iTurb), ErrStat, ErrMsg )      
   
   if (ErrStat <= AbortErrLev) then
         ! return outputs here, too
      IF(NumOutputs_c /= SIZE(Turbine(iTurb)%y_FAST%ChannelNames) ) THEN
         ErrStat = ErrID_Fatal
         ErrMsg  = trim(ErrMsg)//NewLine//"FAST_Start:size of NumOutputs is invalid."
      ELSE
      
         CALL FillOutputAry_T(Turbine(iTurb), Outputs)   
         OutputAry(1)              = Turbine(iTurb)%m_FAST%t_global 
         OutputAry(2:NumOutputs_c) = Outputs 

         CALL FAST_Linearize_T(t_initial, 0, Turbine(iTurb), ErrStat, ErrMsg)
         if (ErrStat2 /= ErrID_None) then
            ErrStat = max(ErrStat,ErrStat2)
            ErrMsg = TRIM(ErrMsg)//NewLine//TRIM(ErrMsg2)
         end if
         
                  
      END IF
   end if
   
   
   ErrStat_c     = ErrStat
   ErrMsg        = TRIM(ErrMsg)//C_NULL_CHAR
   ErrMsg_c      = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
   
#ifdef CONSOLE_FILE   
   if (ErrStat /= ErrID_None) call wrscr1(trim(ErrMsg))
#endif   
      
end subroutine FAST_Start
!==================================================================================================================================
subroutine FAST_Update(iTurb, NumInputs_c, NumOutputs_c, InputAry, OutputAry, ErrStat_c, ErrMsg_c) BIND (C, NAME='FAST_Update')
   IMPLICIT NONE
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_Update
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_Update
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   INTEGER(C_INT),         INTENT(IN   ) :: NumInputs_c      
   INTEGER(C_INT),         INTENT(IN   ) :: NumOutputs_c      
   REAL(C_DOUBLE),         INTENT(IN   ) :: InputAry(NumInputs_c)
   REAL(C_DOUBLE),         INTENT(  OUT) :: OutputAry(NumOutputs_c)
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c      
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen)      
   
      ! local variables
   REAL(ReKi)                            :: Outputs(NumOutputs_c-1)
   INTEGER(IntKi)                        :: i
   INTEGER(IntKi)                        :: ErrStat2                                ! Error status
   CHARACTER(IntfStrLen-1)               :: ErrMsg2                                 ! Error message  (this needs to be static so that it will print in Matlab's mex library)
                 
   
   IF ( n_t_global > Turbine(iTurb)%p_FAST%n_TMax_m1 ) THEN !finish 
      
      ! we can't continue because we might over-step some arrays that are allocated to the size of the simulation

      IF (n_t_global == Turbine(iTurb)%p_FAST%n_TMax_m1 + 1) THEN  ! we call update an extra time in Simulink, which we can ignore until the time shift with outputs is solved
         n_t_global = n_t_global + 1
         ErrStat_c = ErrID_None
         ErrMsg = C_NULL_CHAR
         ErrMsg_c = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
      ELSE     
         ErrStat_c = ErrID_Info
         ErrMsg = "Simulation completed."//C_NULL_CHAR
         ErrMsg_c = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
      END IF
      
   ELSEIF(NumOutputs_c /= SIZE(Turbine(iTurb)%y_FAST%ChannelNames) ) THEN
      ErrStat_c = ErrID_Fatal
      ErrMsg    = "FAST_Update:size of OutputAry is invalid or FAST has too many outputs."//C_NULL_CHAR
      ErrMsg_c  = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
      RETURN
   ELSEIF(  NumInputs_c /= NumFixedInputs .AND. NumInputs_c /= NumFixedInputs+3 ) THEN
      ErrStat_c = ErrID_Fatal
      ErrMsg    = "FAST_Update:size of InputAry is invalid."//C_NULL_CHAR
      ErrMsg_c  = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
      RETURN
   ELSE

      CALL FAST_SetExternalInputs(iTurb, NumInputs_c, InputAry, Turbine(iTurb)%m_FAST)

      CALL FAST_Solution_T( t_initial, n_t_global, Turbine(iTurb), ErrStat, ErrMsg )                  
      n_t_global = n_t_global + 1

      CALL FAST_Linearize_T( t_initial, n_t_global, Turbine(iTurb), ErrStat2, ErrMsg2)
      if (ErrStat2 /= ErrID_None) then
         ErrStat = max(ErrStat,ErrStat2)
         ErrMsg = TRIM(ErrMsg)//NewLine//TRIM(ErrMsg2)
      end if
      
      
      ! set the outputs for external code here...
      ! return y_FAST%ChannelNames
      
      ErrStat_c     = ErrStat
      ErrMsg        = TRIM(ErrMsg)//C_NULL_CHAR
      ErrMsg_c      = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )
   END IF
   
   CALL FillOutputAry_T(Turbine(iTurb), Outputs)   
   OutputAry(1)              = Turbine(iTurb)%m_FAST%t_global 
   OutputAry(2:NumOutputs_c) = Outputs 

#ifdef CONSOLE_FILE   
   if (ErrStat /= ErrID_None) call wrscr1(trim(ErrMsg))
#endif   
      
end subroutine FAST_Update 
!==================================================================================================================================
subroutine FAST_SetExternalInputs(iTurb, NumInputs_c, InputAry, m_FAST)

   USE, INTRINSIC :: ISO_C_Binding
   USE FAST_Types
!   USE FAST_Data, only: NumFixedInputs
   
   IMPLICIT  NONE

   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   INTEGER(C_INT),         INTENT(IN   ) :: NumInputs_c      
   REAL(C_DOUBLE),         INTENT(IN   ) :: InputAry(NumInputs_c)                   ! Inputs from Simulink
   TYPE(FAST_MiscVarType), INTENT(INOUT) :: m_FAST                                  ! Miscellaneous variables
   
         ! set the inputs from external code here...
         ! transfer inputs from Simulink to FAST
      IF ( NumInputs_c < NumFixedInputs ) RETURN ! This is an error
      
      m_FAST%ExternInput%GenTrq      = InputAry(1)
      m_FAST%ExternInput%ElecPwr     = InputAry(2)
      m_FAST%ExternInput%YawPosCom   = InputAry(3)
      m_FAST%ExternInput%YawRateCom  = InputAry(4)
      m_FAST%ExternInput%BlPitchCom  = InputAry(5:7)
      m_FAST%ExternInput%HSSBrFrac   = InputAry(8)         
            
      IF ( NumInputs_c > NumFixedInputs ) THEN  ! NumFixedInputs is the fixed number of inputs
         IF ( NumInputs_c == NumFixedInputs + 3 ) &
             m_FAST%ExternInput%LidarFocus = InputAry(9:11)
      END IF   
      
end subroutine FAST_SetExternalInputs
!==================================================================================================================================
subroutine FAST_End(iTurb, StopTheProgram) BIND (C, NAME='FAST_End')
   IMPLICIT NONE
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_End
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_End
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   LOGICAL(C_BOOL),        INTENT(IN)    :: StopTheProgram   ! flag indicating if the program should end (false if there are more turbines to end)

   CALL ExitThisProgram_T( Turbine(iTurb), ErrID_None, LOGICAL(StopTheProgram))
   
end subroutine FAST_End
!==================================================================================================================================
subroutine FAST_CreateCheckpoint(iTurb, CheckpointRootName_c, ErrStat_c, ErrMsg_c) BIND (C, NAME='FAST_CreateCheckpoint')
   IMPLICIT NONE
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_CreateCheckpoint
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_CreateCheckpoint
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   CHARACTER(KIND=C_CHAR), INTENT(IN   ) :: CheckpointRootName_c(IntfStrLen)      
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c      
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen)      
   
   ! local
   CHARACTER(IntfStrLen)                 :: CheckpointRootName   
   INTEGER(IntKi)                        :: I
   INTEGER(IntKi)                        :: Unit
             
   
      ! transfer the character array from C to a Fortran string:   
   CheckpointRootName = TRANSFER( CheckpointRootName_c, CheckpointRootName )
   I = INDEX(CheckpointRootName,C_NULL_CHAR) - 1                 ! if this has a c null character at the end...
   IF ( I > 0 ) CheckpointRootName = CheckpointRootName(1:I)     ! remove it
   
   if ( LEN_TRIM(CheckpointRootName) == 0 ) then
      CheckpointRootName = TRIM(Turbine(iTurb)%p_FAST%OutFileRoot)//'.'//trim( Num2LStr(n_t_global) )
   end if
   
      
   Unit = -1
   CALL FAST_CreateCheckpoint_T(t_initial, n_t_global, 1, Turbine(iTurb), CheckpointRootName, ErrStat, ErrMsg, Unit )

      ! transfer Fortran variables to C:      
   ErrStat_c     = ErrStat
   ErrMsg        = TRIM(ErrMsg)//C_NULL_CHAR
   ErrMsg_c      = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )


#ifdef CONSOLE_FILE   
   if (ErrStat /= ErrID_None) call wrscr1(trim(ErrMsg))
#endif   
      
end subroutine FAST_CreateCheckpoint 
!==================================================================================================================================
subroutine FAST_Restart(iTurb, CheckpointRootName_c, AbortErrLev_c, NumOuts_c, dt_c, n_t_global_c, ErrStat_c, ErrMsg_c) BIND (C, NAME='FAST_Restart')
   IMPLICIT NONE
#ifndef IMPLICIT_DLLEXPORT
!DEC$ ATTRIBUTES DLLEXPORT :: FAST_Restart
!GCC$ ATTRIBUTES DLLEXPORT :: FAST_Restart
#endif
   INTEGER(C_INT),         INTENT(IN   ) :: iTurb            ! Turbine number 
   CHARACTER(KIND=C_CHAR), INTENT(IN   ) :: CheckpointRootName_c(IntfStrLen)      
   INTEGER(C_INT),         INTENT(  OUT) :: AbortErrLev_c      
   INTEGER(C_INT),         INTENT(  OUT) :: NumOuts_c      
   REAL(C_DOUBLE),         INTENT(  OUT) :: dt_c      
   INTEGER(C_INT),         INTENT(  OUT) :: n_t_global_c      
   INTEGER(C_INT),         INTENT(  OUT) :: ErrStat_c      
   CHARACTER(KIND=C_CHAR), INTENT(  OUT) :: ErrMsg_c(IntfStrLen)      
   
   ! local
   CHARACTER(IntfStrLen)                 :: CheckpointRootName   
   INTEGER(IntKi)                        :: I
   INTEGER(IntKi)                        :: Unit
   REAL(DbKi)                            :: t_initial_out
   INTEGER(IntKi)                        :: NumTurbines_out
   CHARACTER(*),           PARAMETER     :: RoutineName = 'FAST_Restart' 
             
   
      ! transfer the character array from C to a Fortran string:   
   CheckpointRootName = TRANSFER( CheckpointRootName_c, CheckpointRootName )
   I = INDEX(CheckpointRootName,C_NULL_CHAR) - 1                 ! if this has a c null character at the end...
   IF ( I > 0 ) CheckpointRootName = CheckpointRootName(1:I)     ! remove it
   
   Unit = -1
   CALL FAST_RestoreFromCheckpoint_T(t_initial_out, n_t_global, NumTurbines_out, Turbine(iTurb), CheckpointRootName, ErrStat, ErrMsg, Unit )
   
      ! check that these are valid:
      IF (t_initial_out /= t_initial) CALL SetErrStat(ErrID_Fatal, "invalid value of t_initial.", ErrStat, ErrMsg, RoutineName )
      IF (NumTurbines_out /= 1) CALL SetErrStat(ErrID_Fatal, "invalid value of NumTurbines.", ErrStat, ErrMsg, RoutineName )
   
   
      ! transfer Fortran variables to C: 
   n_t_global_c  = n_t_global
   AbortErrLev_c = AbortErrLev   
   NumOuts_c     = min(MAXOUTPUTS, 1 + SUM( Turbine(iTurb)%y_FAST%numOuts )) ! includes time
   dt_c          = Turbine(iTurb)%p_FAST%dt      
      
   ErrStat_c     = ErrStat
   ErrMsg        = TRIM(ErrMsg)//C_NULL_CHAR
   ErrMsg_c      = TRANSFER( ErrMsg//C_NULL_CHAR, ErrMsg_c )

#ifdef CONSOLE_FILE   
   if (ErrStat /= ErrID_None) call wrscr1(trim(ErrMsg))
#endif   
      
end subroutine FAST_Restart 

END MODULE FAST_Data
