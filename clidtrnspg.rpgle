     HCOPYRIGHT('Patrik Schindler <poc@pocnet.net>, 2024-08-18')
     H*-------------------------------------------------------------------------
     H* Copyright 2021-2024 Patrik Schindler <poc@pocnet.net>.
     H*
     H* This file is part of asterisk-translate-clid. It is is free software;
     H* you can redistribute it and/or modify it under the terms of the GNU
     H* General Public License as published by the Free Software Foundation;
     H* either version 2 of the License, or (at your option) any later version.
     H*
     H* It is distributed in the hope that it will be useful, but WITHOUT ANY
     H* WARRANTY; without even the implied warranty of MERCHANTABILITY or
     H* FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
     H* for more details.
     H*
     H* You should have received a copy of the GNU General Public License along
     H* with this; if not, write to the Free Software Foundation, Inc.,
     H* 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA or get it at
     H* http://www.gnu.org/licenses/gpl.html
     H*-------------------------------------------------------------------------
     H* Compiler flags.
     HDFTACTGRP(*NO) ACTGRP(*NEW)
     H*
     H* Tweak default compiler output: Don't be too verbose.
     HOPTION(*NOXREF : *NOSECLVL : *NOSHOWCPY : *NOEXT : *NOSHOWSKP)
     H*
     H* When going prod, enable this for more speed/less CPU load.
     HOPTIMIZE(*FULL)
     H*
     H*************************************************************************
     H* List of INxx, we use:
     H*- Keys:
     H* 01..24: Command Attn Keys. (DSPF)
     H*     28: Content of DSPF Record Format has changed. (DSPF)
     H*     29: Valid Command Key pressed. (DSPF)
     H*- SFL Handling (both regular and deletion):
     H*     31: SFLDSP.
     H*     32: SFLDSPCTL.
     H*     33: SFLCLR.
     H*     34: SFLEND, EOF from Database file.
     H*- General DSPF Conditioning:
     H*     42: Indicate ADDREC/DUPREC was called. (DSPF)
     H*     43: Indicate CHGREC was called. (DSPF)
     H*     44: Indicate DSPREC was called. (DSPF)
     H* 60..69: Detail record cursor placement. (DSPF)
     H*- Other Stuff:
     H*     71: READC from Subfile EOF.
     H*     73: Suppress DSPF write in main loop (prevents enter-jumping).
     H*     77: We must handle deletion of records, since at least one record
     H*         was marked for deletion.
     H*     78: Indicate DUPREC was called.
     H*     79: Indicate that we need to reload the SFL.
     H*- Error Conditions:
     H*     81: Carry over IN91 for next dspf write.
     H*     82: Carry over IN92 for next dspf write.
     H*     83: Carry over IN93 for next dspf write.
     H*     84: Carry over IN94 for next dspf write.
     H*     85: Carry over IN95 for next dspf write.
     H*     91: Record was not found (deleted?). (ERR0012)
     H*     92: Tried to insert duplicate record. (ERR1021)
     H*     93: Locked record is not available for change/deletion. (ERR1218)
     H*     94: Locked record has been opened read only. (RDO1218)
     H*     95: Record has not been written, because no change. (INF0001)
     H*     96: Subfile is full. (INF0999)
     H*     98: Generic File Error Flag within DETAIL-Record views,
     H*          always set when FSTAT > 0.
     H*     99: Set Reverse Video for SFL OPT entry.
     H*
     H*************************************************************************
     F* File descriptors. Unfortunately, we're bound to handle files by file
     F*  name or record name. We can't use variables to make this more dynamic.
     F* Restriction of RPG.
     F*
     F* Main/primary file, used mainly for writing into.
     FCLIDTRNSPFUF A E           K DISK
     F*
     F* For nice sorting
     FCLIDTRNSLFIF   E           K DISK
     F*
     F* Display file with multiple subfiles among other record formats.
     FCLIDTRNSDFCF   E             WORKSTN
     F                                     SFILE(MAINSFL:SFLRCDNBR)
     F                                     SFILE(DLTSFL:SFLDLTNBR)
     F*
     F*************************************************************************
     D* Global Variables (additional to autocreated ones by referenced files).
     D*
     D* Save point for SFL Indicators, to not interfere with deletion logic.
     DSAVIND           S              1A   DIM(9) INZ('0')
     D*
     D* Save RRN for later cursor-placement after intermediate tasks.
     DSAVRCDNBR        S                   LIKE(SFLRCDNBR) INZ(1)
     D*
     D* File Error status variable to track READ/WRITE/UPDATE/DELETE.
     DFSTAT            S              5S 0
     D*
     D* How many times did we loop through "read changed SFL records?".
     DREADC$           S              2S 0
     D*
     D*************************************************************************
     C* Start the main loop: Write SFLCTL and wait for keypress to read.
     C*  This will be handled after *INZSR was implicitly called by RPG for
     C*  the first time we run.
     C     *IN03         DOUEQ     *ON
     C     *IN12         OREQ      *ON
     C*------------------------------------------
     C* Only write changed screen if there actually was a change.
     C     *IN73         IFEQ      *OFF
     C*
     C* Show F-Key footer display.
     C                   WRITE     MAINBTM
     C*
     C* Make sure, we have an indicator of "no records" when SFL is empty.
     C     *IN31         IFEQ      *OFF
     C                   WRITE     MAINND
     C                   ENDIF
     C*
     C* Reset global SFL Error State from last loop iteration.
     C                   MOVE      *OFF          *IN99
     C*
     C*----------------------------
     C* Set Error indicators according to carry-over indicators set before.
     C*
     C* Show message when we can't find the record anymore.
     C     *IN81         IFEQ      *ON
     C                   WRITE     MAINCTL
     C                   MOVE      *OFF          *IN81
     C                   MOVE      *ON           *IN91
     C                   ENDIF
     C*
     C* Show message when we have a duplicate key.
     C     *IN82         IFEQ      *ON
     C                   WRITE     MAINCTL
     C                   MOVE      *OFF          *IN82
     C                   MOVE      *ON           *IN92
     C                   ENDIF
     C*
     C* Show message when we have a locked record.
     C     *IN83         IFEQ      *ON
     C                   WRITE     MAINCTL
     C                   MOVE      *OFF          *IN83
     C                   MOVE      *ON           *IN93
     C                   ENDIF
     C*
     C* Show message when we have not detected a change in the form.
     C     *IN85         IFEQ      *ON
     C                   WRITE     MAINCTL
     C                   MOVE      *OFF          *IN85
     C                   MOVE      *ON           *IN95
     C                   ENDIF
     C*----------------------------
     C* Show Subfile control record and wait for keypress.
     C                   EXFMT     MAINCTL
     C*------------------------------------------
     C                   ELSE
     C                   READ      MAINCTL
     C                   ENDIF
     C*
     C* Jump out immediately if user pressed F3. We need this additionally
     C*  to the DOUEQ-Loop to prevent another loop-cycle and thus late exit.
     C     *IN03         IFEQ      *ON
     C                   MOVE      *OFF          *IN03
     C                   RETURN
     C                   ENDIF
     C*
     C*------------------------------------------------------------------------
     C* Handle Returned F-Keys. These are usually defined as CA in the DSPF and
     C*  return no data to handle. IN29 indicates any valid key has been
     C*  pressed. Watching IN29 here might save a few CPU cycles.
     C     *IN29         IFEQ      *ON
     C                   SELECT
     C*
     C*----------------------------
     C* Handle SFL Reload with data from database.
     C     *IN05         WHENEQ    *ON
     C                   EXSR      LOADDSPSFL
     C*
     C*------------------
     C* Handle Addition of Records.
     C     *IN06         WHENEQ    *ON
     C                   EXSR      ADDREC
     C*
     C* Reload only on indication to do so.
     C     *IN79         IFEQ      *ON
     C                   MOVE      *OFF          *IN79
     C                   EXSR      LOADDSPSFL
     C                   ENDIF
     C*
     C*----------------------------
     C                   ENDSL
     C                   ITER
     C* If no F-Keys were pressed, handle OPT choices.
     C                   ELSE
     C*
     C* Only read from SFL if SFL actually has entries!
     C     *IN31         IFEQ      *ON
     C*
     C* Reset loop-counter.
     C                   Z-ADD     *ZERO         READC$
     C*
     C* Loop and read changed records from the SFL. This implicitly affects the
     C*  SFL RRN variable! Read starts automatically at record 1.
     C     *ZERO         DOWEQ     *ZERO
     C                   READC     MAINSFL                                71
     C     *IN71         IFEQ      *ON
     C* If there was an error one loop-iteration before, leave loop immediately.
     C* Aka, locked record or the like; so the user can see where we stopped.
     C     *IN99         OREQ      *ON
     C                   LEAVE
     C                   ENDIF
     C*
     C* We passed EOF-Check, so we may increment the loop counter.
     C                   ADD       1             READC$
     C*------------------------------------------------------------------------
     C* Better use SELECT/WHENxx than CASExx: There's no "OTHER" with CASExx
     C*  but we need to ignore a blank/invalid selection with a new loop
     C*  iteration to prevent UPDATEing RRN 1 with the last READ/WRITE-Cycle
     C*  from LOADDSPSFL.
     C                   SELECT
     C     OPT           WHENEQ    '2'
     C                   EXSR      CHGREC
     C* We possibly have locked a record before.
     C                   UNLOCK    CLIDTRNSPF
     C*
     C     OPT           WHENEQ    '3'
     C                   EXSR      DUPREC
     C*
     C     OPT           WHENEQ    '4'
     C                   EXSR      DLTPREP
     C*
     C     OPT           WHENEQ    '5'
     C                   EXSR      DSPREC
     C*
     C     OPT           WHENEQ    ' '
     C* Reset Error State for that one entry. Remember, we're still in READC.
     C                   MOVE      *OFF          *IN99
     C*
     C                   OTHER
     C                   ITER
     C                   ENDSL
     C*------------------------------------------------------------------------
     C* *BLANK out OPT to show to the user we're finished with that one. Keep
     C*  entry active if error occured within an EXSR call.
     C     *IN99         IFEQ      *OFF
     C                   MOVE      *BLANK        OPT
     C                   ENDIF
     C*
     C* Finally, update the record in the SFL.
     C                   UPDATE    MAINSFL
     C*
     C* User may quit from current READC-loop.
     C     *IN03         IFEQ      *ON
     C                   MOVE      *OFF          *IN03
     C                   RETURN
     C                   ENDIF
     C* User may interrupt current READC-loop.
     C     *IN12         IFEQ      *ON
     C                   MOVE      *OFF          *IN12
     C                   LEAVE
     C                   ENDIF
     C*
     C* End of readc-loop!
     C                   ENDDO
     C*
     C* If we directly hit EOF, don't rewrite screen, prevents jumping.
     C     READC$        IFEQ      *ZERO
     C                   MOVE      *ON           *IN73
     C                   ELSE
     C                   MOVE      *OFF          *IN73
     C                   ENDIF
     C*
     C* End of If-IN31-ON.
     C                   ENDIF
     C*
     C*------------------------------------------------------------------------
     C* If we have records to delete, do now.
     C     *IN77         IFEQ      *ON
     C*
     C* Save current SFL *INs so we can freely set ours for deletion.
     C                   MOVEA     *IN(31)       SAVIND(1)
     C                   MOVEA     '0000'        *IN(31)
     C*
     C* Since we have previously collected all records to delete,
     C*  set *IN34 for SFLEND.
     C                   MOVE      *ON           *IN34
     C*
     C* Now handle the deletion itself.
     C                   EXSR      DODLTSFL
     C*
     C* If user exited with *IN12 before, just unset and redisplay.
     C     *IN12         IFEQ      *ON
     C                   MOVE      *OFF          *IN12
     C* Restore previous SFL *INs. They got deleted by clearing DLTSFL.
     C                   MOVEA     SAVIND(1)     *IN(31)
     C                   ENDIF
     C*
     C* After all is done, completely reload.
     C                   MOVE      *ON           *IN79
     C*
     C                   ENDIF
     C*------------------------------------------------------------------------
     C* We're finished with our loop, so we can safely reload, if needed.
     C* Just UPDATEing the SFL record muddles up sorting if the (sort) key
     C*  value changes. Also on duplication, we must force a reload, just like
     C*  addrec does, so we can actually see the new record.
     C     *IN79         IFEQ      *ON
     C                   MOVE      *OFF          *IN79
     C                   EXSR      LOADDSPSFL
     C                   ENDIF
     C*------------------------------------------------------------------------
     C* End of OPT-Handling (IN29 = OFF).
     C                   ENDIF
     C* End of main loop.
     C                   ENDDO
     C* Properly end *PGM.
     C                   RETURN
     C*========================================================================
     C* SFL subroutines
     C*========================================================================
     C     CLEARSFL      BEGSR
     C* Reset SFL state to before the first load.
     C*
     C                   MOVEA     '0010'        *IN(31)
     C                   MOVE      *ZERO         SFLRCDNBR
     C                   WRITE     MAINCTL
     C                   MOVE      *OFF          *IN33
     C*
     C     *LOVAL        SETLL     CLIDTRNS2
     C*
     C                   ENDSR
     C*************************************************************************
     C     LOADDSPSFL    BEGSR
     C* Read over all, at most 999 records and write them into the SFL.
     C*  Increment SFLRCDNBR which determines the line where the record is
     C*  to be be inserted. Stop when SFL is full or EOF happens (*IN34).
     C*
     C* Reset SFL state to default.
     C                   EXSR      CLEARSFL
     C*
     C* Save Current Cursor Position.
     C     SFLCSRRRN     IFGT      *ZERO
     C                   Z-ADD     SFLCSRRRN     SAVRCDNBR
     C                   ELSE
     C                   Z-ADD     1             SAVRCDNBR
     C                   ENDIF
     C*
     C*----------------------------
     C* Read loop start.
     C     *ZERO         DOWEQ     *ZERO
     C                   READ(N)   CLIDTRNS2                              34
     C     *IN34         IFEQ      *ON
     C                   LEAVE
     C                   ENDIF
     C*
     C* Reset OPT to blank to prevent stray OPT entries to be duplicated.
     C                   MOVE      *BLANK        OPT
     C*
     C* Reset error *INs.
     C                   MOVEA     '000000000'   *IN(91)
     C*
     C* Increment line-number-to-insert.
     C                   ADD       1             SFLRCDNBR
     C*
     C* Make sure we know if the SFL is full.
     C     SFLRCDNBR     IFGE      999
     C                   MOVE      *ON           *IN96
     C                   LEAVE
     C                   ENDIF
     C*
     C* Write ready-made records into the SFL.
     C                   WRITE     MAINSFL
     C                   ENDDO
     C*----------------------------
     C*
     C* Loop ended. Display the subfile- and subfile control records, or
     C*  indicate an empty SFL by (not) setting IN31.
     C     SFLRCDNBR     IFGT      *ZERO
     C                   MOVE      *ON           *IN31
     C                   ELSE
     C                   MOVE      *OFF          *IN31
     C                   ENDIF
     C*
     C* Restore Cursor Position for SFL, which also sets us on the same display
     C*  page we were before the reload.
     C     SFLRCDNBR     IFGE      SAVRCDNBR
     C                   Z-ADD     SAVRCDNBR     SFLRCDNBR
     C                   ELSE
     C                   Z-ADD     1             SFLRCDNBR
     C                   ENDIF
     C*
     C* Finally allow to show all the data on the display. Actual DSPF write
     C*  is handled in the main routine.
     C                   MOVE      *ON           *IN32
     C*
     C                   ENDSR
     C*========================================================================
     C* Some useful general Subroutines
     C*========================================================================
     C     *INZSR        BEGSR
     C* Stuff to do before the main routine starts.
     C*
     C* Load Subfile, jump to record 1.
     C                   EXSR      LOADDSPSFL
     C                   Z-ADD     1             SFLRCDNBR
     C*
     C                   ENDSR
     C*************************************************************************
     C     SETERRIND     BEGSR
     C* Set *INxx to show errors in the message line. These have been defined
     C*  in the appropriate display file.
     C* Other errors shall be catched by the OS handler.
     C*
     C                   SELECT
     C     FSTAT         WHENEQ    12
     C* Error 0012 = Record not found.
     C                   MOVE      *ON           *IN91
     C     FSTAT         WHENEQ    1021
     C* Error 1021 = Duplicate key.
     C                   MOVE      *ON           *IN92
     C     FSTAT         WHENEQ    1218
     C* Error 1218 = Desired record is locked.
     C                   MOVE      *ON           *IN93
     C                   ENDSL
     C*
     C                   ENDSR
     C*************************************************************************
     C     INHERITERR    BEGSR
     C* To show ERRMSG/IDs, we already need to have the right RECFMT on screen.
     C*  So write, then set IN for the following EXFMT to actually display the
     C*  message.
     C*
     C* Show message when we can't find the record anymore.
     C     *IN81         IFEQ      *ON
     C                   WRITE     DETAILFRM
     C                   MOVE      *OFF          *IN81
     C                   MOVE      *ON           *IN91
     C                   ENDIF
     C*
     C* Show message when we have a duplicate key.
     C     *IN82         IFEQ      *ON
     C                   WRITE     DETAILFRM
     C                   MOVE      *OFF          *IN82
     C                   MOVE      *ON           *IN92
     C                   ENDIF
     C*
     C* Show message when we have a locked record.
     C     *IN83         IFEQ      *ON
     C                   WRITE     DETAILFRM
     C                   MOVE      *OFF          *IN83
     C                   MOVE      *ON           *IN93
     C                   ENDIF
     C*
     C* Show message when we have a locked record, but continued readonly.
     C     *IN84         IFEQ      *ON
     C                   WRITE     DETAILFRM
     C                   MOVE      *OFF          *IN84
     C                   MOVE      *ON           *IN94
     C                   ENDIF
     C*
     C* Show message when we have not detected a change in the form.
     C     *IN85         IFEQ      *ON
     C                   WRITE     DETAILFRM
     C                   MOVE      *OFF          *IN85
     C                   MOVE      *ON           *IN95
     C                   ENDIF
     C*
     C                   ENDSR
     C*========================================================================
     C* SFL Handlers for deleting records.
     C*========================================================================
     C     DLTPREP       BEGSR
     C* For every record selected (OPT 4, see above) copy entry into the
     C*  secondary subfile screen (not yet shown) and blindly set flag IN77.
     C* This implicitly requires displayed fields in DLTSFL not being a
     C*  superset of fields in regular SFL!
     C*
     C* Save current SFL *INs so we can freely set ours for deletion.
     C                   MOVEA     *IN(31)       SAVIND(1)
     C                   MOVEA     '0000'        *IN(31)
     C                   MOVE      *OFF          *IN99
     C*
     C                   MOVE      '4'           DOPT
     C                   ADD       1             SFLDLTNBR
     C                   WRITE     DLTSFL
     C                   MOVE      *ON           *IN77
     C*
     C* Restore previous SFL *INs.
     C                   MOVEA     SAVIND(1)     *IN(31)
     C*
     C                   ENDSR
     C*************************************************************************
     C     CLEARDLTSFL   BEGSR
     C* Reset SFL state to before the first load. Also clear "deletion needed".
     C*
     C                   MOVEA     '0010'        *IN(31)
     C                   MOVE      *ZERO         SFLDLTNBR
     C                   WRITE     DLTCTL
     C                   MOVE      *OFF          *IN33
     C                   MOVE      *OFF          *IN77
     C*
     C                   ENDSR
     C*************************************************************************
     C     DODLTSFL      BEGSR
     C* Show may-i-delete-SFL and wait for keypress. Handle deletions if still
     C*  selected with '4'. Note: The SFL has SFLNXTCHG set on permanently to
     C*  enable reading the whole SFL, even without user changes.
     C*
     C* Prevent Crashing with empty SFL. Should not happen, but who knows?
     C     SFLDLTNBR     IFGT      *ZERO
     C                   MOVE      *ON           *IN31
     C                   ELSE
     C                   MOVE      *OFF          *IN31
     C                   WRITE     MAINND
     C                   ENDIF
     C*
     C* Write F-Keys only once.
     C                   WRITE     DLTBTM
     C*
     C* Finally show all the data on the display.
     C                   MOVE      *ON           *IN32
     C*
     C*----------------------------
     C* Loop SFL display-again until there's no more error.
     C     *ZERO         DOWEQ     *ZERO
     C                   EXFMT     DLTCTL
     C*
     C     *IN12         IFEQ      *ON
     C                   EXSR      CLEARDLTSFL
     C                   LEAVESR
     C                   ENDIF
     C*
     C* Make sure we're beginning read from first entry.
     C                   Z-ADD     1             SFLDLTNBR
     C*
     C*------------------
     C* READC loop start.
     C     *ZERO         DOWEQ     *ZERO
     C                   READC     DLTSFL                                 71
     C     *IN71         IFEQ      *ON
     C                   LEAVE
     C                   ENDIF
     C*
     C* Delete only if record is preselected with '4'. Note, we need the field
     C*  designation in DDS to be both Input/Output for this to work!
     C     DOPT          IFEQ      '4'
     C*
     C* Delete record.
     C     CLID          DELETE(E) CLIDTRNS1
     C                   EVAL      FSTAT=%STATUS(CLIDTRNSPF)
     C     FSTAT         IFGT      *ZERO
     C                   EXSR      SETERRIND
     C                   MOVE      *ON           *IN99
     C                   UPDATE    DLTSFL
     C                   MOVE      *OFF          *IN99
     C                   LEAVE
     C* End-if-FSTAT-gt-*ZERO
     C                   ENDIF
     C*
     C* At this point, we most likely successfully deleted a record.
     C                   MOVE      *BLANK        DOPT
     C                   MOVE      *OFF          *IN99
     C                   UPDATE    DLTSFL
     C*
     C* End-if-DOPT=4
     C                   ENDIF
     C* Loop is left on EOF of DSLTSFL.
     C                   ENDDO
     C*------------------
     C* Leave this loop also if there was EOF (all Records have been treated).
     C*
     C     *IN71         IFEQ      *ON
     C                   MOVE      *OFF          *IN71
     C                   LEAVE
     C                   ENDIF
     C*
     C                   ENDDO
     C*----------------------------
     C* Clear SFL for next run.
     C                   EXSR      CLEARDLTSFL
     C*
     C                   ENDSR
     C*========================================================================
     C* Code for displaying/changing/creating/duplicating record details
     C*  in a separate record format
     C*========================================================================
     C     ADDREC        BEGSR
     C* Clear variables from stray entries. Then present the display to the
     C*  user, for entering data. Wait for the user to press return and deliver
     C*  that data for us to process and eventually insert into the main file.
     C                   CLEAR                   DETAILFRM
     C*
     C*----------------------------
     C* Show the prepared form within a loop, until there are no more errors.
     C                   Z-ADD     99999         FSTAT
     C     FSTAT         DOUEQ     *ZERO
     C* Show matching todo-string.
     C                   MOVEA     '100'         *IN(42)
     C                   EXFMT     DETAILFRM
     C                   EXSR      RSTDSPMOD
     C*
     C* Whee! User pressed a key! May we add a record?
     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   MOVE      *OFF          *IN12
     C                   LEAVESR
     C                   ENDIF
     C*
     C* Now try to WRITE the record, but only if the user actually
     C*  changed anything, or we had an error condition before.
     C     *IN28         IFEQ      *ON
     C     *IN98         OREQ      *ON
     C*
     C* Try to write the record.
     C                   WRITE(E)  CLIDTRNS1
     C                   EVAL      FSTAT=%STATUS(CLIDTRNSPF)
     C     FSTAT         IFGT      *ZERO
     C                   MOVE      *ON           *IN98
     C                   EXSR      SETERRIND
     C                   ITER
     C                   ENDIF
     C* At this point, we most likely successfully inserted a record.
     C                   MOVE      *OFF          *IN98
     C*
     C* Set Reload-Indicator to reflect changes.
     C                   MOVE      *ON           *IN79
     C*
     C* If there was no change in display (IN28).
     C                   ELSE
     C                   MOVE      *ON           *IN85
     C                   LEAVE
     C*
     C                   ENDIF
     C* End of loop-unil-no-error.
     C                   ENDDO
     C*----------------------------
     C*
     C                   ENDSR
     C*************************************************************************
     C     DUPREC        BEGSR
     C* Set "we wanna duplicate" flag, no last state of cursor-placement,
     C*  and let CHGREC do the hard work.
     C                   MOVEA     '0000000000'  *IN(60)
     C                   MOVE      *ON           *IN78
     C                   EXSR      CHGREC
     C                   MOVE      *OFF          *IN78
     C*
     C                   ENDSR
     C*************************************************************************
     C     CHGREC        BEGSR
     C* Load data of the desired record from the database file. Maybe condition
     C*  the data and WRITE it into the DSPF. Wait for the user to press return
     C*  so we may process the data and UPDATE the database file.
     C* We also handle DUPREC with *IN78, because the main difference is
     C*  UPDATE vs. WRITE.
     C*
     C* Show the prepared form within a loop, until there are no more errors.
     C*
     C                   Z-ADD     99999         FSTAT
     C     FSTAT         DOUEQ     *ZERO
     C*
     C* No lock needed for duplication, but for updating.
     C     *IN78         IFEQ      *ON
     C     CLID          CHAIN(EN) CLIDTRNS1
     C                   ELSE
     C     CLID          CHAIN(E)  CLIDTRNS1
     C                   ENDIF
     C*
     C                   EVAL      FSTAT=%STATUS(CLIDTRNSPF)
     C     FSTAT         IFGT      *ZERO
     C                   MOVE      *ON           *IN98
     C                   EXSR      SETERRIND
     C*------------------
     C* Since we'll open the record in question readonly, here is an extension
     C*  to the SETERRIND handler.
     C* Error 1218 = Desired record is locked. (Show record readonly.)
     C     FSTAT         IFEQ      1218
     C* Disable "locked" indicator again, and set IN84 for showing r/o message.
     C                   MOVE      *OFF          *IN98
     C                   MOVE      *OFF          *IN93
     C                   MOVE      *ON           *IN84
     C                   EXSR      DSPREC
     C                   MOVE      *OFF          *IN84
     C                   LEAVESR
     C                   ENDIF
     C*------------------
     C                   MOVE      *ON           *IN99
     C                   LEAVESR
     C                   ENDIF
     C*
     C                   MOVE      *OFF          *IN98
     C*
     C* Position cursor in DSPF to field where it was with last CHGREC.
     C     *IN78         IFEQ      *OFF
     C                   EXSR      SETCSRPOS
     C                   ENDIF
     C*
     C* Show matching todo-string.
     C     *IN78         IFEQ      *ON
     C                   MOVEA     '100'         *IN(42)
     C                   ELSE
     C                   MOVEA     '010'         *IN(42)
     C                   ENDIF
     C*
     C* Set Error indicators according to carry-over indicators set before.
     C                   EXSR      INHERITERR
     C                   EXFMT     DETAILFRM
     C                   EXSR      RSTDSPMOD
     C*
     C* Whee! User pressed a key! May we add (duplicate) or change a record?
     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   LEAVESR
     C                   ENDIF
     C*
     C* Now try to WRITE/UPDATE the record, but only if the user actually
     C*  changed anything or there has been an error before.
     C     *IN28         IFEQ      *ON
     C     *IN98         OREQ      *ON
     C*
     C* Try to write or update the record.
     C     *IN78         IFEQ      *ON
     C                   WRITE(E)  CLIDTRNS1
     C                   ELSE
     C                   UPDATE(E) CLIDTRNS1
     C                   ENDIF
     C                   EVAL      FSTAT=%STATUS(CLIDTRNSPF)
     C     FSTAT         IFGT      *ZERO
     C                   MOVE      *ON           *IN98
     C                   EXSR      SETERRIND
     C                   ITER
     C                   ENDIF
     C*
     C* If there was no change in display (IN28).
     C                   ELSE
     C                   MOVE      *ON           *IN85
     C                   LEAVE
     C                   ENDIF
     C*
     C* End of loop-unil-no-error.
     C                   ENDDO
     C*----------------------------
     C*
     C* Reset error-state: After end of loop there is no more error.
     C                   MOVE      *OFF          *IN98
     C*
     C* Set Reload-Indicator to reflect changes.
     C                   MOVE      *ON           *IN79
     C*
     C                   ENDSR
     C*************************************************************************
     C     DSPREC        BEGSR
     C* Load data of the current selected record from the database file. Maybe
     C*  condition the data and WRITE it into the DSPF. Wait for the user to
     C*  press any key to return to the main program.
     C*
     C* Show the prepared form within a loop, until there are no more errors.
     C*
     C                   Z-ADD     99999         FSTAT
     C     FSTAT         DOUEQ     *ZERO
     C*
     C     CLID          CHAIN(EN) CLIDTRNS1
     C*
     C                   EVAL      FSTAT=%STATUS(CLIDTRNSPF)
     C     FSTAT         IFGT      *ZERO
     C                   MOVEA     '11'          *IN(98)
     C                   EXSR      SETERRIND
     C                   LEAVESR
     C                   ENDIF
     C*
     C                   MOVE      *OFF          *IN98
     C*
     C* Show matching todo-string.
     C                   MOVEA     '001'         *IN(42)
     C*
     C* Set Error indicators according to carry-over indicators set before.
     C                   EXSR      INHERITERR
     C                   EXFMT     DETAILFRM
     C                   EXSR      RSTDSPMOD
     C*
     C* Whee! User pressed a key!
     C     *IN03         IFEQ      *ON
     C     *IN12         OREQ      *ON
     C                   LEAVESR
     C                   ENDIF
     C*
     C* End of loop-unil-no-error.
     C                   ENDDO
     C*----------------------------
     C*
     C* Reset error-state: After end of loop there is no more error.
     C                   MOVE      *OFF          *IN98
     C*
     C                   ENDSR
     C*========================================================================
     C* Some useful general Subroutines for Detail-Record-handling
     C*========================================================================
     C     SETCSRPOS     BEGSR
     C* Here we check in which record format the cursor was last time and place
     C*  the cursor via DSPATR(PC) via *IN6x into the same field.
     C                   MOVEA     '0000000000'  *IN(60)
     C     CSREC         IFEQ      'DETAILFRM'
     C                   SELECT
     C     CSFLD         WHENEQ    'CLID'
     C                   MOVE      *ON           *IN60
     C     CSFLD         WHENEQ    'CLNAME'
     C                   MOVE      *ON           *IN61
     C                   ENDSL
     C                   ENDIF
     C*
     C                   ENDSR
     C*************************************************************************
     C     RSTDSPMOD     BEGSR
     C* Reset stuff to default.
     C                   MOVEA     '000'         *IN(42)
     C*
     C                   ENDSR
     C*************************************************************************
     C* vim: syntax=rpgle colorcolumn=81 autoindent noignorecase
