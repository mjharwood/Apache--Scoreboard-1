#define REMOTE_SCOREBOARD_TYPE "application/x-apache-scoreboard"

#ifndef Move
#define Move(s,d,n,t) (void)memmove((char*)(d),(char*)(s), (n) * sizeof(t)) 
#endif
#ifndef Copy
#define Copy(s,d,n,t) (void)memcpy((char*)(d),(char*)(s), (n) * sizeof(t))
#endif

#define SIZE16 2

static void pack16(unsigned char *s, int p)
{
    short ashort = htons(p);
    Move(&ashort, s, SIZE16, unsigned char);
}

static unsigned short unpack16(unsigned char *s)
{
    unsigned short ashort;
    Copy(s, &ashort, SIZE16, char);
    return ntohs(ashort);
}

static int scoreboard_send(request_rec *r)
{
    int i, psize, ssize, tsize;
    char buf[SIZE16*2];
    char *ptr = buf;

    ap_sync_scoreboard_image();
    for (i=0; i<HARD_SERVER_LIMIT; i++) {
	if (!ap_scoreboard_image->parent[i].pid) {
	    break;
	}
    }

    psize = i * sizeof(parent_score);
    ssize = i * sizeof(short_score);
    tsize = psize + ssize + sizeof(global_score) + sizeof(buf);

    pack16(ptr, psize);
    ptr += SIZE16;
    pack16(ptr, ssize);

    ap_set_content_length(r, tsize);
    r->content_type = REMOTE_SCOREBOARD_TYPE;
    ap_send_http_header(r);

    if (!r->header_only) {
	ap_rwrite(&buf[0], sizeof(buf), r);
	ap_rwrite(&ap_scoreboard_image->parent[0], psize, r);
	ap_rwrite(&ap_scoreboard_image->servers[0], ssize, r);
	ap_rwrite(&ap_scoreboard_image->global, sizeof(global_score), r);
    }

    return OK;
}
