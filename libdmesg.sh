# !/bin/bash

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
# [Description]: Defined utilities to check out specified dmesg segment 


if [[ -z "${DMESG_ROOT}" ]]; then
	DMESG_ROOT=`pwd`
fi

source $DMESG_ROOT/debug.sh

ERR=1

# desc: capture all the heads of various kmsg exceptional log
# param:
#   [dmesg]: the dmesg log which you'll employ
grep_crash_head()
{
	[[ ! "$*" || "$*" =~ ^-[a-z]+$ ]] && {
		echo "input of grep_crash_head is empty" >&2
		dump_stack
		return 1
	}
	grep -a -f $DMESG_ROOT/oops-pattern "$@" && return

	grep -B8 'Call Trace:$' "$@" |
	grep -B1 -e 'Pid: [0-9]+, comm: ' \
		 -e 'CPU: [0-9]+ PID: [0-9]+ Comm: ' |
	grep -v -e ' [cC]omm: ' \
		-e '^--$' \
		-e '^$' \
		-e '^\[[ 0-9.]*\] $' \
		-e 'The following trace is a kernel self test and not a bug'
}

# desc: filter the kmsg exceptional log messages
# param:
#   [dmesg]: the dmesg log which you'll engage
grep_crash_dmesg()
{
	[[ "$@" ]] || {
		echo "input of grep_crash_dmesg is empty" >&2
		dump_stack
		return 1
	}

	grep -a -f $DMESG_ROOT/oops-pattern \
		-f $DMESG_ROOT/oops-context-pattern "$@"
}

# desc: filter the first kmsg exceptional log 
# param:
#   [dmesg]: the dmesg source you'll use
first_crash_dmesg()
{
	grep_crash_dmesg -C3 "$@" | awk 'BEGIN { nr_first_head=0; };
					/^--$/ { exit };
					/---\[ end trace .*\]---/ { print; getline; print; exit };
					/(kernel BUG at |Kernel panic -|\<BUG: |WARNING: |INFO: )/ { if (nr_first_head > NR + 1) exit; nr_first_head = NR; };
					{ print };
					NR > 200 { exit };'
}

# desc: retrieve dmesg trace info based on dmesg tag
# param:
#   [tag]: a dmesg tag or head
#   [dmesg]: the file which contains your full dmesg log
head_to_dmesg()
{
	[[ $# -eq 2 ]] || {
		echo "ERROR:input of head_to_dmesg is empty !" >&2
		echo "Usage: head_to_dmesg <dmesg_head> <dmesg_log_file>"
		return $ERR
	}
	
	dmesg_head=$1
	dmesg_file=$2

	awk -v pattern="${dmesg_head}" '
	BEGIN { nr_dmesg_target = 0; }
	{
		if ( $0 !~ pattern){
			next;
		} 
		else { 
			nr_dmesg_target = FNR; print;
		}

		do
		{
			if (getline > 0) 
				print; 
			else
				break;

			if ($0 ~ /---\[ end trace .*\]/){
				break;
			}
		} while (NR - nr_dmesg_target < 60)
	}	
	END { 
		if (nr_dmesg_target > 0) {
			print "---[kernel msg end]---";
		}
		else {
			print "Not Found";
		}
	}' "${dmesg_file}"
}


# desc: sort out the call trace funcs from the given dmesg log
# param:
#   [dmesg]: the dmesg source you'll use, if a file 
CALL_TRACE_FUNCS='[a-zA-Z0-9._]+\+0x[0-9a-f]+\/0x[0-9a-f]+'
call_trace_funcs()
{
	local dmesg=$1
	grep -Eo "$CALL_TRACE_FUNCS" $1 | cut -f1 -d+ | uniq
}

# desc: sort out funcs from the first call trace stack of dmesg
# param:
#   [dmesg]: the dmesg call trace log
first_call_trace()
{
	local dmesg=$1
	awk 'BEGIN { in_trace=0; };
		/(Call Trace:|state was registered at:)/ { in_trace++; nr=0; next; };
		/'"$CALL_TRACE_FUNCS"'/{ if (match($0, />\] (?\s)?(_)?[a-zA-Z_][a-zA-Z0-9._]+\+0x/))
						{ print substr($0, RSTART+3, RLENGTH-6); nr++; }; next; };
		// {if (in_trace > 0 && nr > 1) exit;};' $dmesg |
		sed -r -e 's/\.(isra|constprop|part)\.[0-9]+//g' \
			| uniq
}
