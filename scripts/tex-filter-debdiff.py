#! /usr/bin/env python
#
# tex-filter-debdiff.py --- Filter debdiff output in a way that is useful to
#                           the Debian TeX maintainers.
#
# Copyright (c) 2007 Florent Rougon
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 dated June, 1991.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING. If not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301 USA.
#

import sys, os, re, getopt

# ****************************************************************************
# *                        Customization starts here                         *
# ****************************************************************************

# The filtering for files which differ only in the last directory component
# will only be done for those whose full path (as reported in the debdiff
# output) matches one of the regular expressions in 'filter_in_regexes'.
#
# Note: "^/usr/share/doc/texlive" matches /usr/share/doc/texlive-lang-french
#       and many others...
filter_in_regexes = [r"^/usr/share/texlive/texmf",
		     r"^/usr/share/texlive/texmf-dist",
                     r"^/usr/share/doc/texlive"]

# "Configuration files", for the purpose of locating which of them were moved
# between the two .deb files, are defined as those whose full path matches one
# of the regular expressions in 'config_files_regexes'.
config_files_regexes = [r"^/etc/texmf"]

# Regular expressions matching the "interesting" sections (those that will
# be filtered).
first_deb_sec_rec = re.compile(r"^Files in first \.deb but not in second$")
second_deb_sec_rec = re.compile(r"^Files in second \.deb but not in first$")

# ****************************************************************************
# *                         Customization ends here                          *
# ****************************************************************************

filter_in_reclist = map(re.compile, filter_in_regexes)
config_files_reclist = map(re.compile, config_files_regexes)


progname = os.path.basename(sys.argv[0])
progversion_base = "0.2"

# Append an SVN revision part to the program version
svn_revision_string = "$LastChangedRevision$"
svn_revision_rec = re.compile(r"^\$LastChangedRevision: ([0-9]+) \$$")
svn_revision_mo = svn_revision_rec.match(svn_revision_string)

if svn_revision_mo is not None:
    svn_revision = svn_revision_mo.group(1)
else:
    svn_revision = "unknown.svn.revision"

del svn_revision_string, svn_revision_rec, svn_revision_mo
progversion = "%s.%s" % (progversion_base, svn_revision)


usage = """Usage: %(progname)s [option ...]
Filter debdiff output in a way that is useful to the Debian TeX maintainers.

The debdiff output is expected on the standard input. It will be
processed and the result will go to the standard output.

Options:
      --algorithm              explain the algorithm used
      --help                   display this message and exit
      --version                output version information and exit""" \
  % {"progname": progname}


class error(Exception):
    pass

class ParseError(error):
    pass

class ProgramError(error):
    "Exception raised for obvious bugs (when an assertion is false)."


def split_input_into_sections(f):
    sections = []
    # How sections are underlined in the input
    sec_delim = re.compile(r"^-+$")

    section_number = 1

    while True:
        section = {"name": None,
                   "lines": []}
        # Will store the previous line (needed to remember section titles)
        prev_line = None

        # Line number within a section
        line_num = 1
        while True:
            line = f.readline()
            if line in ('', '\n'):
                break

            mo = sec_delim.match(line)
            # Section delimiters are only considered as such iff found on
            # the second line of a section.
            if mo and (line_num == 2):
                if prev_line is None:
                    raise ParseError(
                        "Section %u, line %u (within the section): section "
                        "delimiter not preceded by a section title",
                        section_number, line_num)
                
                # The section title will be stored in section["name"];
                # therefore, remove it from section["lines"], i.e., start over
                # since we are on the second line.
                section["lines"] = []
                # Strip the trailing newline before storing the section title
                section["name"] = prev_line[:-1]
                # Store the section delimiter, in order to reproduce the
                # debdiff output verbatim.
                section["title delimiter"] = mo.group(0)
            else:
                # Strip the trailing newline before storing the line
                section["lines"].append(line[:-1])

            prev_line = line
            line_num += 1

        sections.append(section)
        if line == '':                  # EOF
            break
        section_number += 1

    return sections


def locate_interesting_sections(sections):
    first_deb_sec, second_deb_sec = None, None

    for section in sections:
        if section["name"] is not None:
            if first_deb_sec_rec.match(section["name"]):
                first_deb_sec = section
            elif second_deb_sec_rec.match(section["name"]):
                second_deb_sec = section

    return first_deb_sec, second_deb_sec
            

