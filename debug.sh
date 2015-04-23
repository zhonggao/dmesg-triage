#!/bin/bash

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

[[ "$BASHPID" ]] || echo "======= Run me with bash ======="

dump_shell_vars()
{
	(
		set -o posix
		local branch_commit_files=()
		local sparse_lines=()
		local remote_url=()
		set >&2
	)
}

dump_call_stack()
{
	local stack_depth=${#FUNCNAME[@]}
	local i
	for ((i = 0; i < $((stack_depth-1)); i++)); do
		echo "  ${BASH_SOURCE[i+1]}:${BASH_LINENO[i]}: ${FUNCNAME[i+1]}" >&2
	done
}

# nr_stack_dumps=0
dump_stack()
{
	# echo "Stack dump: $BASH_COMMAND"
	dump_call_stack
	echo
	dump_shell_vars
}

notice()
{
	local time_str="$(date +'%F %H:%M:%S') "
	echo -e ${color[MAGENTA]}"${time_str}$*"$reset_color
}

die()
{
	notice "$*"

	dump_stack
	email "$*"
	exit
}
