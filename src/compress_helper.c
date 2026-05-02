#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define DEFAULT_THREADS 4
#define MAX_THREADS 16
#define COPY_BUFFER_SIZE 65536

typedef struct {
  char chunk_path[PATH_MAX];
  char gzip_path[PATH_MAX];
  int status;
} compress_job_t;

static char *shell_quote(const char *value) {
  size_t len = 2;
  const char *cursor;
  char *quoted;
  char *out;

  for (cursor = value; *cursor != '\0'; cursor++) {
    len += (*cursor == '\'') ? 4 : 1;
  }

  quoted = malloc(len + 1);
  if (quoted == NULL) {
    return NULL;
  }

  out = quoted;
  *out++ = '\'';
  for (cursor = value; *cursor != '\0'; cursor++) {
    if (*cursor == '\'') {
      memcpy(out, "'\\''", 4);
      out += 4;
    } else {
      *out++ = *cursor;
    }
  }
  *out++ = '\'';
  *out = '\0';

  return quoted;
}

static int run_command(const char *command) {
  int status = system(command);
  return status == 0 ? 0 : -1;
}

static int split_path(const char *path, char *dir, size_t dir_size, char *base,
                      size_t base_size) {
  const char *slash = strrchr(path, '/');
  size_t len;

  if (slash == NULL) {
    if (snprintf(dir, dir_size, ".") >= (int)dir_size) {
      return -1;
    }
    if (snprintf(base, base_size, "%s", path) >= (int)base_size) {
      return -1;
    }
    return 0;
  }

  len = (size_t)(slash - path);
  if (len == 0) {
    len = 1;
  }
  if (len >= dir_size) {
    return -1;
  }
  memcpy(dir, path, len);
  dir[len] = '\0';

  if (snprintf(base, base_size, "%s", slash + 1) >= (int)base_size) {
    return -1;
  }

  return 0;
}

static int create_tar(const char *tar_path, const char *source_path) {
  char dir[PATH_MAX];
  char base[PATH_MAX];
  char *q_tar = NULL;
  char *q_dir = NULL;
  char *q_base = NULL;
  char *command = NULL;
  size_t command_len;
  int result = -1;

  if (split_path(source_path, dir, sizeof(dir), base, sizeof(base)) != 0 ||
      base[0] == '\0') {
    fprintf(stderr, "compress_helper: invalid source path\n");
    return -1;
  }

  q_tar = shell_quote(tar_path);
  q_dir = shell_quote(dir);
  q_base = shell_quote(base);
  if (q_tar == NULL || q_dir == NULL || q_base == NULL) {
    goto cleanup;
  }

  command_len = strlen("tar -cf  -C  ") + strlen(q_tar) + strlen(q_dir) +
                strlen(q_base) + 1;
  command = malloc(command_len);
  if (command == NULL) {
    goto cleanup;
  }

  snprintf(command, command_len, "tar -cf %s -C %s %s", q_tar, q_dir, q_base);
  result = run_command(command);

cleanup:
  free(q_tar);
  free(q_dir);
  free(q_base);
  free(command);
  return result;
}

static int copy_bytes(FILE *src, FILE *dst, off_t bytes) {
  char buffer[COPY_BUFFER_SIZE];

  while (bytes > 0) {
    size_t wanted = bytes > COPY_BUFFER_SIZE ? COPY_BUFFER_SIZE : (size_t)bytes;
    size_t got = fread(buffer, 1, wanted, src);

    if (got == 0) {
      return ferror(src) ? -1 : 0;
    }

    if (fwrite(buffer, 1, got, dst) != got) {
      return -1;
    }

    bytes -= (off_t)got;
  }

  return 0;
}

