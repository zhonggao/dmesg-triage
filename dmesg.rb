#!/usr/bin/ruby

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# [Description]: Find out all crash dmesg clauses with tailored pattern



require "fileutils"
require "tempfile"

def fixup_dmesg(line)
	line.chomp!

	# remove absolute path names
	line.sub!(%r{/kbuild/src/[^/]+/}, '')

	line.sub!(/\.(isra|constprop|part)\.[0-9]+\+0x/, '+0x')

	# break up mixed messages
	case line
	when /^<[0-9]>/
	when /(.+)(\[ *[0-9]{1,6}\.[0-9]{6}\] .*)/
		line = $1 + "\n" + $2
	end

	return line
end

def fixup_dmesg_file(dmesg_file)
	tmpfile = Tempfile.new '.fixup-dmesg-', File.dirname(dmesg_file)
	dmesg_lines = []
	File.open(dmesg_file, 'rb') do |f|
		f.each_line { |line|
			line = fixup_dmesg(line)
			dmesg_lines << line
			tmpfile.puts line
		}
	end
	tmpfile.chmod 0664
	tmpfile.close
	FileUtils.mv tmpfile.path, dmesg_file, :force => true
	return dmesg_lines
end

def grep_crash_head(dmesg, grep_options = '')
	oops = %x[ grep -a -f #{DMESG_ROOT}/oops-pattern #{grep_options} #{dmesg} |
		   grep -v -e 'INFO: NMI handler .* took too long to run' |
		   awk '{line = $0; sub(/^(<[0-9]>)?\[[ 0-9.]+\] /, "", line); if (!x[line]++) print;}'
	]
	return oops unless oops.empty?


	if system "grep -q -F 'EXT4-fs ('	#{dmesg}"
		oops = `grep -a -f #{DMESG_ROOT}/ext4-crit-pattern	#{grep_options} #{dmesg}`
		return oops unless oops.empty?
	end

	if system "grep -q -F 'XFS ('	#{dmesg}"
		oops = `grep -a -f #{DMESG_ROOT}/xfs-alert-pattern	#{grep_options} #{dmesg}`
		return oops unless oops.empty?
	end

	if system "grep -q -F 'btrfs: '	#{dmesg}"
		oops = `grep -a -f #{DMESG_ROOT}/btrfs-crit-pattern	#{grep_options} #{dmesg}`
		return oops unless oops.empty?
	end

	return ''
end

def grep_printk_errors(dmesg_file, dmesg_lines)
	oops = `grep -a -f #{DMESG_ROOT}/oops-pattern #{dmesg_file}`
	dmesg = dmesg_lines.join "\n"
	oops += `grep -a -f #{DMESG_ROOT}/ext4-crit-pattern	#{dmesg_file}` if dmesg.index 'EXT4-fs ('
	oops += `grep -a -f #{DMESG_ROOT}/xfs-alert-pattern	#{dmesg_file}` if dmesg.index 'XFS ('
	oops += `grep -a -f #{DMESG_ROOT}/btrfs-crit-pattern	#{dmesg_file}` if dmesg.index 'btrfs: '
	return oops
end

def common_error_id(line)
	line = line.chomp
	line.gsub! /\b3\.[0-9]+[-a-z0-9.]+/, '#'			# linux version: 3.17.0-next-20141008-g099669ed
	line.gsub! /\b[1-9][0-9]-[A-Z][a-z]+-[0-9]{4}\b/, '#'		# Date: 28-Dec-2013
	line.gsub! /\b0x[0-9a-f]+\b/, '#'				# hex number
	line.gsub! /\b[a-f0-9]{40}\b/, '#'				# SHA-1
	line.gsub! /\b[0-9][0-9.]*/, '#'				# number
	line.gsub! /#x\b/, '0x'
	line.gsub! /[ \t]/, ' '
	line.gsub! /\ \ +/, ' '
	line.gsub! /([^a-zA-Z0-9])\ /, '\1'
	line.gsub! /\ ([^a-zA-Z])/, '\1'
	line.gsub! /^\ /, ''
	line.gsub! /\  _/, '_'
	line.gsub! /\ /, '_'
	line.gsub! /[-_.,;:#!\[\(]+$/, ''
	line
end
