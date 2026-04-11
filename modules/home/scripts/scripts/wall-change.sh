#!/usr/bin/env bash

if (( RANDOM % 2 )); then
  awww img --transition-type=any $1 ;
else
  awww img --transition-type=wipe --transition-angle=135 $1 ;
fi