static int create_chunk(const char *tar_path, const char *chunk_path,
                        off_t start, off_t bytes) {
  FILE *src = fopen(tar_path, "rb");
  FILE *dst = NULL;
  int result = -1;

  if (src == NULL) {
    return -1;
  }

  if (fseeko(src, start, SEEK_SET) != 0) {
    goto cleanup;
  }

  dst = fopen(chunk_path, "wb");
  if (dst == NULL) {
    goto cleanup;
  }

  result = copy_bytes(src, dst, bytes);

cleanup:
  if (dst != NULL) {
    fclose(dst);
  }
  fclose(src);
  return result;
}

static void *compress_chunk(void *arg) {
  compress_job_t *job = (compress_job_t *)arg;
  char *q_chunk = shell_quote(job->chunk_path);
  char *q_gzip = shell_quote(job->gzip_path);
  char *command = NULL;
  size_t command_len;

  job->status = -1;

  if (q_chunk == NULL || q_gzip == NULL) {
    goto cleanup;
  }

  command_len = strlen("gzip -c  > ") + strlen(q_chunk) + strlen(q_gzip) + 1;
  command = malloc(command_len);
  if (command == NULL) {
    goto cleanup;
  }

  snprintf(command, command_len, "gzip -c %s > %s", q_chunk, q_gzip);
  job->status = run_command(command);

cleanup:
  free(q_chunk);
  free(q_gzip);
  free(command);
  return NULL;
}

static int append_file(FILE *out, const char *path) {
  FILE *in = fopen(path, "rb");
  int result;

  if (in == NULL) {
    return -1;
  }

  result = copy_bytes(in, out, LLONG_MAX);
  fclose(in);
  return result;
}

static void cleanup_temp(const char *tmp_dir, const char *tar_path) {
  if (tar_path != NULL) {
    unlink(tar_path);
  }

  if (tmp_dir != NULL) {
    /* rmdir only removes empty directories — use a recursive approach
       to handle leftover chunk files from failed threads. We validate
       the path prefix to avoid accidental recursive deletion. */
    char cmd[PATH_MAX + 32];
    if (strstr(tmp_dir, "blackbox_compress_") != NULL) {
      snprintf(cmd, sizeof(cmd), "rm -rf '%s'", tmp_dir);
      system(cmd);
    } else {
      rmdir(tmp_dir);
    }
  }
}

static int write_parallel_gzip(const char *tar_path, const char *archive_path,
                               int thread_count, const char *tmp_dir) {
  struct stat st;
  compress_job_t *jobs = NULL;
  pthread_t *threads = NULL;
  FILE *out = NULL;
  off_t size;
  int i;
  int created_threads = 0;
  int thread_failed = 0;
  int result = -1;

  if (stat(tar_path, &st) != 0) {
    return -1;
  }

  size = st.st_size;
  if (size <= 0) {
    thread_count = 1;
  } else if ((off_t)thread_count > size) {
    thread_count = (int)size;
  }

  jobs = calloc((size_t)thread_count, sizeof(*jobs));
  threads = calloc((size_t)thread_count, sizeof(*threads));
  if (jobs == NULL || threads == NULL) {
    goto cleanup;
  }

  for (i = 0; i < thread_count; i++) {
    off_t start = size * i / thread_count;
    off_t end = size * (i + 1) / thread_count;

    if (snprintf(jobs[i].chunk_path, sizeof(jobs[i].chunk_path),
                 "%s/chunk_%02d.tarpart", tmp_dir,
                 i) >= (int)sizeof(jobs[i].chunk_path)) {
      goto cleanup;
    }
    if (snprintf(jobs[i].gzip_path, sizeof(jobs[i].gzip_path),
                 "%s/chunk_%02d.gz", tmp_dir,
                 i) >= (int)sizeof(jobs[i].gzip_path)) {
      goto cleanup;
    }

    if (create_chunk(tar_path, jobs[i].chunk_path, start, end - start) != 0) {
      goto cleanup;
    }
  }

  for (i = 0; i < thread_count; i++) {
    if (pthread_create(&threads[i], NULL, compress_chunk, &jobs[i]) != 0) {
      thread_failed = 1;
      break;
    }
    created_threads++;
  }

  for (i = 0; i < created_threads; i++) {
    if (pthread_join(threads[i], NULL) != 0 || jobs[i].status != 0) {
      thread_failed = 1;
    }
  }
  if (thread_failed) {
    goto cleanup;
  }

  out = fopen(archive_path, "wb");
  if (out == NULL) {
    goto cleanup;
  }

  for (i = 0; i < thread_count; i++) {
    if (append_file(out, jobs[i].gzip_path) != 0) {
      goto cleanup;
    }
  }

  result = 0;

cleanup:
  if (out != NULL) {
    fclose(out);
  }
  if (result != 0) {
    unlink(archive_path);
  }
  if (jobs != NULL) {
    for (i = 0; i < thread_count; i++) {
      unlink(jobs[i].chunk_path);
      unlink(jobs[i].gzip_path);
    }
  }
  free(threads);
  free(jobs);
  return result;
}

