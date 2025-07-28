#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/fanotify.h>

#define DEVICE_PATH "/dev/video0"

int main(void) {
    int fanotify_fd = fanotify_init(FAN_CLOEXEC | FAN_CLASS_CONTENT, O_RDONLY | O_LARGEFILE);
    if (fanotify_fd == -1) {
        perror("fanotify_init");
        return 1;
    }

    // Add a watch for /dev/video0
    int wd = fanotify_mark(fanotify_fd, FAN_MARK_ADD | FAN_MARK_MOUNT, FAN_ACCESS | FAN_CLOSE_WRITE, AT_FDCWD, DEVICE_PATH);
    if (wd == -1) {
        perror("fanotify_mark");
        close(fanotify_fd);
        return 1;
    }

    printf("Monitoring /dev/video0 access. Press Ctrl+C to stop.\n");

    char buf[4096];
    ssize_t len;
    struct fanotify_event_metadata *event;

    while (1) {
        len = read(fanotify_fd, buf, sizeof(buf));
        if (len == -1) {
            perror("read");
            continue;
        }

        printf("Received %zd bytes of fanotify event data.\n", len);

        for (char *ptr = buf; ptr < buf + len; ptr += event->event_len) {
            event = (struct fanotify_event_metadata *)ptr;

            printf("Event mask: 0x%016llx\n", (unsigned long long)event->mask);
            printf("Event FD: %d\n", event->fd);
            printf("Event PID: %d\n", event->pid);
            printf("Event path: %s\n", DEVICE_PATH);

            char path[PATH_MAX];

            if (event->fd >= 0) {
                snprintf(path, PATH_MAX, "/proc/self/fd/%d", event->fd);
                ssize_t path_len = readlink(path, path, PATH_MAX);
                if (path_len >= 0) {
                    path[path_len] = '\0';
                    printf("Process %d accessed %s\n", event->pid, path);
                } else {
                    perror("readlink");
                }
                close(event->fd);
            }
        }
    }

    close(fanotify_fd);
    return 0;
}