def index_files(section):
    """Build a dictionary whose keys are the file basenames.

    This allows to easily find everything pertaining to a file given his
    basename.

    The dictionary will be accessible as section["files"]. For a given
    basename (a string), section["files"][basename] will yield the list of
    entries having this basename in 'section'.

    Another object is added to 'section': after this function returns,
    section["ordered list"] can be used to obtain the list of file entries
    for 'section', in the same order as they appear in the debdiff output.

    """
    if not section.has_key("files"):
        section["files"] = {}
    if not section.has_key("ordered list"):
        # We are going to store in section["ordered list"] a list made of
        # the file entries for every file in section["lines"], in the same
        # order as they appear in section["lines"]. This will be quite useful
        # in dump_filtered_section() to preserve the order of files in the
        # debdiff output.
        section["ordered list"] = []

    d = section["files"]                # 'd' for dictionary

    # The point of having the "sep_after_mode", "sep_after_owner_and_group"
    # and "symlink_arrow" groups is to recreate exactly the debdiff output
    # for each entry (in particular, use the same number of spaces/tabs
    # that were used by debdiff between the various fields).
    nonsymlink_line_rec = re.compile(
        r"^(?P<mode>[^l][^ \t]+)(?P<sep_after_mode>[ \t]+)"
        r"(?P<owner_and_group>[^ \t]+)(?P<sep_after_owner_and_group>[ \t]+)"
        r"(?P<path>.+?)$")
    symlink_line_rec = re.compile(
        r"^(?P<mode>l[^ \t]+)(?P<sep_after_mode>[ \t]+)"
        r"(?P<owner_and_group>[^ \t]+)(?P<sep_after_owner_and_group>[ \t]+)"
        r"(?P<link>.+?)(?P<symlink_arrow> -> )(?P<target>.+)$")

    for line in section["lines"]:
        if line.startswith("l"):
            mo = symlink_line_rec.match(line)
            if not mo:
                raise ParseError(
                    "Looks like a line for a symlink, but doesn't match the "
                    "corresponding regexp:\n\n  '%s'" % line)

            name = os.path.basename(mo.group("link"))
            if not d.has_key(name):
                # First time we find a file with basename 'name' -> create
                # a new entry for it.
                d[name] = []

            entry = \
                  {"name": name,
                   "type": "symlink",
                   "dirname": os.path.dirname(mo.group("link")),
                   "mode": mo.group("mode"),
                   "owner and group": mo.group("owner_and_group"),
                   "target": mo.group("target"),
                   "separator after mode": mo.group("sep_after_mode"),
                   "separator after owner and group":
                   mo.group("sep_after_owner_and_group"),
                   "symlink arrow": mo.group("symlink_arrow")}
        else:
            mo = nonsymlink_line_rec.match(line)
            if not mo:
                raise ParseError(
                    "Looks like a line for a file that is not a symlink, but "
                    "doesn't match the corresponding regexp:\n\n  '%s'" % line)

            name = os.path.basename(mo.group("path"))
            if not d.has_key(name):
                # First time we find a file with basename 'name' -> create
                # a new entry for it.
                d[name] = []

            entry = \
                  {"name": name,
                   "type": "not a symlink",
                   "dirname": os.path.dirname(mo.group("path")),
                   "mode": mo.group("mode"),
                   "owner and group": mo.group("owner_and_group"),
                   "separator after mode": mo.group("sep_after_mode"),
                   "separator after owner and group":
                   mo.group("sep_after_owner_and_group")}

        # Record all this precious data...
        # ... first, in section["files"][name]:
        d[name].append(entry)
        # and second, append a pointer to the file entry to
        # section["ordered list"], which will allow us to reproduce
        # debdiff's output correctly, preserving the order:
        section["ordered list"].append(entry)


def build_dir_list_for_file(name, section):
    """Compute the list of directories for a given file basename in a section.

    Return the list of directories where a file with basename 'name' is
    shipped in section 'section'.

    """
    res = []

    if section["files"].has_key(name):
        for entry in section["files"][name]:
            res.append(entry["dirname"])

    return res

