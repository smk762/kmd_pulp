#!/bin/bash
for row in $(komodo-cli help); do
	line=( $row )
	echo $line
	echo $row
	echo $row | wc -w
done
