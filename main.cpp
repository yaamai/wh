#include <sys/poll.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <dirent.h>
#include <stdlib.h>
#include <string>

/*
 * # wormhole consume stdin and output nothing
 * $ echo a | wh
 * <empty>
 *
 * # wormhole can named
 * $ echo foo | wh foo
 * $ echo bar | wh bar
 * $ wh foo
 * foo
 *
 * # noname wormhole is default
 * $ wh
 * a
 *
 * # like stack, noname wormhole can pop (output and delete)
 * $ wh -p
 * a
 *
 * $ wh
 * <empty>
 */

const char* BASE_PATH = "/var/tmp";
const char* NONAME_WH_FORMAT = "wh-%d";
const char* NAMED_WH_FORMAT = "wh-%s";
const char* PATH_PATTERN = "/var/tmp/%s";
const size_t BUF_SIZE = 4096;
const size_t FILE_PATH_MAX = 256;

bool has_stdin_data() {
	return !isatty(STDIN_FILENO);
        struct pollfd fds;
        fds.fd = 0;
        fds.events = POLLIN;

        int ret = poll(&fds, 1, 0);
        if(ret == 1)
		return true;
        else if(ret == 0)
		return false;

	return false;
}

// 0: not found, 1>: last number
int get_last_noname_wormhole() {
	auto last_num = 0;
	DIR *d;
	struct dirent *dir;
	d = opendir(BASE_PATH);
	if (d) {
		while ((dir = readdir(d)) != NULL) {
			if (strncmp("wh-", dir->d_name, 3) == 0) {
				auto num = atoi(dir->d_name+3);
				if (num != 0 && num > last_num) {
					last_num = num;
				}
			}
		}
		closedir(d);
	}
	return last_num;
}

int get_next_noname_wormhole() {
	return get_last_noname_wormhole() + 1;
}

std::string get_filepath(const char* name, bool next) {
	char filename[FILE_PATH_MAX];
	if (name == NULL) {
		auto num = 0;
		if (next) {
			num = get_next_noname_wormhole();
		} else {
			num = get_last_noname_wormhole();
		}
		snprintf(filename, FILE_PATH_MAX, NONAME_WH_FORMAT, num);
	} else {
		snprintf(filename, FILE_PATH_MAX, NAMED_WH_FORMAT, name);
	}

	char filepath[FILE_PATH_MAX];
	snprintf(filepath, FILE_PATH_MAX, PATH_PATTERN, filename);

	return filepath;
}


void create_wormhole(const char* name) {
	auto filepath = get_filepath(name, true);
	FILE* fp = fopen(filepath.c_str(), "wb");
	if (fp == NULL) {
		return;
	}

	char buf[BUF_SIZE];
	size_t len = 0;
	while ((len = read(STDIN_FILENO, &buf, BUF_SIZE)) > 0) {
		fwrite(buf, len, 1, fp);
	}
}

void read_wormhole(const char* name) {
	auto filepath = get_filepath(name, false);
	FILE* fp = fopen(filepath.c_str(), "rb");
	if (fp == NULL) {
		return;
	}

	char buf[BUF_SIZE];
	size_t len = 0;
	while ((len = fread(&buf, 1, BUF_SIZE, fp)) > 0) {
		write(STDOUT_FILENO, &buf, len);
	}
	fflush(NULL);
}

void pop_wormhole() {
	auto filepath = get_filepath(NULL, false);
	remove(filepath.c_str());
}

bool parse_opt_pop(int argn, char** args) {
	return argn>1 && args[1] && strcmp("-p", args[1]) == 0;
}

const char* parse_opt_name(int argn, char** args) {
	if (argn>1 && args[1] && strcmp("-p", args[1]) != 0)
		return args[1];
	return NULL;
}

int main(int argn, char** args) {
	auto do_pop = parse_opt_pop(argn, args);
	auto name = parse_opt_name(argn, args);

	if (has_stdin_data()) {
		create_wormhole(name);
	} else {
		read_wormhole(name);
		if (do_pop) {
			pop_wormhole();
		}
	}
}