def extract_moved_cfg_file(name, moved_cfg_files, sec, other_sec):
    """Extract a configuration file that was moved between the two .deb files.

    See the docstring for extract_moved_cfg_files() for details.

    """
    if moved_cfg_files.has_key(name):
        raise ProgramError(
            "'%s' is already present in moved_cfg_files. All its occurrences "
            "should have been removed from sec['ordered list'] and "
            "other_sec['ordered list'] at the time it was introduced into "
            "moved_cfg_files. Therefore, we shouldn't be trying to extract "
            "it here." % name)

    dirs_in_this_section = build_dir_list_for_file(name, sec)
    dirs_in_other_section = build_dir_list_for_file(name, other_sec)

    dirs_in_this_section.sort()
    dirs_in_other_section.sort()

    if dirs_in_this_section != dirs_in_other_section:
        # We'll store in moved_cfg_files[name] all entries for files with
        # 'name' as the basename; and this, for each of the two interesting
        # sections. This will allow us to list the various locations where a
        # given file can be found (under /etc/texmf, under
        # /usr/share/texmf-texlive, etc.).
        #
        # Note: we could make moved_cfg_files[name] a tuple with a
        # well-defined order such as (first_deb, second_deb) in order to save
        # some memory...
        moved_cfg_files[name] = {sec["name"]:
                                 sec["files"][name],
                                 other_sec["name"]:
                                 other_sec["files"][name]}

        # Remove the corresponding entries from sec["ordered list"] and
        # other_sec["ordered list"]. This will make them disappear from the
        # debdiff output (which is OK, since they are listed in a separate
        # section, appended to the filtered debdiff output).
        for section in (sec, other_sec):
            for entry in section["files"][name]:
                section["ordered list"].remove(entry)


def extract_moved_cfg_files(moved_cfg_files, sec, other_sec,
                            config_files_reclist):
    """Extract moved configuration files.

    INPUT:            config_files_reclist
    OUTPUT:           moved_cfg_files (modified in-place)
    INPUT AND OUTPUT: sec, other_sec (modified in-place)

    Examine each entry in section 'sec' and extract the corresponding file
    from the debdiff output if it fulfills the following conditions:

      (1) There must be in section 'sec' an entry for the file whose full path
          (dirname + basename) matches at least one of the compiled regular
          expressions in 'config_files_reclist', and

      (2) The file must be found somewhere in the other section, 'other_sec'
          (possibly with no path there matching a regular expression from
          'config_files_reclist'), and

      (3) The set of directories in which the file can be found in 'sec' and
          in 'other_sec' must differ in some way (which is how
          "the file was moved" is defined).

    For every such file:

      1. The list of corresponding entries in 'sec' and in 'other_sec' is
         stored in 'moved_cfg_files'. This will allow list_moved_cfg_files()
         to precisely display the state of the file in each .deb (directories
         where it is found, permissions, etc.).

      2. Every entry for the file is removed from both 'sec["ordered list"]'
         and 'other_sec["ordered list"]'.

         This has two effects. First, all these entries will be filtered out
         from the usual debdiff output (which is OK, since they will appear in
         a separate section later, appended to the filtered debdiff output).
         Second, this prevents attempts to extract the same file several
         times (because it's found under different paths, for instance).

    """
    # Make a copy of names and dirnames from 'sec["ordered list"]'.
    # This is important, because we're going to remove elements from
    # 'sec["ordered list"]' in the following loop. Therefore, a simple
    #
    #   for entry in sec["ordered list"]:
    #       name, dirname = (entry["name"], entry["dirname"])
    #
    #       [...]
    #
    # would skip some entries due to the deleted elements...
    l = [ (entry["name"], entry["dirname"]) for entry in sec["ordered list"] ]

    for name, dirname in l:
        full_path = os.path.join(dirname, name)

        for regexp in config_files_reclist:
            if regexp.match(full_path):
                # If the file cannot be found in the other section, perform no
                # special treatment: list it as debdiff would.
                if not other_sec["files"].has_key(name):
                    break

                # This may remove an element from sec["ordered list"], hence
                # the need to make a list of the (name, dirname) pairs
                # in sec["ordered list"] before entering the outer loop.
                extract_moved_cfg_file(name, moved_cfg_files, sec, other_sec)
                # full_path might match several regexps in
                # config_files_reclist, and running extract_moved_cfg_file
                # several times for the same file wouldn't be a good idea.
                # Therefore we break out of the loop after the first match.
                break


def write_section_title(output, section):
    if section["name"] is not None:
        output.write("%s\n%s\n" % (section["name"],
                                   section["title delimiter"]))


def dump_unfiltered_section(output, section):
    """Dump a section verbatim."""
    # Section title, if any
    write_section_title(output, section)

    # Section contents
    for line in section["lines"]:
        output.write("%s\n" % line)


