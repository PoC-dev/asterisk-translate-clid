/*
 * Copyright 2021-2022 Patrik Schindler <poc@pocnet.net>.
 *
 * Licensing terms.
 * This is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * It is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 * or get it at http://www.gnu.org/licenses/gpl.html
 *
 * Based on the skeleton "Programming udp sockets in C on Linux
 * Silver Moon <m00n.silv3r@gmail.com>
 * http://www.binarytides.com/programming-udp-sockets-in-c-on-linux/
 *
 */

#include <errno.h>
#include <iconv.h>
#include <netdb.h>          /* getservent */
#include <netinet/in.h>     /* networkbyteorder translation */
#include <recio.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>     /* socket */
#include <sys/types.h>      /* socket */
#include <signal.h>
#include <sys/signal.h>
#include <unistd.h>
#include <qtqiconv.h>
#include <qp0ztrc.h>

/* Files ---------------------------------------------------------------------*/

/* Important! This statement is about the compiled object, not the source! */
#pragma mapinc("TRANSTBL", "ASTSUPPORT/CLIDTRNSLF(*ALL)", "input", "_P", "")
#include "TRANSTBL"
#define _TRANSRECSZ sizeof(transrec)

/* Defines -------------------------------------------------------------------*/

/* How much memory to put aside for the static string buffers? */
#define BUFSIZE 512

/* Defines for CRLF. */
#define _CR 0xd
#define _LF 0xa

/* Global variables, so we can easily iconv anywhere in our code. */
iconv_t a_e_ccsid;
iconv_t e_a_ccsid;
int exit_flag;

/* Actual Code ---------------------------------------------------------------*/

/* Send a message to the job log, and then exit with error. ------------------*/

void die(char *s) {
    Qp0zLprintf("%s: %s\n", s, strerror(errno));
    exit(1);
}

/* Charset conversion. -------------------------------------------------------*/

int convert_buffer(char *inBuf, char *outBuf, int inBufLen, int outBufLen,
                iconv_t table) {
    int retval = 0;
    size_t insz;
    size_t outsz;
    char *out_buf;
    char *in_buf;

    insz = inBufLen;
    outsz = outBufLen;
    in_buf = inBuf;
    out_buf = outBuf;
    retval = (iconv(table, (char **)&(in_buf), &insz, (char **)&(out_buf),
            &outsz));
    return(retval);
}

/* Print EBCDIC buffer to string as ASCII. -----------------------------------*/

int seprintf(iconv_t convtable, char *dststr, char *format, ...) {
    va_list va;
    char tmpbuf[BUFSIZE];
    unsigned int len;

    /* Erase buffers for use */
    memset(tmpbuf, '\0', BUFSIZE);

    /* Print Varargs into Buffer */
    va_start(va, format);
    vsprintf(tmpbuf, format, va);
    va_end(va);

    len = strlen(tmpbuf);
    convert_buffer(tmpbuf, dststr, len, len, convtable);

    return(0);
}

/* What to do when we receive a SIGTERM. -------------------------------------*/

void set_exit_flag(int signum) {
    exit_flag = 1;
}

/* Main. ---------------------------------------------------------------------*/

