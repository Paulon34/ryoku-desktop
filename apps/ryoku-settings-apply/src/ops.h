#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Allowlisted operations for ryoku-settings-apply. */
enum RyokuApplyOp {
    RYOKU_APPLY_OP_INVALID = -1,
    RYOKU_APPLY_OP_APPLY = 0,
    RYOKU_APPLY_OP_ROLLBACK = 1,
    RYOKU_APPLY_OP_SWITCH_GENERATION = 2,
};

/* Returns RYOKU_APPLY_OP_* for exact token match; no substrings.
 * For switch-generation the token is exactly "switch-generation". */
int ryoku_parse_operation(const char *arg);

/* Strict positive decimal generation number (no signs, spaces, suffixes).
 * Returns 0 on success and writes *out (>= 1). Returns -1 on reject. */
int ryoku_parse_generation_number(const char *arg, unsigned *out);

/* Writes /nix/var/nix/profiles/system-<N>-link into buf. Returns 0 on success. */
int ryoku_system_generation_link_path(unsigned gen, char *buf, size_t buflen);

/* Validate that system-<gen>-link exists, is a symlink into /nix/store/,
 * and looks like a NixOS system (nixos-version + switch-to-configuration).
 * On success writes canonical store path into canon_out.
 * Returns 0 on success, -1 on failure (message in err_out when provided). */
int ryoku_validate_system_generation(unsigned gen,
                                     char *canon_out, size_t canon_len,
                                     char *err_out, size_t err_len);

#ifdef __cplusplus
}
#endif
