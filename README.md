This repository contains a solution for resolving caller IDs to names.

It is a classic client-server application server, and an AS/400 typical maintenance application for adding, editing, and deleting records of a database file containing caller IDs and names.

The application server is an udp-based socket server. It just listens to data, on an UDP socket, queries the database with that data, and either returns the CLID name if a match is found, or just the input, if not. A possible client is netcat in UDP mode.

Both components are released to the public according to the GNU GPL v 2.0 or later.

## License.
This document is part of asterisk-translate-clid, to be found on [GitHub](https://github.com/PoC-dev/asterisk-translate-clid). Its content is subject to the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, also known as *Attribution-ShareAlike 4.0 International*. The project itself is subject to the GNU Public License version 2 or later, at your option.

## Motivation
Does this make sense? IBM has ODBC client libraries available for Linux, so this translation could be done more easy with Asterisk built-in ODBC support!

Well... ODBC access from Debian Linux to older OS/400 releases broke quite a time ago. When doing a trace on OS/400 what happens, the Hostserver *DATABASE task complains about an uneven memory access (odd memory address?) and sends back an error condition. Funnily, this happens *only* with Asterisk ODBC support, and with `isql`, the command line ODBC client. No queries possible besides HELP, which just generates a list of libraries and files to see, as before. The fault is probably dependent on current time, because reverting to older versions of LinuxODBC didn't help. The interesting part is: It still works with Perl's DBI::ODBC.

However, the additional complications of mixed EBCDIC vs. ASCII worlds, a strong indication of a bug in OS/400, and the lack of source code for it to eventually fix the issue gave way to try other means.

The second important motivation is that my main machine is an old AS/400 9401 model 150. It's slow, depending on what you do. SQL is slow. Inetd is slow. Startup times of inetd spawns are in the one to two second range, without any meaningful work being done! Thus I came up with the idea of a most simple UDP listener which can be contacted by simple Netcat call. Additionally, I was searching for some meaningful work besides just editing database content via green screen. See [my AS/400 Wiki](https://try-as400.pocnet.net) for details around this highly interesting platform.

## How to get it to run
First, the daemon is meant to run in a separate subsystem, so it can be easily started at IPL time. Second, it's also meant to run with a separate user profile solely for that purpose.

The instructions assume you are signed on to a 5250 session as *QSECOFR* or some user with equivalent rights.

First, create a new library to hold all the needed objects. Change thereto.
```
crtlib lib(astsupport) text('Asterisk Support')
chgcurlib curlib(astsupport)
crtsrcpf file(sources) rcdlen(112)
```
Next, create a user profile for the programs to run with. 
```
crtusrprf usrprf(astsupport) password(*none) curlib(astsupport) lmtcpb(*yes) text('Asterisk Support') inlpgm(qwcclfec)
```
Now we can create the run time environment objects.
```
crtsbsd sbsd(*curlib/astsupport) pools((1 *base)) syslible(astsupport) text('Asterisk Support SBS')
crtjobq jobq(*curlib/astjobs) autchk(*dtaaut)
crtjobd jobd(*curlib/calltransd) jobq(astsupport/astjobs) user(astsupport) rtgdta(calltransd) rqsdta('call pgm(astsupport/calltransd)') text('Start CALLTRANSD *PGM') 
```
Next, we need to modify the subsystem description we've created earlier.
- Add entries for actual auto start
- Add a job queue: Each job is placed in a queue for the SBS to pick it up
- Add a routing entry to match against the JOBD's RTGDTA to add run time attributes.
```
addaje sbsd(*curlib/astsupport) job(calltransd) jobd(*curlib/calltransd)
addjobqe sbsd(*curlib/astsupport) jobq(*curlib/astjobs) maxact(*nomax)
addrtge sbsd(*curlib/astsupport) seqnbr(99) cmpval(*any) pgm(qcmd) cls(*libl/qbatch)
```
Finally, create an entry for the OS/400 equivalent of */etc/services* for our daemon:
```
addsrvtble service('CALLTRANSD') port(10001) protocol('UDP')
```

### Files: Naming and upload
```
Repository name  | MBR Name   | Type 
-----------------+------------+------
clidtrnspf.dds   | clidtrnspf | PF
clidtrnslf.dds   | clidtrnslf | LF
calltransd.c     | calltransd | C
clidtrnsdf.dds   | clidtrnsdf | DSPF
clidtrnspg.rpgle | clidtrnspg | RPGLE
```
Upload these files with any FTP client **in ASCII mode** into *ASTSUPPORT/SOURCES*. Then set their file type with WRKMBRPDM in the 5250 session as shown above. To ease this undertaking, you can feed *ftpupload.txt* to stdin of your preferred command line FTP client.
```
ftp myas400 < ftpupload.txt
```
Now you can just type 14 beneath the objects to create them.

**Note!** You need to create the physical files first, because they are referenced in the programs. When the objects don't exist and you try to compile the programs, compilation will fail.

Now you can start the subsystem with `strsbs sbsd(astsupport)`. You should see the jobs run in `wrkactjob`:
```
Opt   Subsystem/Job  User        Type CPU %  Function        Status
 __   ASTSUPPORT     QSYS        SBS    0,0                   DEQW 
 __     CALLTRANSD   ASTERISK    ASJ    0,0  PGM-CALLTRANSD   TIMW  
```
If something does not work, check:
- `wrklib lib(*curlib)`: Are all objects created as outlined above?
- `wrkactjob sbs(astsupport)`. If the programs appear, use option 5 (work with), and then 10 to display their job log.
- `dspmsg`
- `dspmsg qsysopr`
- `dsplog`

### About Record-I/O, and C string handling
There is a fundamental difference between the concept of record I/O, and string handling in the C language.

Record I/O means that data entities, such as strings, have a predefined length. Unused space at the end of a string is filled with blank (space) characters until the length of the respective field is filled.

C strings are terminated by a NULL character. Memory locations behind the end of the string variable might contain garbage or old data, and should be treated as undefined. Hence, C library string handling functions naturally assume, or implicitly write NULL characters.

Programming on OS/400 in C requires to learn when which kind of string is needed, and the best way to convert between them.

One way to deal with this is to use a second set of variables, being at least one position larger to accommodate the terminating NULL character, copying strings, and setting the string end to the first non-blank character by replacing that position with a NULL character. Drawback is that copying a string is less efficient than just modifying the original buffer. But the original buffer can be filled to the brim with characters, leaving no space for a terminating NULL.

Personally, I declare that database fields have to be at least one position larger than the longest string. This is not error-proof but must suffice until I come up with a likewise efficient but better idea.

### Maintenance frontend compilation
You probably have had created all the needed objects already, so you can start the program with `call pgm(clidtrnspg)`.

***Note!*** If an error occurs, you'll probably get a second-level-error that a message file *genericsmsg* could not be found. See my [generic Subfile project on Github](https://github.com/PoC-dev/as400-sfltemplates) for crtmsgd REXX script which should create this file for you - with German texts, though.

### Asterisk Configuration
You need to have Netcat installed, and need to make sure you allow all necessary modules in Asterisk to be loaded.
```
exten => _X.,n,Set(CALLERID(name)=${SHELL(printf "TRANSLATE ${CALLERID(number)}\n" |nc -u -w 1 192.168.1.150 10001)})
```

After you added some entries to the database, you can try the above printf-with-pipe command on the command line to see if you have a problem within Asterisk, or elsewhere.

## Current state
- Maintenance application is German, maybe not the best pick for an international audience. But since I am German... (I'm learning constantly about OS/400, and when I have enough motivation, I'll come up with a project- independent way of providing multiple language support, as well as translations for existing projects.)
- Autostart of job at SBS start works.
- Graceful end of background ("batch") job works.

Also see FIXME remarks in the source code.

----

2024-08-18 poc@pocnet.net 
