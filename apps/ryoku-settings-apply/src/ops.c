#include "ops.h"

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

int ryoku_parse_operation(const char *arg)
{
    if (!arg)
        return RYOKU_APPLY_OP_INVALID;
    if (strcmp(arg, "apply") == 0)
        return RYOKU_APPLY_OP_APPLY;
    if (strcmp(arg, "rollback") == 0)
        return RYOKU_APPLY_OP_ROLLBACK;
    if (strcmp(arg, "switch-generation") == 0)
        return RYOKU_APPLY_OP_SWITCH_GENERATION;
    return RYOKU_APPLY_OP_INVALID;
}

int ryoku_parse_generation_number(const char *arg, unsigned *out)
{
    if (!arg || !out || !*arg)
        return -1;
    /* Reject signs, spaces, hex, suffixes — digits only, no leading zeros unless "0" which we reject. */
    for (const char *p = arg; *p; ++p) {
        if (!isdigit((unsigned char)*p))
            return -1;
    }
    if (arg[0] == '0')
        return -1; /* 0 and 01.. invalid */

    errno = 0;
    char *end = NULL;
    unsigned long v = strtoul(arg, &end, 10);
    if (errno != 0 || end == arg || (end && *end != '\0'))
        return -1;
    if (v < 1UL || v > 1000000UL) /* hard upper bound against absurd values */
        return -1;
    *out = (unsigned)v;
    return 0;
}

int ryoku_system_generation_link_path(unsigned gen, char *buf, size_t buflen)
{
    if (!buf || buflen < 48)
        return -1;
    const int n = snprintf(buf, buflen, "/nix/var/nix/profiles/system-%u-link", gen);
    if (n < 0 || (size_t)n >= buflen)
        return -1;
    return 0;
}

static int set_err(char *err_out, size_t err_len, const char *msg)
{
    if (err_out && err_len > 0) {
        snprintf(err_out, err_len, "%s", msg ? msg : "validation failed");
    }
    return -1;
}

int ryoku_validate_system_generation(unsigned gen,
                                     char *canon_out, size_t canon_len,
                                     char *err_out, size_t err_len)
{
    if (gen < 1)
        return set_err(err_out, err_len, "generation must be >= 1");

    char linkpath[PATH_MAX];
    if (ryoku_system_generation_link_path(gen, linkpath, sizeof(linkpath)) != 0)
        return set_err(err_out, err_len, "cannot format generation link path");

    struct stat st;
    if (lstat(linkpath, &st) != 0)
        return set_err(err_out, err_len, "generation link does not exist");
    if (!S_ISLNK(st.st_mode))
        return set_err(err_out, err_len, "generation path is not a symlink");

    char resolved[PATH_MAX];
    if (!realpath(linkpath, resolved))
        return set_err(err_out, err_len, "cannot canonicalize generation link");

    if (strncmp(resolved, "/nix/store/", 11) != 0)
        return set_err(err_out, err_len, "generation target is not in /nix/store");

    char version_path[PATH_MAX];
    char stc_path[PATH_MAX];
    if (snprintf(version_path, sizeof(version_path), "%s/nixos-version", resolved) >= (int)sizeof(version_path)
        || snprintf(stc_path, sizeof(stc_path), "%s/bin/switch-to-configuration", resolved)
               >= (int)sizeof(stc_path))
        return set_err(err_out, err_len, "path too long");

    if (access(version_path, R_OK) != 0)
        return set_err(err_out, err_len, "missing nixos-version in generation");
    if (access(stc_path, X_OK) != 0)
        return set_err(err_out, err_len, "missing switch-to-configuration in generation");

    if (canon_out && canon_len > 0) {
        if (strlen(resolved) + 1 > canon_len)
            return set_err(err_out, err_len, "canonical path buffer too small");
        memcpy(canon_out, resolved, strlen(resolved) + 1);
    }
    return 0;
}