static void usage(const char *program) {
  fprintf(stderr, "Usage: %s [-j threads] <archive.tar.gz> <source_path>\n",
          program);
}

int main(int argc, char **argv) {
  int thread_count = DEFAULT_THREADS;
  int arg_index = 1;
  const char *archive_path;
  const char *source_path;
  const char *tmp_root;
  char tmp_dir_template[PATH_MAX];
  char *tmp_dir;
  char tar_path[PATH_MAX];
  struct stat source_stat;
  int result = 1;

  if (argc > 1 && strcmp(argv[1], "-j") == 0) {
    if (argc < 4) {
      usage(argv[0]);
      return 2;
    }
    thread_count = atoi(argv[2]);
    arg_index = 3;
  }

  if (argc - arg_index != 2) {
    usage(argv[0]);
    return 2;
  }

  if (thread_count < 1) {
    thread_count = 1;
  } else if (thread_count > MAX_THREADS) {
    thread_count = MAX_THREADS;
  }

  archive_path = argv[arg_index];
  source_path = argv[arg_index + 1];

  if (stat(source_path, &source_stat) != 0) {
    fprintf(stderr, "compress_helper: source not found: %s\n", source_path);
    return 2;
  }
  if (!S_ISREG(source_stat.st_mode) && !S_ISDIR(source_stat.st_mode)) {
    fprintf(stderr,
            "compress_helper: source must be a regular file or directory\n");
    return 2;
  }

  tmp_root = getenv("TMPDIR");
  if (tmp_root == NULL || tmp_root[0] == '\0') {
    tmp_root = "/tmp";
  }

  if (snprintf(tmp_dir_template, sizeof(tmp_dir_template),
               "%s/blackbox_compress_%ld_XXXXXX", tmp_root,
               (long)getpid()) >= (int)sizeof(tmp_dir_template)) {
    fprintf(stderr, "compress_helper: temporary path is too long\n");
    return 2;
  }

  tmp_dir = mkdtemp(tmp_dir_template);
  if (tmp_dir == NULL) {
    fprintf(stderr, "compress_helper: mkdtemp failed: %s\n", strerror(errno));
    return 2;
  }

  if (snprintf(tar_path, sizeof(tar_path), "%s/payload.tar", tmp_dir) >=
      (int)sizeof(tar_path)) {
    fprintf(stderr, "compress_helper: tar path is too long\n");
    cleanup_temp(tmp_dir, NULL);
    return 2;
  }

  printf("[compress_helper] source=%s archive=%s threads=%d\n", source_path,
         archive_path, thread_count);

  if (create_tar(tar_path, source_path) != 0) {
    fprintf(stderr, "compress_helper: tar creation failed\n");
    goto cleanup;
  }

  if (write_parallel_gzip(tar_path, archive_path, thread_count, tmp_dir) != 0) {
    fprintf(stderr, "compress_helper: parallel compression failed\n");
    goto cleanup;
  }

  result = 0;

cleanup:
  cleanup_temp(tmp_dir, tar_path);
  return result;
}
