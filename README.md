## What is it?
This repository contains a client-server application server, and an AS/400
typical maintenance application for adding, editing, and deleting records of
a database file.

The application server is an udp-based socket server. It just listens to data,
on an UDP socket, queries the database with that data, and either returns the
CLID name if a match is found, or just the input, if not.

Both components are released to the public according to the GNU GPL v 2.0 or
later.

### Motivation
Does this make sense? IBM has ODBC client libraries available for Linux, so this
translation could be done more easy with Asterisk built-in ODBC support!

Well... ODBC access from Debian Linux to older OS/400 releases broke quite a
time ago.  When doing a trace on OS/400 what happens, the Hostserver *DATABASE
task complains about an uneven memory access (odd memory address?) and sends
back error. Funnily, this happens *only* with Asterisk ODBC support, and with
`isql`, the command line ODBC client. No queries possible besides HELP, which
just generates a list of libraries and files to see, as before. The fault is
probably dependent on current time, because reverting to older versions of
LinuxODBC didn't help. The interesting part is: It still works with Perl's
DBI::ODBC.

However, the mixed EBCDIC vs. ASCII worlds, a strong indication of a bug in
OS/400 and the lack of source code for it to eventually fix the issue gave way
to try other means.

The second important motivation is that my main machine is an old AS/400 9401
model 150. It's slow, depending on what you do. SQL is slow. Inetd is slow.
Startup times are in the one to two second range, without any meaningful work
being done! Thus I came up with the idea of a most simple UDP listener which
can be contacted by simple Netcat call. Additionally, I was searching for some
meaningful work besides just editing database content via green screen. See [my
AS/400 Wiki](https://try-as400.pocnet.net) for details around this highly
interesting platform.

## How to get it to run
First, the daemon is meant to run in a separate subsystem, so it can be easily
started at IPL time. Second, it's also meant to run with a separate user profile
solely for that purpose.

The instructions assume you are signed on to a 5250 session as QSECOFR or some
user with equivalent rights.

***Note:*** Lines which end in a + sign are continued on the next line!

First, create a new library to hold all the needed objects. Change thereto.
```
CRTLIB LIB(ASTSUPPORT) TEXT('Asterisk Support')
CHGCURLIB CURLIB(ASTSUPPORT)
CHGSRCPF FILE(SOURCES)
```

Next, create a user profile for the programs to run with. 
```
CRTUSRPRF USRPRF(ASTSUPPORT) PASSWORD(*NONE) CURLIB(ASTSUPPORT) LMTCPB(*YES) +
  TEXT('Asterisk Support')
```

Now we can create the run time environment objects.
```
CRTSBSD SBSD(*CURLIB/ASTSUPPORT) POOLS((1 *BASE)) SYSLIBLE(ASTSUPPORT) +
  TEXT('Asterisk Support SBS')
CRTJOBQ JOBQ(*CURLIB/ASTJOBS) AUTCHK(*DTAAUT)
CRTJOBD JOBD(*CURLIB/CALLTRANSD) JOBQ(ASTSUPPORT/ASTJOBS) USER(ASTSUPPORT) +
  RTGDTA(CALLTRANSD) RQSDTA('CALL PGM(ASTSUPPORT/CALLTRANSD)') +
  TEXT('Start CALLTRANSD *PGM') 
```

Next, we need to modify the subsystem description we've created earlier.
- Add entries for actual auto start
- Add a job queue: Each job is placed in a queue for the SBS to pick it up
- Add a routing entry to match against the JOBD's RTGDTA to add run time
  attributes.
```
ADDAJE SBSD(*CURLIB/ASTSUPPORT) JOB(CALLTRANSD) JOBD(*CURLIB/CALLTRANSD)
ADDJOBQE SBSD(*CURLIB/ASTSUPPORT) JOBQ(*CURLIB/ASTJOBS) MAXACT(*NOMAX)
ADDRTGE SBSD(*CURLIB/ASTSUPPORT) SEQNBR(99) CMPVAL(*ANY) PGM(QCMD) +
  CLS(*LIBL/QBATCH)
```

Finally, create an entry for the OS/400 equivalent of /etc/services for our
daemon:
```
ADDSRVTBLE SERVICE('calltransd') PORT(10001) PROTOCOL('udp')
```

### Files: Naming and upload
```
Repository name    MBR Name and Type 
-------------------------------------
clidtrnspf.dds     CLIDTRNSPF   PF
clidtrnslf.dds     CLIDTRNSLF   LF
calltransd.c       CALLTRANSD   C
clidtrnsdf.dds     CLIDTRNSDF   DSPF
clidtrnspg.rple    CLIDTRNSPG   RPGLE
Makefile           MAKEFILE     TXT
```

Upload these files with any FTP client **in ASCII mode** into
ASTSUPPORT/SOURCES. Then set their file type with WRKMBRPDM in the 5250 session
as shown above. Now you can just type 14 beneath the objects to create them.

The provided Makefile is optional and based on some assumptions:
- You installed TMKMAKE according to the instructions in
  QUSRTOOL/QATTINFO.TMKINFO. If that library is not found, you need to install
  the "example programs" available on your install media.
- The initial, empty PF must be manually created.
- There must be a SRC PF called BLDTMSTMPS. This is required to track time stamps
  of changing files, such as PFs and LFs.
- The existence of a CMDCTI menu source is assumed. This is not part of this
  project, though.

**Note!** You need to create the physical files first, because they are
referenced in the programs. When the objects don't exist and you try to compile
the programs, compilation will fail.

Now you can start the subsystem with `STRSBS SBSD(ASTSUPPORT)`. You should see
the jobs run in WRKACTJOB:
```
Opt   Subsystem/Job  User        Type CPU %  Function        Status
 __   ASTSUPPORT     QSYS        SBS    0,0                   DEQW 
 __     CALLTRANSD   ASTERISK    ASJ    0,0  PGM-CALLTRANSD   TIMW  
```

If something does not work, check:
- WRKLIB LIB(*CURLIB): Are all objects created as outlined above?
- WRKACTJOB. If the programs appear, use option 5 (work with), and then 10 to
  display their job log.
- DSPMSG
- DSPMSG QSYSOPR
- DSPLOG

### Maintenance frontend compilation
You probably have had created all the needed objects already, so you can start
the program with `CALL PGM(CLIDTRNSPG)`.

***Note!*** If an error occurs, you'll probably get a second-level-error that a
message file *genericsmsg* could not be found. See my [generic Subfile project
on Github](https://github.com/PoC-dev/as400-sfltemplates-german) for crtmsgd
REXX script which should create this file for you - with German Text, though.

### Asterisk Configuration
You need to have Netcat installed, and need to make sure you allow all necessary
modules in Asterisk to be loaded.

```
exten => _X.,n,Set(CALLERID(name)=${SHELL(printf "TRANSLATE ${CALLERID(number)}\n" |nc -u -w 1 192.168.1.150 10001)})
```

After you added some entries to the database, you can try the command on the
command line to see if you have a problem within Asterisk, or elsewhere.

## Current state
- Maintenance application is German, maybe not the best pick for an
  international audience. But since I am German... (I'm learning constantly
  about OS/400, and when I have enough motivation, I'll come up with a project-
  independent way of providing multiple language support, as well as
  translations for existing projects.)
- Autostart of job at SBS start works.
- Graceful end of background ("batch") job works.

Also see FIXME remarks in the source code.

## Contact
You may write email to poc@pocnet.net for questions and general contact.

Patrik Schindler,
January, 2023
