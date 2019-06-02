prefix		::= $(shell knoconfig prefix)
exec_prefix	::= $(shell knoconfig exec_prefix)
libsuffix	::= $(shell knoconfig libsuffix)

BINDIR		::= $(shell knoconfig bin)
LIBDIR		::= $(shell knoconfig lib)
ETC		::= $(shell knoconfig etc)
CFLAGS		::= $(shell knoconfig cflags)
LDFLAGS		::= $(shell knoconfig ldflags)
LIBS		::= $(shell knoconfig libs)
LIB		::= $(shell knoconfig lib)
CMODULES	::= $(shell knoconfig cmodules)
DATADIR		::= $(shell knoconfig data)
INCLUDE		::= $(shell knoconfig include)
KNO_VERSION	::= $(shell knoconfig version)
KNO_MAJOR	::= $(shell knoconfig major)
KNO_MINOR	::= $(shell knoconfig minor)
RELEASE	        ::= $(shell cat etc/release)
ADMINGROUP	::= $(shell knoconfig admin_group)
BUILTIN		::= $(shell knoconfig builtin_modules)
CODENAME	::= $(shell etc/getrelease)
PKGVERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${RELEASE}
DPKG_FLAGS	::= -b

DESTDIR		=
DEBUG		= 
OPTIMIZE	=   -O3 -funroll-loops
#OPTIMIZE	=
LCFLAGS		=   -Wall ${DEBUG} ${OPTIMIZE}
XCFLAGS		=
APTREPO		=   /srv/repo/apt
GPG		=   $(shell which gpg2 || which gpg)
GPGID		=   repoman@beingmeta.com
MSG		=   echo
SUDO		=   sudo
INSTALL		=   ${SUDO} install -g $(ADMINGROUP) -m 775
INSTALLDATA	=   ${SUDO} install -g $(ADMINGROUP) -m 664
INSTALLDIR	=   ${SUDO} install -d -g $(ADMINGROUP) -m 775
LINKINSTALL	=   ${SUDO} ln -sf 

MACLIBTOOL	= $(CC) -dynamiclib -single_module \
			-undefined dynamic_lookup \
			$(LDFLAGS) $(LIBS)
MSG		= echo
MKSO		= $(CC) -shared $(LDFLAGS) $(LIBS)
MKSTATIC	= ld -r
XLIBS		= -lknocore -lknoscheme -lknotexttools

SOURCE_DIRS = modules modules/squad modules/dev modules/dev/english
DATA_DIRS   = modules/dev/english/data modules/dev/english/wn16 data/x2vec modules/data

OFSM_OBJECTS=ofsm.o tagxtract.o taglink.o
OFSM_SOURCES=shortcut.h ofsm.c tagxtract.c taglink.c

OBJECT_FILES=${OFSM_OBJECTS} x2vec.o
SOURCE_FILES=${OFSM_SOURCES} x2vec.c

# Build rules

%.o: %.c ./fileinfo
	@$(CC) $(CFLAGS) $(LCFLAGS) $(XCFLAGS) -D_FILEINFO="\"`./fileinfo $<`\"" -o $@ -c $<
	@$(MSG) CC $@ $<

%.so: %.o
	@$(MKSO) -o $@ $< ${XLIBS}
	@$(MSG) MKSO $@ $<
%.dylib: %.o
	@$(MACLIBTOOL) -install_name \
		@rpath/lib/`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		$(DYLIB_FLAGS) -o $@ $< ${XLIBS}
	@$(MSG) MACLIBTOOL $@

# Install rules

$(DESTDIR)$(INCLUDE)/%.h: %.h $(DESTDIR)$(INCLUDE)
	@$(INSTALL) $< $@
	@$(MSG) Installed $@

$(DESTDIR)$(CMODULES)/%.so.${KNO_VERSION}: %.so $(DESTDIR)$(CMODULES)
	@$(INSTALL) $< $@
	@$(MSG) Installed $@
$(DESTDIR)$(CMODULES)/%.so: $(DESTDIR)$(CMODULES)/%.so.${KNO_VERSION}
	@$(LINKINSTALL) $(shell basename $<) $@
	@$(MSG) Linked $@
$(DESTDIR)$(CMODULES)/%.so.${KNO_MAJOR}: $(DESTDIR)$(CMODULES)/%.so.${KNO_VERSION}
	@$(LINKINSTALL) $(shell basename $<) $@
	@$(MSG) Linked $@
$(DESTDIR)$(CMODULES)/%.so.${KNO_MAJOR}.${KNO_MINOR}: $(DESTDIR)$(CMODULES)/%.so.${KNO_VERSION}
	@$(LINKINSTALL) $(shell basename $<) $@
	@$(MSG) Linked $@

$(DESTDIR)$(CMODULES)/%.${KNO_VERSION}.dylib: %.dylib $(DESTDIR)$(CMODULES)
	@$(INSTALL) $< $@
	@$(MSG) Installed $@
$(DESTDIR)$(CMODULES)/%.dylib: $(DESTDIR)$(CMODULES)/%.${KNO_VERSION}.dylib
	@$(LINKINSTALL) $(shell basename $<) $@
	@$(MSG) Linked $@
$(DESTDIR)$(CMODULES)/%.${KNO_MAJOR}.dylib: $(DESTDIR)$(CMODULES)/%.${KNO_VERSION}.dylib
	@$(LINKINSTALL) $(shell basename $<) $@
	@$(MSG) Linked $@
$(DESTDIR)$(CMODULES)/%.${KNO_MAJOR}.${KNO_MINOR}.dylib: \
		$(DESTDIR)$(CMODULES)/%.${KNO_VERSION}.dylib
	@$(LINKINSTALL) $(shell basename $<) $@
	@$(MSG) Linked $@

$(DESTDIR)$(LIB)/%.a: %.a $(DESTDIR)$(LIB)
	@$(INSTALL) $< $@
	@$(MSG) Installed $@

# Top level targets

default: shared-libs TAGS

all binary: fileinfo shared-libs static-libs

clean:
	rm -f fileinfo *.o *.so *.a

debug: clean
	make XCFLAGS=-g OPTIMIZE= all

release: clean
	make XCFLAGS=-DPRODUCTION=1

fresh: clean
	make all

.PHONY: clean debug release default binary

# Other dependencies

fileinfo: etc/fileinfo.c
	@$(CC) -o fileinfo etc/fileinfo.c

$(OFSM_OBJECTS): shortcut.h fileinfo
x2vec.o: x2vec.h fileinfo

# Building libraries

static-libs: libofsm.a libx2vec.a 
shared-libs: ofsm.$(libsuffix) x2vec.$(libsuffix)

libofsm.a: $(OFSM_OBJECTS) makefile
	@$(MKSTATIC) -o $@ $(OFSM_OBJECTS)
	@$(MSG) MKSTATIC $@ $(OFSM_OBJECTS)
libx2vec.a: x2vec.o makefile
	@$(MKSTATIC) -o $@ $<
	@$(MSG) MKSTATIC $@ $<

ofsm.so: $(OFSM_OBJECTS) makefile
	@$(MKSO) -o $@ $(OFSM_OBJECTS) ${XLIBS}
	@$(MSG) MKSO $@ $(OFSM_OBJECTS)
ofsm.dylib: $(OFSM_OBJECTS) makefile
	@$(MACLIBTOOL) -install_name \
		@rpath/lib/`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		$(DYLIB_FLAGS) -o $@ $(OFSM_OBJECTS) ${XLIBS}
	@$(MSG) MACLIBTOOL $@ $(OFSM_OBJECTS)