int main(int argc, char *argv[]) {
	_RFILE *fp;
	_RIOFB_T *rfb;
    ASTSUPPORT_CLIDTRNSLF_CLIDTRNSTB_i_t transrec;
    QtqCode_T jobCode = {0,0,0,0,0,0};
    QtqCode_T asciiCode = {819,0,0,0,0,0};
    struct sockaddr_in server_addr, client_addr;
    struct servent *whoami;
    struct sigaction termaction;
    char asciiBuf[BUFSIZE], ebcdicBuf[BUFSIZE], cmdBuf[BUFSIZE], *number;
    int sockfd, len;
    static int setsockopt_flag=1;
    unsigned int strlen, i, n;


    /* Create signal handler for SIGTERM. */
    memset(&termaction, 0, sizeof(struct sigaction));
    termaction.sa_handler = set_exit_flag;
    sigaction(SIGTERM, &termaction, NULL);


    /* Create the conversion tables */
    /* ASCII to EBCDIC */
    a_e_ccsid = QtqIconvOpen(&jobCode, &asciiCode);
    if (a_e_ccsid.return_value == -1) {
        iconv_close(a_e_ccsid);
        Qp0zLprintf("QtqIconvOpen Failed");
    }

    /* EBCDIC to ASCII */
    e_a_ccsid = QtqIconvOpen(&asciiCode, &jobCode);
    if (e_a_ccsid.return_value == -1) {
        iconv_close(e_a_ccsid);
        Qp0zLprintf("QtqIconvOpen Failed");
    }


    /* Prepare Networking - note that statement ordering is important! */

    /* Keep trying to socket for 15 mins, so TCP/IP has enough time to start. */
    for ( i = 0; i <= 900; i++ ) {
        if ( (sockfd = socket(AF_INET, SOCK_DGRAM, 0)) == -1 ) {
            sleep(1);
        } else {
            break;
        }
    }
    if ( i >= 900 ) {
        Qp0zLprintf("Tried socket() %d times, giving up. Last error was %s.\n",
            i, strerror(errno));
        exit(1);
    } else {
        Qp0zLprintf("socket(): got fd %d after %d tries: %s\n",
            sockfd, i++, strerror(errno));
    }


    if ( (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR,
            (char *)&setsockopt_flag, sizeof(setsockopt_flag)) == -1) ) {
        die("setsockopt(): failed");
    }


    /* Zero Struct. */
    memset(&server_addr, 0, sizeof(server_addr));
    memset(&client_addr, 0, sizeof(client_addr));

    /* Setup. */
    whoami = getservbyname("calltransd", "udp");
    if ( whoami == 0 ) {
        die("Could not find myself in /etc/services");
    }
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(whoami->s_port);
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    endservent();

    len = sizeof(client_addr);

    /* Bind socket to port. */
    if ( (bind(sockfd, (struct sockaddr *)&server_addr,
            sizeof(server_addr))) == -1 ) {
        die("bind");
    }


	/* Open file with updating only the number of r/w bytes in _RIOFB_T */
	if ((fp = _Ropen ("ASTSUPPORT/CLIDTRNSLF", "rr, riofb=n")) == NULL) {
		die("Error opening database file");
	}


    /* Keep listening for data */
    while( exit_flag == 0 ) {
        /* Erase buffers for use */
        memset(asciiBuf, '\0', BUFSIZE);
        memset(ebcdicBuf, '\0', BUFSIZE);
        memset(cmdBuf, '\0', BUFSIZE);

        /* Read packet from network. Client_addr will contain sender info. */
        if ( (n = recvfrom(sockfd, asciiBuf, BUFSIZE, 0,
                    (struct sockaddr *)&client_addr, &len)) == -1) {
            if ( errno == EINTR ) {
                continue;
            } else {
                die("recvfrom()");
            }
        }

        /* Convert EOL to EOS */
        for ( i = 0; i++; i < BUFSIZ ) {
            if ( asciiBuf[i] == _CR || asciiBuf[i] == _LF ) {
                asciiBuf[i] = '\0';
            }
        }

        /* Short cut for an empty input line. */
        if ( strlen(asciiBuf) >= 1 ) {

            /* Convert to EBCDIC, so we understand
             * what we've been asked to do.
             */
            convert_buffer(asciiBuf, ebcdicBuf, strlen(asciiBuf),
                    strlen(asciiBuf), a_e_ccsid);

            if ( strncmp(ebcdicBuf, "TRANSLATE", 9) == 0 ) {
                /* Extract number to translate. */
                number = strtok(ebcdicBuf, " ");
                number = strtok(NULL, " ");
                number[strlen(number) - 1] = 0x0;

                /* FIXME: Check if our input is all digits. */

                /* Locate record and print what we've found. */
                rfb = _Rreadk(fp, &transrec, _TRANSRECSZ, __DFT,
                        number, strlen(number));
                memset(ebcdicBuf, '\0', BUFSIZE);

                /* FIXME: Error handling! We only know if there was something
                 *        wrong when we don't receive a full-sized record,
                 *        but we wanna know *what* went wrong, also.
                 */
                if (( rfb->num_bytes < _TRANSRECSZ )) {
                    Qp0zLprintf("rfb->num_bytes = %d, sending back '%s'\n",
                        rfb->num_bytes, number);
                    seprintf(e_a_ccsid, ebcdicBuf, "%s", number);

                } else {
                    /* Chop blanks at end of string. Omit \0 at end! */
                    for ( i = sizeof(transrec.CLNAME) - 1; i >= 0; i-- ) {
                        if ( transrec.CLNAME[i] == ' '
                             || transrec.CLNAME[i] == '\t' ) {
                                transrec.CLNAME[i] = '\0';
                        } else {
                            break;
                        }
                    }

                    Qp0zLprintf("rfb->num_bytes = %d, sending back '%s'\n",
                        rfb->num_bytes, transrec.CLNAME);
                    seprintf(e_a_ccsid, ebcdicBuf, "%s", transrec.CLNAME);
                }
                /* FIXME: Maybe add a newline, for more convenient debugging? */
                sendto(sockfd, ebcdicBuf, strlen(ebcdicBuf), 0,
                        (struct sockaddr *)&client_addr, len);
            }
        }
    }

    close(sockfd);
	_Rclose(fp);

	return(0);
}

/* -----------------------------------------------------------------------------
 * vim: ft=c colorcolumn=81 autoindent shiftwidth=4 tabstop=4 expandtab
 */
