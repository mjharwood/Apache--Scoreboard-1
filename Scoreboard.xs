#include "modules/perl/mod_perl.h"
#include "scoreboard.h"

#ifndef HZ
#define HZ 100
#endif

typedef struct {
    short_score record;
    int idx;
} Apache__server_score;

typedef Apache__server_score * Apache__ServerScore;

typedef struct {
    parent_score record;
    int idx;
    scoreboard *image;
} Apache__parent_score;

typedef Apache__parent_score * Apache__ParentScore;

typedef scoreboard * Apache__Scoreboard;

#define server_score_status(s)          s->record.status
#define server_score_access_count(s)    s->record.access_count
#define server_score_bytes_served(s)    s->record.bytes_served
#define server_score_my_access_count(s) s->record.my_access_count
#define server_score_my_bytes_served(s) s->record.my_bytes_served
#define server_score_conn_bytes(s)      s->record.conn_bytes
#define server_score_conn_count(s)      s->record.conn_count
#define server_score_client(s)          s->record.client
#define server_score_request(s)         s->record.request

#define server_score_vhost(s)                           \
    s->record.vhostrec && ap_scoreboard_image           \
        ? s->record.vhostrec->server_hostname           \
        : ""

#define parent_score_pid(s) s->record.pid

static scoreboard *my_scoreboard_image = NULL;

static char status_flags[SERVER_NUM_STATUS];

static void status_flags_init(void)
{
    status_flags[SERVER_DEAD] = '.';
    status_flags[SERVER_READY] = '_';
    status_flags[SERVER_STARTING] = 'S';
    status_flags[SERVER_BUSY_READ] = 'R';
    status_flags[SERVER_BUSY_WRITE] = 'W';
    status_flags[SERVER_BUSY_KEEPALIVE] = 'K';
    status_flags[SERVER_BUSY_LOG] = 'L';
    status_flags[SERVER_BUSY_DNS] = 'D';
    status_flags[SERVER_GRACEFUL] = 'G';
}

static SV *size_string(size_t size)
{
    SV *sv = newSVpv("    -", 5);
    if (size == (size_t)-1) {
	/**/
    }
    else if (!size) {
	sv_setpv(sv, "   0k");
    }
    else if (size < 1024) {
	sv_setpv(sv, "   1k");
    }
    else if (size < 1048576) {
	sv_setpvf(sv, "%4dk", (size + 512) / 1024);
    }
    else if (size < 103809024) {
	sv_setpvf(sv, "%4.1fM", size / 1048576.0);
    }
    else {
	sv_setpvf(sv, "%4dM", (size + 524288) / 1048576);
    }

    return sv;
}

#include "apxs/send.c"

MODULE = Apache::Scoreboard   PACKAGE = Apache::Scoreboard   PREFIX = scoreboard_

BOOT:
{
    HV *stash = gv_stashpv("Apache::Constants", TRUE);
    newCONSTSUB(stash, "HARD_SERVER_LIMIT",
		newSViv(HARD_SERVER_LIMIT));
    stash = gv_stashpv("Apache::Scoreboard", TRUE);
    newCONSTSUB(stash, "REMOTE_SCOREBOARD_TYPE",
		newSVpv(REMOTE_SCOREBOARD_TYPE, 0));
    status_flags_init();
}

void
END()

    CODE:
    if (my_scoreboard_image) {
	safefree(my_scoreboard_image);
	my_scoreboard_image = NULL;
    }

SV *
size_string(size)
    size_t size

int
scoreboard_send(r)
    Apache r

Apache::Scoreboard
thaw(CLASS, packet)
    SV *CLASS
    SV *packet

    PREINIT:
    int psize, ssize;
    char *ptr;

    CODE:
    if (!(SvOK(packet) && SvCUR(packet) > (SIZE16*2))) {
	XSRETURN_UNDEF;
    }

    if (!my_scoreboard_image) {
	my_scoreboard_image = 
	  (scoreboard *)safemalloc(sizeof(*my_scoreboard_image));
    }
    Zero(my_scoreboard_image, 1, scoreboard); /*XXX*/

    RETVAL = my_scoreboard_image;
    ptr = SvPVX(packet);
    psize = unpack16(ptr);
    ptr += SIZE16;
    ssize = unpack16(ptr);
    ptr += SIZE16;

    Move(ptr, &RETVAL->parent[0], psize, char);
    ptr += psize;
    Move(ptr, &RETVAL->servers[0], ssize, char);
    ptr += ssize;
    Move(ptr, &RETVAL->global, sizeof(global_score), char);

    OUTPUT:
    RETVAL

Apache::Scoreboard
image(CLASS)
    SV *CLASS

    CODE:
    if (ap_exists_scoreboard_image()) {
	RETVAL = ap_scoreboard_image;
	ap_sync_scoreboard_image();
    }

    OUTPUT:
    RETVAL

Apache::ServerScore
servers(image, idx=0)
    Apache::Scoreboard image
    int idx

    ALIAS:
    self = 1

    CODE:
    RETVAL = (Apache__ServerScore )safemalloc(sizeof(*RETVAL));

    if (XSANY.any_i32 == 1) {
	int i;
	SV *sv = perl_get_sv("$$", TRUE); /* avoid getpid() call */
	pid_t pid = SvIV(sv);
	for (i=0; i<HARD_SERVER_LIMIT; i++) {
	    if (image->parent[i].pid == pid) {
		RETVAL->record = image->servers[i];
	    }
	}
    }
    else {
	RETVAL->record = image->servers[idx];
    }

    OUTPUT:
    RETVAL