def dirnames_are_equivalent(dirname1, dirname2):
    """Tell whether two dirnames are to be considered equivalent by dump_filtered_section().

    Current implementation: two dirnames are considered equivalent if, and
    only if, they are equal or only differ in the last component.
    
    """
    return (os.path.dirname(dirname1) == os.path.dirname(dirname2))


def file_entry(entry):
    """Build the line (string) for a file entry."""
    line = []
    for component in ("mode", "separator after mode", "owner and group",
                      "separator after owner and group"):
        line.append(entry[component])

    full_path = os.path.join(entry["dirname"], entry["name"])

    if entry["type"] == "symlink":
        line.append(full_path)
        for component in ("symlink arrow", "target"):
            line.append(entry[component])
    elif entry["type"] == "not a symlink":
        line.append(full_path)
    else:
        raise ProgramError(
            "Unexpected entry type '%s' for '%s' in section '%s'." %
            (entry["type"], full_path, section["name"]))

    return ''.join(line)


def dump_filtered_section(output, sec, other_sec, filter_in_reclist=None):
    """Dump section 'sec' in a filtered way, depending on 'other_sec'.

    The algorithm used for the filtering is the following one:

    For every file entry in 'sec':
      if:

        (1) either 'filter_in_reclist' is None, or the full path of the entry
            (dirname + basename) matches at least one of the compiled regular
            expressions in 'filter_in_reclist', and

        (2) there is a corresponding entry in 'other_sec' with the same file
            basename, and

        (3) the dirnames of these two entries are considered equivalent by
            dirnames_are_equivalent() and

        (4) both entries have the same mode, owner and group

        then:
          do nothing

        else:
          print the file entry unmodified.

    Notes:

      (a) The condition (1), when 'filter_in_reclist' is not None, ensures
          that we don't filter out changes that ought to be noticed (e.g., for
          TeX Live, we typically want to filter out those files which fulfill
          the other conditions only if they appear under
          /usr/share/texmf-texlive/ or /usr/share/doc/texlive*, but not under
          /usr/lib/!).

      (b) 'sec' and 'other_sec' typically correspond to those parts of
          debdiff's output labeled "Files in first .deb but not in second"
          and "Files in second .deb but not in first".

    """
    # Section title, if any
    write_section_title(output, sec)

    # Section contents
    for entry in sec["ordered list"]:
        name, dirname = (entry["name"], entry["dirname"])
        full_path = os.path.join(dirname, name)

        passes_through_regexp_filter = False

        if filter_in_reclist is None:
            passes_through_regexp_filter = True
        else:
            for regexp in filter_in_reclist:
                if regexp.match(full_path):
                    passes_through_regexp_filter = True
                    break

        filtered_out = False

        if passes_through_regexp_filter:
            if other_sec["files"].has_key(name):
                for other in other_sec["files"][name]:
                    # Note: if both entries ('entry' and 'other') have the
                    # same mode, then they are necessarily of the same type
                    # (symlink / not symlink). Therefore, it is useless to
                    # compare the types, since we already compare the modes.
                    if dirnames_are_equivalent(dirname, other["dirname"]) \
                           and (entry["mode"] == other["mode"]) \
                           and (entry["owner and group"] \
                                == other["owner and group"]):
                        filtered_out = True
                        break

        if not filtered_out:
            output.write(file_entry(entry) + '\n')


def short_section_name(section_name):
    if first_deb_sec_rec.match(section_name):
        res = "First .deb"
    elif second_deb_sec_rec.match(section_name):
        res = "Second .deb"
    else:
        raise ProgramError("Unexpected section name here...")

    return res


def flush_chunk(chunks, lines):
    """Terminate all elements of 'lines' with a newline, concatenate them,
    append the resulting string to 'chunks' and make 'lines' the empty list.

    """
    lines.append('')
    chunks.append('\n'.join(lines))
    # Turn 'lines' into the empty list (in-place modification)
    del lines[:]


def append_indented_line(string, lines, indentation):
    lines.append((' ' * indentation) + string)


