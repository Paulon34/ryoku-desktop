/*
 * ryoku-settings-apply — privileged helper for Ryoku Settings.
 *
 * Allowlisted operations only:
 *   ryoku-settings-apply apply
 *   ryoku-settings-apply rollback
 *   ryoku-settings-apply switch-generation <N>
 *
 * Repo path and flake host are compile-time constants from the Nix package.
 * The GUI never supplies repo/host/command strings — only an allowlisted
 * operation token and, for switch-generation, a strict integer.
 *
 * No shell. No system(). fork + execv + waitpid only.
 */

#include "ops.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef RYOKU_REPO_PATH
#error "RYOKU_REPO_PATH must be defined at compile time"
#endif

#ifndef RYOKU_FLAKE_HOST
#error "RYOKU_FLAKE_HOST must be defined at compile time"
#endif

#ifndef RYOKU_NIXOS_REBUILD
#error "RYOKU_NIXOS_REBUILD must be defined at compile time"
#endif

#ifndef RYOKU_NIX_ENV
#error "RYOKU_NIX_ENV must be defined at compile time"
#endif

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

static const char *kSystemProfile = "/nix/var/nix/profiles/system";

static void usage(void)
{
    fprintf(stderr,
            "usage: ryoku-settings-apply {apply|rollback|switch-generation <N>}\n"
            "\n"
            "Privileged Ryoku Settings helper. Operations are allowlisted.\n"
            "Repo and host are fixed at build time.\n"
            "switch-generation accepts only a positive decimal generation number.\n");
}

static int run_execv_wait(const char *path, char *const argv[])
{
    const pid_t pid = fork();
    if (pid < 0) {
        fprintf(stderr, "ryoku-settings-apply: fork failed: %s\n", strerror(errno));
        return 2;
    }
    if (pid == 0) {
        execv(path, argv);
        fprintf(stderr, "ryoku-settings-apply: execv(%s) failed: %s\n", path, strerror(errno));
        _exit(127);
    }

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        fprintf(stderr, "ryoku-settings-apply: waitpid failed: %s\n", strerror(errno));
        return 2;
    }
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) {
        fprintf(stderr, "ryoku-settings-apply: child killed by signal %d\n", WTERMSIG(status));
        return 2;
    }
    return 2;
}

static int profile_points_to_generation(unsigned gen)
{
    char expected[64];
    if (snprintf(expected, sizeof(expected), "system-%u-link", gen) >= (int)sizeof(expected))
        return 0;
    char buf[PATH_MAX];
    const ssize_t n = readlink(kSystemProfile, buf, sizeof(buf) - 1);
    if (n < 0)
        return 0;
    buf[n] = '\0';
    /* readlink may return relative "system-N-link" or absolute path ending with it */
    if (strcmp(buf, expected) == 0)
        return 1;
    const size_t elen = strlen(expected);
    const size_t blen = strlen(buf);
    if (blen >= elen && strcmp(buf + (blen - elen), expected) == 0) {
        if (blen == elen || buf[blen - elen - 1] == '/')
            return 1;
    }
    return 0;
}

static int do_switch_generation(unsigned gen)
{
    char err[512];
    char canon[PATH_MAX];
    if (ryoku_validate_system_generation(gen, canon, sizeof(canon), err, sizeof(err)) != 0) {
        fprintf(stderr, "ryoku-settings-apply: %s\n", err);
        return 3;
    }

    char genstr[32];
    if (snprintf(genstr, sizeof(genstr), "%u", gen) >= (int)sizeof(genstr)) {
        fprintf(stderr, "ryoku-settings-apply: generation string overflow\n");
        return 2;
    }

    fprintf(stderr, "ryoku-settings-apply: switching profile to generation %u\n", gen);
    fprintf(stderr, "ryoku-settings-apply: target %s\n", canon);

    char *const env_args[] = {
        (char *)"nix-env",
        (char *)"--profile",
        (char *)kSystemProfile,
        (char *)"--switch-generation",
        genstr,
        NULL,
    };
    const int env_rc = run_execv_wait(RYOKU_NIX_ENV, env_args);
    if (env_rc != 0) {
        fprintf(stderr,
                "ryoku-settings-apply: nix-env --switch-generation failed (exit %d)\n",
                env_rc);
        return env_rc == 0 ? 2 : env_rc;
    }

    if (!profile_points_to_generation(gen)) {
        fprintf(stderr,
                "ryoku-settings-apply: after nix-env, system profile does not point to "
                "generation %u — aborting activation\n",
                gen);
        return 4;
    }

    /* Profile link name matches; also require canonical store path == validated target. */
    char profile_real[PATH_MAX];
    profile_real[0] = '\0';
    if (!realpath(kSystemProfile, profile_real) || strcmp(profile_real, canon) != 0) {
        fprintf(stderr,
                "ryoku-settings-apply: after nix-env, profile canonical path mismatch "
                "(got '%s', expected '%s') — aborting activation\n",
                profile_real[0] ? profile_real : "(unresolved)",
                canon);
        return 4;
    }

    /* Activate the validated store path directly (not via profile symlink).
     * Same outcome as nixos-rebuild after nix-env --switch-generation, with an
     * explicit TOPLEVEL that cannot drift if the profile symlink races. */
    char stc[PATH_MAX];
    if (snprintf(stc, sizeof(stc), "%s/bin/switch-to-configuration", canon)
        >= (int)sizeof(stc)) {
        fprintf(stderr, "ryoku-settings-apply: switch-to-configuration path overflow\n");
        return 2;
    }

    fprintf(stderr, "ryoku-settings-apply: activating via %s switch\n", stc);
    char *const stc_args[] = {
        stc,
        (char *)"switch",
        NULL,
    };
    execv(stc, stc_args);
    fprintf(stderr, "ryoku-settings-apply: execv(%s) failed: %s\n", stc, strerror(errno));
    /* Profile already moved; activation did not start. Report clearly — no auto-rollback. */
    fprintf(stderr,
            "ryoku-settings-apply: WARNING: profile may point to generation %u but "
            "activation failed to start\n",
            gen);
    return 2;
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        usage();
        return 1;
    }

    const int op = ryoku_parse_operation(argv[1]);
    if (op == RYOKU_APPLY_OP_INVALID) {
        fprintf(stderr, "ryoku-settings-apply: invalid operation '%s'\n", argv[1]);
        usage();
        return 1;
    }

    if (op == RYOKU_APPLY_OP_SWITCH_GENERATION) {
        if (argc != 3) {
            fprintf(stderr, "ryoku-settings-apply: switch-generation requires exactly one number\n");
            usage();
            return 1;
        }
        unsigned gen = 0;
        if (ryoku_parse_generation_number(argv[2], &gen) != 0) {
            fprintf(stderr, "ryoku-settings-apply: invalid generation number '%s'\n", argv[2]);
            return 1;
        }
        return do_switch_generation(gen);
    }

    if (argc != 2) {
        usage();
        return 1;
    }

    if (op == RYOKU_APPLY_OP_APPLY) {
        char flakeRef[4096];
        const int n = snprintf(flakeRef, sizeof(flakeRef), "%s#%s",
                               RYOKU_REPO_PATH, RYOKU_FLAKE_HOST);
        if (n < 0 || (size_t)n >= sizeof(flakeRef)) {
            fprintf(stderr, "ryoku-settings-apply: flake ref too long\n");
            return 2;
        }

        char *const args[] = {
            (char *)"nixos-rebuild",
            (char *)"switch",
            (char *)"--flake",
            flakeRef,
            NULL,
        };
        execv(RYOKU_NIXOS_REBUILD, args);
        fprintf(stderr, "ryoku-settings-apply: execv(%s) failed: %s\n",
                RYOKU_NIXOS_REBUILD, strerror(errno));
        return 2;
    }

    /* rollback */
    {
        char *const args[] = {
            (char *)"nixos-rebuild",
            (char *)"switch",
            (char *)"--rollback",
            NULL,
        };
        execv(RYOKU_NIXOS_REBUILD, args);
        fprintf(stderr, "ryoku-settings-apply: execv(%s) failed: %s\n",
                RYOKU_NIXOS_REBUILD, strerror(errno));
        return 2;
    }
}