Apache::ParentScore
parent(image, idx=0)
    Apache::Scoreboard image
    int idx

    CODE:
    RETVAL = (Apache__ParentScore )safemalloc(sizeof(*RETVAL));
    RETVAL->record = image->parent[idx];
    RETVAL->idx = idx;
    RETVAL->image = image;

    OUTPUT:
    RETVAL

void
pids(image)
    Apache::Scoreboard image

    PREINIT:
    AV *av = newAV();
    int i;

    PPCODE:
    for (i=0; i<HARD_SERVER_LIMIT; i++) {
	if (!image->parent[i].pid) {
	    break;
	}
	av_push(av, newSViv(image->parent[i].pid));
    }

    XPUSHs(sv_2mortal(newRV_noinc((SV*)av)));
    
MODULE = Apache::Scoreboard   PACKAGE = Apache::ServerScore   PREFIX = server_score_

void
DESTROY(self)
    Apache::ServerScore self

    CODE:
    safefree(self);

void
times(self)
    Apache::ServerScore self

    PPCODE:
    if (GIMME == G_ARRAY) {
	/* same return values as CORE::times() */
	EXTEND(sp, 4);
	PUSHs(sv_2mortal(newSViv(self->record.times.tms_utime)));
	PUSHs(sv_2mortal(newSViv(self->record.times.tms_stime)));
	PUSHs(sv_2mortal(newSViv(self->record.times.tms_cutime)));
	PUSHs(sv_2mortal(newSViv(self->record.times.tms_cstime)));
    }
    else {
#ifdef _SC_CLK_TCK
	float tick = sysconf(_SC_CLK_TCK);
#else
	float tick = HZ;
#endif
	if (self->record.access_count) {
	    /* cpu %, same value mod_status displays */
	      float RETVAL = (self->record.times.tms_utime +
			      self->record.times.tms_stime +
			      self->record.times.tms_cutime +
			      self->record.times.tms_cstime);
	    XPUSHs(sv_2mortal(newSVnv((double)RETVAL/tick)));
	}
	else {
	    XPUSHs(sv_2mortal(newSViv((0))));
	}
    }

void
start_time(self)
    Apache::ServerScore self

    ALIAS:
    stop_time = 1

    PREINIT:
    struct timeval tp;

    PPCODE:
    tp = (XSANY.any_i32 == 0) ? 
         self->record.start_time : self->record.stop_time;

    /* do the same as Time::HiRes::gettimeofday */
    if (GIMME == G_ARRAY) {
	EXTEND(sp, 2);
	PUSHs(sv_2mortal(newSViv(tp.tv_sec)));
	PUSHs(sv_2mortal(newSViv(tp.tv_usec)));
    } 
    else {
	EXTEND(sp, 1);
	PUSHs(sv_2mortal(newSVnv(tp.tv_sec + (tp.tv_usec / 1000000.0))));
    }

long
req_time(self)
    Apache::ServerScore self

    CODE:
    /* request time in millseconds, same value mod_status displays  */
    if (self->record.start_time.tv_sec == 0L &&
	self->record.start_time.tv_usec == 0L) {
	RETVAL = 0L;
    }
    else {
	RETVAL =
	  ((self->record.stop_time.tv_sec - 
	    self->record.start_time.tv_sec) * 1000) +
	      ((self->record.stop_time.tv_usec - 
		self->record.start_time.tv_usec) / 1000);
    }
    if (RETVAL < 0L || !self->record.access_count) {
	RETVAL = 0L;
    }

    OUTPUT:
    RETVAL

SV *
server_score_status(self)
    Apache::ServerScore self

    CODE:
    RETVAL = newSV(0);
    sv_setnv(RETVAL, (double)self->record.status);
    sv_setpvf(RETVAL, "%c", status_flags[self->record.status]);
    SvNOK_on(RETVAL); /* dual-var */ 

    OUTPUT:
    RETVAL

unsigned long
server_score_access_count(self)
    Apache::ServerScore self

unsigned long
server_score_bytes_served(self)
    Apache::ServerScore self

unsigned long
server_score_my_access_count(self)
    Apache::ServerScore self

unsigned long
server_score_my_bytes_served(self)
    Apache::ServerScore self

unsigned long
server_score_conn_bytes(self)
    Apache::ServerScore self

unsigned short
server_score_conn_count(self)
    Apache::ServerScore self

char *
server_score_client(self)
    Apache::ServerScore self

char *
server_score_request(self)
    Apache::ServerScore self

char *
server_score_vhost(self)
    Apache::ServerScore self
    
MODULE = Apache::Scoreboard   PACKAGE = Apache::ParentScore   PREFIX = parent_score_

void
DESTROY(self)
    Apache::ParentScore self

    CODE:
    safefree(self);

pid_t
parent_score_pid(self)
    Apache::ParentScore self

Apache::ParentScore
next(self)
    Apache::ParentScore self

    CODE:
    ++self->idx;
    if (!self->image->parent[self->idx].pid) {
	XSRETURN_UNDEF;
    }
    RETVAL = (Apache__ParentScore )safemalloc(sizeof(*RETVAL));
    RETVAL->record = self->image->parent[self->idx];
    RETVAL->idx = self->idx;
    RETVAL->image = self->image;

    OUTPUT:
    RETVAL

Apache::ServerScore
server(self)
    Apache::ParentScore self

    CODE:
    RETVAL = (Apache__ServerScore )safemalloc(sizeof(*RETVAL));
    RETVAL->record = self->image->servers[self->idx];

    OUTPUT:
    RETVAL