x2vec.so: x2vec.o makefile
	@$(MKSO) -o $@ x2vec.o ${XLIBS}
	@$(MSG) MKSO $@ x2vec.o
x2vec.dylib: x2vec.o makefile
	@$(MACLIBTOOL) -install_name \
		@rpath/lib/`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		$(DYLIB_FLAGS) -o $@ x2vec.o ${XLIBS}
	@$(MSG) MACLIBTOOL $@ x2vec.o

$(DESTDIR)$(CMODULES) $(DESTDIR)$(LIB) $(DESTDIR)$(INCLUDE):
	${INSTALLDIR} $@


# Making directories

install: install-headers install-binary install-scheme

install-scheme:
	@$(SUDO) $(INSTALLDIR) $(DESTDIR)${BUILTIN}/ofsm/;
	@for src in $(SOURCE_DIRS); do  \
	  if test ! -z "$${src}"; then \
	    echo "Installing files from $${src}"; \
	    $(SUDO) $(INSTALLDIR) $(DESTDIR)$(BUILTIN)/$${src}/; \
	    $(SUDO) $(INSTALL) $${src}/*.scm $(DESTDIR)$(BUILTIN)/$${src}/; \
	  fi; \
	done;

install-data: install-lexdata install-x2vec-data

install-lexdata:
	@cd ./lexdata; s3update
	@$(SUDO) $(INSTALLDIR) $(DESTDIR)${DATADIR}/ofsm/;
	@$(SUDO) $(INSTALL) \
		lexdata/*.ztype lexdata/*.index lexdata/*.dtype lexdata/.s3root \
		$(DESTDIR)${DATADIR}/ofsm/;

install-x2vec-data:
	@$(SUDO) $(INSTALLDIR) $(DESTDIR)${BUILTIN}/ofsm/data/;
	@for src in $(DATA_DIRS); do 					\
	  if test ! -z "$${src}"; then 					\
	    $(SUDO) $(INSTALLDIR) $(DESTDIR)${BUILTIN}/$${src}/;	\
	    $(SUDO) $(INSTALL) $${src}/* $(DESTDIR)$(BUILTIN)/$${src}/;	\
	  fi; \
	done;

install-binary: install-static install-shared

install-static: $(DESTDIR)$(LIB)/libofsm.a $(DESTDIR)$(LIB)/libx2vec.a

install-shared: install-${libsuffix}

install-so: shared-libs						\
	$(DESTDIR)$(CMODULES)/x2vec.so.${KNO_VERSION} 		\
	$(DESTDIR)$(CMODULES)/x2vec.so.${KNO_MAJOR}.${KNO_MINOR}  	\
	$(DESTDIR)$(CMODULES)/x2vec.so.${KNO_MAJOR} 		\
	$(DESTDIR)$(CMODULES)/x2vec.so 				\
	$(DESTDIR)$(CMODULES)/ofsm.so.${KNO_VERSION}		\
	$(DESTDIR)$(CMODULES)/ofsm.so.${KNO_MAJOR}.${KNO_MINOR} 	\
	$(DESTDIR)$(CMODULES)/ofsm.so.${KNO_MAJOR}		\
	$(DESTDIR)$(CMODULES)/ofsm.so

install-dylib: shared-libs						\
	$(DESTDIR)$(CMODULES)/x2vec.${KNO_VERSION}.dylib 			\
	$(DESTDIR)$(CMODULES)/x2vec.${KNO_MAJOR}.${KNO_MINOR}.dylib 	\
	$(DESTDIR)$(CMODULES)/x2vec.${KNO_MAJOR}.dylib 			\
	$(DESTDIR)$(CMODULES)/x2vec.dylib	 			\
	$(DESTDIR)$(CMODULES)/ofsm.${KNO_VERSION}.dylib			\
	$(DESTDIR)$(CMODULES)/ofsm.${KNO_MAJOR}.${KNO_MINOR}.dylib 	\
	$(DESTDIR)$(CMODULES)/ofsm.${KNO_MAJOR}.dylib			\
	$(DESTDIR)$(CMODULES)/ofsm.dylib

install-headers: $(DESTDIR)$(INCLUDE)/ofsm.h $(DESTDIR)$(INCLUDE)/x2vec.h

.PHONY: install install-scheme install-data install-binary \
	install-static install-shared install-so install-dylib \
	install-headers

# Debian package building

staging/ofsm:
	git archive --prefix=ofsm_${PKGVERSION}/ \
	            -o staging/ofsm_${PKGVERSION}.tar HEAD;
	cd staging; tar -xf ofsm_${PKGVERSION}.tar; rm ofsm_${PKGVERSION}.tar;
	cd staging; tar -czvf ofsm_${PKGVERSION}.orig.tar.gz \
		ofsm_${PKGVERSION};
	mv staging/ofsm_${PKGVERSION}/dist/debian \
	   staging/ofsm_${PKGVERSION}/debian;
	etc/gitchangelog ofsm ${CODENAME} < dist/debian/changelog \
	   > staging/ofsm_${PKGVERSION}/debian/changelog;
	ln -s ofsm_${PKGVERSION} staging/ofsm
staging/ofsm.orig.tar.gz:
	make staging/ofsm_${PKGVERSION}
	tar -czvf $@ -C staging ofsm_${PKGVERSION}
	ln -s ofsm_${PKGVERSION}.orig.tar.gz staging/ofsm.orig.tar.gz

dist/debs.built: staging/ofsm
	(cd staging/ofsm_${PKGVERSION}; \
	 dpkg-buildpackage ${DPKG_FLAGS} -us -uc -rfakeroot) && \
	touch dist/debs.built;
dist/debs.signed: dist/debs.built
	(cd staging; debsign -p${GPG} --re-sign -k${GPGID} 		\
			ofsm_${PKGVERSION}*.changes) && 		\
	(cd staging; cp ofsm_${PKGVERSION}*.tar.?z ../dist) &&		\
	(cd staging; 						\
	 for file in beingmeta*${PKGVERSION}*.deb 		\
	            tagger*${PKGVERSION}*.changes 		\
	            tagger*${PKGVERSION}*.buildinfo; do	\
	  if test -f $${file}; then 				\
	   mv $${file} ../dist; fi; done;) &&			\
	touch dist/debs.signed;

debian: dist/debs.signed

dist/debs.done: dist/debs.signed
	touch dist/debs.done

install-debian install-debs debinstall installdebs: dist/debs.done
	$(SUDO) dpkg -i dist/beingmeta*_${PKGVERSION}*.deb

debclean:
	rm -rf staging/tagger* dist/*.deb dist/*.changes

debfresh freshdeb:
	rm -rf staging/tagger* dist/*.deb dist/*.changes
	make debian

update-local-apt-repo: dist/debs.done
	for change in dist/*.changes; do \
	  reprepro -Vb ${APTREPO} include ${CODENAME} $${change} && \
	  rm -f $${change}; \
	done

update-remote-apt-repo: dist/debs.done
	cd dist; for change in *.changes; do \
	  dupload -c --nomail --to ${CODENAME} $${change} && \
	  rm -f $${change}; \
	done

update-apt update-apt-repo: dist/debs.done
	if test -d ${APTREPO}; then	\
	  make update-local-apt-repo;	\
	else				\
	  make update-remote-apt-repo;	\
	fi;

TAGS: *.c *.h modules/*.scm modules/squad/*.scm modules/dev/*.scm modules/dev/english/*.scm makefile
	@etags *.c *.h makefile;
	@find modules -name "*.scm" -type f | grep -v module.scm | xargs etags -o TAGS -a
	@find modules/dev/web -regex ".*[.]\(html\|css\|fdcgi\|js\)" -type f | xargs etags -o TAGS -a

.PHONY: TAGS