def list_moved_cfg_files(output, sections, moved_cfg_files):
    """List the configuration files that were moved between the two .deb files."""
    # We want to preserve the order of sections (first deb then second
    # deb, or second deb then first deb) from the debdiff output.
    ordered_sec_names = []

    for section in sections:
        if (section["name"] is not None) and \
               (first_deb_sec_rec.match(section["name"]) or \
                second_deb_sec_rec.match(section["name"])):
            ordered_sec_names.append(section["name"])

    # Chunks of text. They will be join()ed in the end, with a blank line
    # inserted between two consecutive chunks.
    chunks = ['']
    # This list aggregates the lines for the current chunk, until we call
    # flush_chunk(), which adds the current chunk to 'chunks' and resets
    # 'lines' to the empty list.
    lines = []
    title = "Moved configuration files [computed by %s]" % progname
    lines.append(title)
    lines.append('-' * len(title))

    indentation = 0
    for name, data in moved_cfg_files.iteritems():
        flush_chunk(chunks, lines)

        lines.append(name)
        indentation += 2

        # Iterate over the two sections
        print_section_separator = False
        for sec_name in ordered_sec_names:
            if print_section_separator:
                flush_chunk(chunks, lines)
            else:
                print_section_separator = True

            append_indented_line(short_section_name(sec_name),
                                 lines, indentation)
            indentation += 2

            for entry in data[sec_name]:
                append_indented_line(file_entry(entry), lines, indentation)

            indentation -= 2

        indentation -= 2

    flush_chunk(chunks, lines)
    output.write('\n'.join(chunks))


algorithm_doc = """\
1. Splitting the input into sections
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
First, the debdiff output is read from the standard input
and split into "sections", where sections are the chunks of text in the
debdiff output that are separated by a blank line.

Here is an sample debdiff output (indented by two spaces, and with some
parts elided):

  [The following lists of changes regard files as different if they have
  different names, permissions or owners.]

  Files in second .deb but not in first
  -------------------------------------
  -rw-r--r--  root/root   /etc/texmf/dvipdfm/dvipdfm.cfg
  -rw-r--r--  root/root   /etc/texmf/dvips/config/alt-rule.pro
  [...]

  Files in first .deb but not in second
  -------------------------------------
  -rw-r--r--  root/root   /etc/texmf/texlive/dvipdfm.cfg
  -rw-r--r--  root/root   /etc/texmf/texlive/dvips/alt-rule.pro
  [...]

  Control files: lines which differ (wdiff format)
  ------------------------------------------------
  Version: [-2005.dfsg.2-11-] {+2007-1~2+}
  Depends: ed, mime-support, libc6 (>= 2.3.6-6), libncurses5 (>= 5.4-5)
  [...]
  
In this example, there are 4 sections. The first one is quite uninteresting
and has no name. The other three sections all have a name (underlined), but
only two of them are really interesting for %(progname)s: those
whose names are:

  Files in second .deb but not in first

and

  Files in first .deb but not in second

These two sections are referred to as the "interesting sections", and often
assigned to variables named 'second_deb_sec' and 'first_deb_sec', or 'sec'
and 'other_sec' (the latter when we don't want to know which was labeled as
"first" by debdiff, and which was labeled as "second").

2. Indexing the interesting sections
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Once the sections have been read, the interesting sections are indexed if
both are present, so that one can easily find all entries for a given file
basename (this is useful to track files that are shipped in several
directories in the same .deb).

Note: a "file entry" here is a dictionary containing all the information
      from the debdiff output for a given line in one of the interesting
      sections: it contains the file basename, its dirname, its type
      (regular file, symlink...), owner and group, permissions, etc.

3. Extracting moved configuration files
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
If both interesting sections are present, %(progname)s looks for
configuration files that were moved between the two .deb files. A
configuration file is considered to have been "moved" if it doesn't appear
in the exact same set of directories in both .deb files.

Note: what is considered a "configuration file" by %(progname)s
      is a file that can be found in such a path (in either of the two .deb
      files) that the full path (dirname + basename) matches at least one
      of the compiled regular expressions in 'config_files_reclist'
      (typically, a file that is shipped under /etc/texmf in either of the
      .deb files).

All entries for such moved configuration files are extracted (removed) from
the interesting sections, and recorded into a dictionary called
'moved_cfg_files', for later use.

The docstring for extract_moved_cfg_files() reproduced below explains this
process in greater detail.

4. Printing the filtered debdiff output
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Every section from the debdiff output is printed as is, except the
interesting sections, which are "filtered".

These are filtered in two ways. First, the files that were extracted in
step 3, if any, are not listed at this point. Second, other files are
omitted, as described in the docstrings for dump_filtered_section() and
dirnames_are_equivalent(), which are reproduced below. Basically, if a file
is found under several directories that differ only in the last component,
the corresponding entries are not listed at all.

5. Listing the moved configuration files
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
If we found configuration files in step 3 that were moved between the two
.deb files, they are now listed with all details (for each .deb, in which
directories the file can be found, along with owner/group and permission
information, etc.). This is done in a new (fake) section, that doesn't come
directly from debdiff, and thus named:

  Moved configuration files [computed by %(progname)s]


Appendix -- Relevant docstrings
*******************************

extract_moved_cfg_files(moved_cfg_files, sec, other_sec, config_files_reclist)
------------------------------------------------------------------------------

%(docstring_for_extract_moved_cfg_files)s


dump_filtered_section(output, sec, other_sec, filter_in_reclist=None)
---------------------------------------------------------------------

%(docstring_for_dump_filtered_section)s


dirnames_are_equivalent(dirname1, dirname2)
-------------------------------------------

%(docstring_for_dirnames_are_equivalent)s""" \
% {"progname": progname,
   "docstring_for_extract_moved_cfg_files":
   extract_moved_cfg_files.__doc__.rstrip(),
   "docstring_for_dump_filtered_section":
   dump_filtered_section.__doc__.rstrip(),
   "docstring_for_dirnames_are_equivalent":
   dirnames_are_equivalent.__doc__.rstrip()
   }
 

def process_command_line():
    try:
        opts, args = getopt.getopt(sys.argv[1:], "",
                                   ["algorithm",
                                    "help",
                                    "version"])
    except getopt.GetoptError, message:
        sys.stderr.write(usage + "\n")
        return ("exit", 1)

    # Unused for the moment
    params = {}

    for option, value in opts:
        if option == "--algorithm":
            print algorithm_doc
            return ("exit", 0)
        elif option == "--help":
            print usage
            return ("exit", 0)
        elif option == "--version":
            print "%s version %s" % (progname, progversion)
            return ("exit", 0)
        else:
            raise ProgramError("unexpected option received from the "
                               "getopt module: '%s'" % option)

    if len(args) != 0:
        sys.stderr.write(usage + '\n')
        return ("exit", 1)

    return ("continue", params)


def print_filtered_debdiff_output(output, sections, first_deb_sec,
                                  second_deb_sec):
    # No section separator (newline) should be printed before the first section
    print_section_separator = False

    for section in sections:
        if print_section_separator:
            output.write('\n')
        else:
            print_section_separator = True

        if (first_deb_sec is not None) and (second_deb_sec is not None) \
               and (section["name"] is not None):
            if first_deb_sec_rec.match(section["name"]):
                dump_filtered_section(output, first_deb_sec, second_deb_sec,
                                      filter_in_reclist)
            elif second_deb_sec_rec.match(section["name"]):
                dump_filtered_section(output, second_deb_sec, first_deb_sec,
                                      filter_in_reclist)
            else:
                dump_unfiltered_section(output, section)
        else:
            dump_unfiltered_section(output, section)
    

def main():
    action, p = process_command_line()
    if action == "exit":
        sys.exit(p)

    output = sys.stdout

    sections = split_input_into_sections(sys.stdin)
    # Locate the sections "Files in second .deb but not in first"
    # and                 "Files in first .deb but not in second"
    first_deb_sec, second_deb_sec = locate_interesting_sections(sections)

    moved_cfg_files = {}

    # It is only useful to index the "interesting" sections if both of them
    # are present (otherwise, we'll just dump them verbatim).
    # Similarly, there is no point in looking for moved configuration files
    # if these sections aren't both present.
    if (first_deb_sec is not None) and (second_deb_sec is not None):
        for section in first_deb_sec, second_deb_sec:
            index_files(section)

        # Look for moved config files between the two .deb files; extract them
        # from both first_deb_sec["ordered list"] and
        # second_deb_sec["ordered list"], and record them into
        # moved_cfg_files.
        extract_moved_cfg_files(moved_cfg_files,
                                first_deb_sec, second_deb_sec,
                                config_files_reclist)
        # This second call is necessary, because a particular file might not
        # look as a configuration file when looking at 'first_deb_sec' only
        # (for instance, if it's not shipped under /etc/texmf); but it may be
        # shipped in a directory in 'second_deb_sec' that makes it a
        # configuration file (from the POV of this program).
        extract_moved_cfg_files(moved_cfg_files,
                                second_deb_sec, first_deb_sec,
                                config_files_reclist)

    print_filtered_debdiff_output(output, sections, first_deb_sec,
                                  second_deb_sec)
    # List moved configuration files, if any
    if moved_cfg_files:
        list_moved_cfg_files(output, sections, moved_cfg_files)

    sys.exit(0)

if __name__ == "__main__": main()
