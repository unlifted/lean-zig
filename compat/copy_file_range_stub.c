// Stub implementation of copy_file_range for glibc 2.27 compatibility
// This function is only used by Zig's standard library in some code paths
// that are not actually exercised in lean-zig usage.

#include <errno.h>
#include <sys/types.h>

ssize_t copy_file_range(int fd_in, off_t *off_in,
                       int fd_out, off_t *off_out,
                       size_t len, unsigned int flags)
{
    // Return ENOSYS (function not implemented) to signal fallback needed
    errno = ENOSYS;
    return -1;
}
