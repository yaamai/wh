import os
import strconv

#include <unistd.h>
#include <dirent.h>
#include <stdio.h>
struct C.dirent {
pub:
	d_name byteptr
}

fn C.read(arg_1 int, arg_2 voidptr, arg_3 int) int

fn C.write(arg_1 int, arg_2 voidptr, arg_3 int) int

fn parse_opt(args []string) (bool, string) {
	if args.len <= 1 {
		return false, ''
	}
	mut do_pop := false
	if args[1] == '-p' {
		do_pop = true
	}
	mut name := ''
	if args[1] != '-p' {
		name = args[1]
	}
	return do_pop, name
}

fn has_stdin_data() bool {
	// == 1 is tty
	return C.isatty(C.STDIN_FILENO) != 1
}

const (
	base_path        = '/var/tmp'
	filename_pattern = 'wh-'
	buf_size         = 4096
)

fn get_last_noname_wormhole() int {
	mut last_num := 0
	dir := C.opendir(base_path.str)
	if isnil(dir) {
		return 0
	}
	mut ent := &C.dirent(0)
	for {
		ent = C.readdir(dir)
		if isnil(ent) {
			break
		}
		path := tos_clone(byteptr(ent.d_name))
		if path.len < 3 {
			continue
		}
		if path[0..3] != 'wh-' {
			continue
		}
		num := strconv.atoi(path[3..])
		if num != 0 && num > last_num {
			last_num = num
		}
	}
	C.closedir(dir)
	return last_num
}

fn get_next_noname_wormhole() int {
	return get_last_noname_wormhole() + 1
}

fn get_filepath(name string, next bool) string {
	// get noname wormhole
	mut filename := ''
	if name == '' {
		mut num := 0
		if next {
			num = get_next_noname_wormhole()
		} else {
			num = get_last_noname_wormhole()
		}
		filename = filename_pattern + num.str()
	} else {
		filename = filename_pattern + name
	}
	return base_path + '/' + filename
}

fn create_wormhole(name string) {
	filepath := get_filepath(name, true)
	fp := os.vfopen(filepath, 'wb')
	if fp == 0 {
		return
	}
	mut buf := [`0`].repeat(buf_size)
	for {
		len := C.read(C.STDIN_FILENO, buf.data, buf_size)
		if len <= 0 {
			break
		}
		C.fwrite(buf.data, len, 1, fp)
	}
	C.fclose(fp)
}

fn read_wormhole(name string) {
	filepath := get_filepath(name, false)
	fp := os.vfopen(filepath, 'rb')
	if fp == 0 {
		return
	}
	mut buf := [`0`].repeat(buf_size)
	for {
		len := C.fread(buf.data, 1, buf_size, fp)
		if len <= 0 {
			break
		}
		C.write(C.STDOUT_FILENO, buf.data, len)
	}
	C.fclose(fp)
}

fn pop_wormhole() {
	filepath := get_filepath('', false)
	C.remove(filepath.str)
}

fn main() {
	do_pop, name := parse_opt(os.args)
	if has_stdin_data() {
		create_wormhole(name)
	} else {
		read_wormhole(name)
		if do_pop {
			pop_wormhole()
		}
	}
}
