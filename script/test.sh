#!/bin/bash

REDPRL=./bin/redprl
PROBLEM=0

echo "Building RedPRL with SML/NJ..."
./script/smlnj.sh >"build-smlnj.log" 2>&1 || { echo "build failed!"; cat "build-smlnj.log"; exit 1; }
echo "done!"

echo "Building RedPRL with MLton..."
./script/mlton.sh >"build-mlton.log" 2>&1 || { echo "build failed!"; cat "build-mlton.log"; exit 1; }
echo "done!"

# Ensure that the examples file and all suceeding tests succeed
for f in test/examples.prl test/success/*.prl ; do
    if ! $REDPRL $f >$f.log 2>&1 ; then
        PROBLEM=1
        echo "Test $f should succeed but failed!"
    fi
done


# Ensure that failing tests fail
for f in test/failure/*.prl ; do
    if $REDPRL $f >$f.log 2>&1 ; then
        PROBLEM=1
        echo "Test $f should fail but succeeded!"
    fi
done

if [ $PROBLEM -eq 0 ] ; then
    echo "All tests ran as expected!"
fi

exit $PROBLEM
