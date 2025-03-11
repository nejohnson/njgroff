/* Copyright (C) 1989-2025 Free Software Foundation, Inc.
     Written by James Clark (jjc@jclark.com)

This file is part of groff.

groff is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or
(at your option) any later version.

groff is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <stdlib.h>

#include <getopt.h> // getopt_long()

#include "lib.h"

#include "errarg.h"
#include "error.h"
#include "stringclass.h"
#include "nonposix.h"
#include "searchpath.h"
#include "lf.h"

// The include search path initially contains only the current directory.
static search_path include_search_path(0, 0, 0, 1);

bool want_att_compat = false;
bool want_raw_output = false;
bool want_tex_output = false;

extern "C" const char *Version_string;

int do_file(const char *, int, int);

enum {
  START_LINENO = 1,
  END_LINENO   = INT_MAX
};

void usage(FILE *stream)
{
  fprintf(stream, "usage: %s [-Crt] [-I dir] [input-file ...]\n"
	  "usage: %s {-v | --version}\n"
	  "usage: %s --help\n",
	  program_name, program_name, program_name);
  if (stdout == stream)
    fputs("\n"
"GNU soelim eliminates source requests in roff(7) and other text\n"
"files; it replaces lines of the form \".so included‐file\" within\n"
"each text input-file with the contents of included-file recursively,\n"
"flattening a tree of documents.  By default, it writes roff \"lf\"\n"
"requests as well to record the name and line number of each\n"
"input-file and included-file.  Use the -t option to produce TeX\n"
"comments instead of roff requests.  Use the -r option to write\n"
"neither.  See the soelim(1) manual page.\n"
"(neilj version)\n",
	  stream);
}

int main(int argc, char **argv)
{
  program_name = argv[0];
  int opt;
  static const struct option long_options[] = {
    { "help", no_argument, 0, CHAR_MAX + 1 },
    { "version", no_argument, 0, 'v' },
    { NULL, 0, 0, 0 }
  };
  while ((opt = getopt_long(argc, argv, ":CI:rtv", long_options, NULL))
	 != EOF)
    switch (opt) {
    case 'v':
      printf("GNU soelim (groff) version %s\n", Version_string);
      exit(EXIT_SUCCESS);
      break;
    case 'C':
      want_att_compat = true;
      break;
    case 'I':
      include_search_path.command_line_dir(optarg);
      break;
    case 'r':
      want_raw_output = true;
      break;
    case 't':
      want_tex_output = true;
      break;
    case CHAR_MAX + 1: // --help
      usage(stdout);
      exit(EXIT_SUCCESS);
      break;
    case '?':
      error("unrecognized command-line option '%1'", char(optopt));
      usage(stderr);
      exit(2);
      break;
    case ':':
      error("command-line option '%1' requires an argument",
           char(optopt));
      usage(stderr);
      exit(2);
      break;
    default:
      assert(0 == "unhandled getopt_long return value");
    }
  int nbad = 0;
  if (optind >= argc)
    nbad += !do_file("-", START_LINENO, END_LINENO);
  else
    for (int i = optind; i < argc; i++)
      nbad += !do_file(argv[i], START_LINENO, END_LINENO);
  if (ferror(stdout))
    fatal("error status on standard output stream");
  if (fflush(stdout) < 0)
    fatal("cannot flush standard output stream: %1", strerror(errno));
  return (nbad != 0);
}

void set_location()
{
  if (!want_raw_output) {
    if (!want_tex_output)
      printf(".lf %d %s%s\n", current_lineno,
	('"' == current_filename[0]) ? "" : "\"", current_filename);
    else
      // XXX: Should we quote the file name?  What's TeX-conventional?
      printf("%% file %s, line %d\n", current_filename, current_lineno);
  }
}

void get_line_range(FILE *fp, int *start_lineno, int *end_lineno)
{
  int s = 0, e = 0;
  char c = getc(fp);
  enum { START, END, SKIPPING } state = START;
  int ok = 0;
  int is_relative = 0;
  for (; c != ']' && c != EOF && c != '\n'; c = getc(fp)) {
    switch (state) {
case START:
      if (isdigit(c))
        s = (s * 10) + c - '0';
      else if (c == '-')
        state = END;
      else if (c == '+') {
        state = END;
	is_relative = 1;
      }
      else
        state = SKIPPING;
      break;
case END:
      if (isdigit(c))
        e = (e * 10) + c - '0';
      else
        state = SKIPPING;
      break;
case SKIPPING:
      break;
default:
      assert(0 == "unhandled state in line range parser");
    }
  }
  if (state == START && s > 0 && e == 0) {
    e = s;
    ok = 1;
  }
  else if (state == END) {
    if (s == 0) s = START_LINENO;
    if (is_relative) {
      if (e == 0) e = 1;
      e += s;
    } else if (e == 0) e = END_LINENO;
    ok = 1;
  }
  if (state == SKIPPING || s > e) {
    error("Bad line range spec, skipping...");
    s = START_LINENO;
    e = END_LINENO;
  }
  *start_lineno = s;
  *end_lineno = e;
}

void do_so(const char *line, int start_lineno, int end_lineno)
{
  const char *p = line;
  while (*p == ' ')
    p++;
  string filename;
  bool is_filename_valid = true;
  const char *q = p;
  if ('"' == *q)
    q++;
  for (; is_filename_valid && (*q != '\0') && (*q != '\n'); q++)
    if (*q == '\\') {
      switch (*++q) {
      case 'e':
      case '\\':
	filename += '\\';
	break;
      case ' ':
	filename += ' ';
	break;
      default:
	is_filename_valid = false;
	break;
      }
    }
    else
      filename += char(*q);
  if (is_filename_valid && (filename.length() > 0)) {
    filename += '\0';
    const char *fn = current_filename;
    int ln = current_lineno;
    current_lineno--;
    if (do_file(filename.contents(), start_lineno, end_lineno)) {
      current_filename = fn;
      current_lineno = ln;
      set_location();
      return;
    }
    current_lineno++;
  }
  fputs(".so", stdout);
  fputs(line, stdout);
}

int do_file(const char *filename, int start_lineno, int end_lineno)
{
  char *file_name_in_path = 0;
  FILE *fp = include_search_path.open_file_cautious(filename,
						    &file_name_in_path);
  int err = errno;
  string whole_filename(filename);
  if (strcmp(filename, "-") && file_name_in_path != 0 /* nullptr */)
    whole_filename = file_name_in_path;
  whole_filename += '\0';
  free(file_name_in_path);
  if (fp == 0) {
    error("cannot open '%1': %2", whole_filename.contents(),
	  strerror(err));
    return 0;
  }
  normalize_for_lf(whole_filename);
  current_filename = whole_filename.contents();
  current_lineno = 1;
  while (current_lineno < start_lineno) {
    int c = getc(fp);
    if (c == EOF)
      break;
    if (c == '\n')
      current_lineno++;
  }
  set_location();
  enum { START, MIDDLE, HAD_DOT, HAD_s, HAD_so, HAD_l, HAD_lf } state = START;
  for (;;) {
    int c = getc(fp);
    if (c == EOF)
      break;
    if (current_lineno > end_lineno)
      break;
    switch (state) {
    case START:
      if (c == '.')
	state = HAD_DOT;
      else {
	putchar(c);
	if (c == '\n') {
	  current_lineno++;
	  state = START;
	}
	else
	  state = MIDDLE;
      }
      break;
    case MIDDLE:
      putchar(c);
      if (c == '\n') {
	current_lineno++;
	state = START;
      }
      break;
    case HAD_DOT:
      if (c == 's')
	state = HAD_s;
      else if (c == 'l')
	state = HAD_l;
      else {
	putchar('.');
	putchar(c);
	if (c == '\n') {
	  current_lineno++;
	  state = START;
	}
	else
	  state = MIDDLE;
      }
      break;
    case HAD_s:
      if (c == 'o')
	state = HAD_so;
      else  {
	putchar('.');
	putchar('s');
	putchar(c);
	if (c == '\n') {
	  current_lineno++;
	  state = START;
	}
	else
	  state = MIDDLE;
      }
      break;
    case HAD_so:
      if (c == ' ' || c == '\n' || c == '[' || want_att_compat) {
	string line;
	int s = START_LINENO;
	int e = END_LINENO;
	if (c == '[') {
	  get_line_range(fp, &s, &e);
	  c = getc(fp);
	}
	for (; c != EOF && c != '\n'; c = getc(fp))
	  line += c;
	current_lineno++;
	line += '\n';
	line += '\0';
	do_so(line.contents(), s, e);
	state = START;
      }
      else {
	fputs(".so", stdout);
	putchar(c);
	state = MIDDLE;
      }
      break;
    case HAD_l:
      if (c == 'f')
	state = HAD_lf;
      else {
	putchar('.');
	putchar('l');
	putchar(c);
	if (c == '\n') {
	  current_lineno++;
	  state = START;
	}
	else
	  state = MIDDLE;
      }
      break;
    case HAD_lf:
      if (c == ' ' || c == '\n' || want_att_compat) {
	string line;
	for (; c != EOF && c != '\n'; c = getc(fp))
	  line += c;
	current_lineno++;
	line += '\n';
	line += '\0';
	interpret_lf_args(line.contents());
	printf(".lf%s", line.contents());
	state = START;
      }
      else {
	fputs(".lf", stdout);
	putchar(c);
	state = MIDDLE;
      }
      break;
    default:
      assert(0 == "unhandled state in file parser");
    }
  }
  switch (state) {
  case HAD_DOT:
    fputs(".\n", stdout);
    break;
  case HAD_l:
    fputs(".l\n", stdout);
    break;
  case HAD_s:
    fputs(".s\n", stdout);
    break;
  case HAD_lf:
    fputs(".lf\n", stdout);
    break;
  case HAD_so:
    fputs(".so\n", stdout);
    break;
  case MIDDLE:
    putc('\n', stdout);
    break;
  case START:
    break;
  }
  if (fp != stdin)
    if (fclose(fp) < 0)
      fatal("cannot close '%1': %2", whole_filename.contents(),
	    strerror(errno));
  current_filename = 0 /* nullptr */;
  return 1;
}

// Local Variables:
// fill-column: 72
// mode: C++
// End:
// vim: set cindent noexpandtab shiftwidth=2 textwidth=72:
