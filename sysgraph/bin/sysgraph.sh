#!/bin/bash
echo "Reading config...." >&2
source ../etc/sysgraph.conf
function help {
echo "usage: ./sysgraph.sh <date> <graph type>"
echo "example: ./sysgraph.sh 2013-10-22 cpu_load"
echo "currently available graphs : \
cpu_load \
cpu_pct \
io_read \
io_write \
io_wait \
mem_used \
active_conn \
locks"
}
if test $# -ne 2; then
	help
	exit 0
fi
#
# following function defines the filenames that script should use
#
function _property {
if [ $graph = "cpu_load" ]
	then file_pattern="mpstat"
	title="cpu load report for $date"
	xlabel="time"
	ylabel="load"
	colums="1:2"
	limit="100"
	plot_command="plot '$tmpdir/output.csv' using 1:2 title '%user' with lines ls 1 , '$tmpdir/output.csv' using 1:3 title '%system' with lines ls 2,'$tmpdir/output.csv' using 1:4 title '%idle' with lines ls 3"
elif [ $graph = cpu_pct ]
	then file_pattern="mpstat"
elif [ $graph = io_read ]
	then
	title="io read report for $date"
	xlabel="time"
	ylabel="reads"
	colums="1:2"
	limit="10000"
	file_pattern="iostat"
	plot_command="plot '$tmpdir/output.csv' using 1:2 title 'writes' with lines ls 1"		                  
elif [ $graph = io_write ]
	then file_pattern="iostat"
	title="io write report for $date"
	xlabel="time"
	ylabel="writes"
	colums="1:2"
	limit="80000"
        plot_command="plot '$tmpdir/output.csv' using 1:2 title 'writes' with lines ls 1"
elif [ $graph = io_wait ]
	then file_pattern="iostat"
	title="IO wait for $date"
	xlabel="Time"
	ylabel="Wait"
	colums="1:2"	
        limit="2"
        plot_command="plot '$tmpdir/output.csv' using 1:2 title 'writes' with lines ls 1"
elif [ $graph = mem_used ]
	then file_pattern="mem"
	title="Used Memory for $date"
	xlabel="Time"
	ylabel="Used"
	colums="1:2"	
	limit="128"
        plot_command="plot '$tmpdir/output.csv' using 1:2 title 'Memory used (MB)' with lines ls 1"
elif [ $graph = active_conn ]    
	then file_pattern="pg_stat_activity"
	title="active_connections for $date"
	xlabel="Time"
	ylabel="connections"
	colums="1:2" 
	limit="20"                                                                                        
        plot_command="plot '$tmpdir/output.csv' using 1:2 title 'Locks' with lines ls 1"         
elif [ $graph = locks ]    
	then file_pattern="pg_locks"
	title="locks for $date"
	xlabel="Time"
	ylabel="locks"  
	colums="1:2" 
limit="20"                 
                                                
else 
	echo "not right graph type !!"
	exit 0
fi
}

function _get_files {
_property
echo "Grabbing files from $logdir for date: $date..." 

for files in `/usr/bin/find $logdir/ -type f |grep "$date" |grep $file_pattern`
	do cp $files $tmpdir/
done
echo "Uncopressing.."
gunzip $tmpdir/*.gz
}


function _run_parser {
if [ $graph = "cpu_load" ]
	then $parsedir/cpu_usage.sh 
elif [ $graph = cpu_pct ]
	then $parsedir/cpu_usage.sh
elif [ $graph = io_read ]
	then $parsedir/reads_writes.sh $tmpdir $tmpdir $read_disk $read_column $read_op
elif [ $graph = io_write ]
	then $parsedir/reads_writes.sh $tmpdir $tmpdir $write_disk $write_column $write_op
elif [ $graph = io_wait ]
	then $parsedir/response_wait.sh $tmpdir $tmpdir $disk $res_col $svc_col
elif [ $graph = mem_used ]
	then $parsedir/memory_used.sh
elif [ $graph = active_conn ]
        then $parsedir/connection_count.sh $tmpdir $tmpdir
elif [ $graph = active_conn ]
        then $parsedir/locks.sh $tmpdir $tmpdir
        
else 
	echo "no parser :("
fi
}


_get_files

_run_parser 2>/dev/null

#rm $tmpdir/*
#echo $tmpdir
pngfile=$graph-$date.png
gnuplot << EOF
set terminal png size 1920,1080 enhanced font "Helvetica,20"
set output "$graphdir/$pngfile"
set title "$title"
set xlabel "$xlabel"
set ylabel "$ylabel"
set xdata time
set timefmt '%H:%M:%S'
set xrange[ "00:00:00":"23:59:59" ]
set yrange [ 0:"$limit" ]
set format x "%H:%M"
set datafile separator ','
set style line 1 lc rgb '#0000000' lt 10 lw 0.5 pt 1 pi -1 ps 0.5
set style line 3 lc rgb '#0000000' lt 10 lw 0.5 pt 1 pi -1 ps 0.5
set style line 4 lc rgb '#FF0000' lt 10 lw 0.5 pt 1 pi -1 ps 0.5
set style line 1 lc rgb '#708090' lt 10 lw 0.5 pt 1 pi -1 ps 0.5
set style line 2 lc rgb '#8B0000' lt 10 lw 0.5 pt 1 pi -1 ps 0.5
#plot '$tmpdir/output.csv' using 1:2 title 'writes' with lines ls 1 , '$tmpdir/output.csv' using 1:3 title 'reads' with lines ls 2
$plot_command
EOF

echo "Cleaning up temp dir .."
#cp $tmpdir/output.csv ~/
rm -rf $tmpdir/*
echo "Your file can be found at $graphdir/$pngfile ... enjoy"