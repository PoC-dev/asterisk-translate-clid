# Variables used by rules
DSTLIB=ASTSUPPORT
SRCFILE=SOURCES
STAMPFILE=BLDTMSTMPS

# Global rules for recreating everything, if required --------------------------
all: curlib CMDCTI<MENU> clidtrans CALLTRANSD<PGM>

# This is to make sure that even if we run in batch, we can use unqualified
# names in rules. Because there are no dependents, the rule is executed always.
curlib:
    CHGCURLIB CURLIB($(DSTLIB))

# Menu -------------------------------------------------------------------------
CMDCTI<MENU>: CMDCTI.$(SRCFILE)
    CRTMNU MENU(CMDCTI) TYPE(*UIM) SRCFILE($(SRCFILE)) INCFILE(QGPL/MENUUIM)

# CallerID-Translator maintenance -----------------------------------------------
clidtrans: CLIDTRNDHP<PNLGRP> CLIDTRNSHP<PNLGRP> CLIDTRNSPG<PGM>

CLIDTRNDHP<PNLGRP>: CLIDTRNDHP.$(SRCFILE)
    CRTPNLGRP PNLGRP(CLIDTRNDHP) SRCFILE($(SRCFILE))

CLIDTRNSHP<PNLGRP>: CLIDTRNSHP.$(SRCFILE)
    CRTPNLGRP PNLGRP(CLIDTRNSHP) SRCFILE($(SRCFILE))


CLIDTRNSPF.$(STAMPFILE): CLIDTRNSPF.$(SRCFILE)
    CHGPF FILE(CLIDTRNSPF) SRCFILE($(SRCFILE))
    -RMVM FILE($(STAMPFILE)) MBR(CLIDTRNSPF)
    ADDPFM FILE($(STAMPFILE)) MBR(CLIDTRNSPF)

CLIDTRNSLF.$(STAMPFILE): CLIDTRNSLF.$(SRCFILE) CLIDTRNSPF.$(STAMPFILE)
    CRTLF FILE(CLIDTRNSLF) SRCFILE($(SRCFILE)) REPLACE(*YES)
    -RMVM FILE($(STAMPFILE)) MBR(CLIDTRNSLF)
    ADDPFM FILE($(STAMPFILE)) MBR(CLIDTRNSLF)

CLIDTRNSDF<FILE>: CLIDTRNSDF.$(SRCFILE) CLIDTRNSPF.$(STAMPFILE)
    CRTDSPF FILE(CLIDTRNSDF) SRCFILE($(SRCFILE))


CLIDTRNSPG<PGM>: CLIDTRNSPG.$(SRCFILE) CLIDTRNSDF<FILE> +
        CLIDTRNSPF.$(STAMPFILE)  CLIDTRNSLF.$(STAMPFILE)
    CRTBNDRPG PGM(CLIDTRNSPG) SRCFILE($(SRCFILE))

# Asterisk CLID network listener ------------------------------------------------
CALLTRANSD<PGM>: CALLTRANSD.$(SRCFILE) CLIDTRNSLF.$(STAMPFILE)
    CRTBNDC PGM(CALLTRANSD) SRCFILE($(SRCFILE)) OPTIMIZE(*FULL)

# EOF --------------------------------------------------------------------------
# vim: ft=make textwidth=80 colorcolumn=81 expandtab tabstop=4 shiftwidth=4
