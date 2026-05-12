#!/bin/bash
echo "PASS"; grep -c "Test PASS" ./*log | grep -c ":1"
grep -l "Test PASS" ./*log
echo "FAIL"; grep -c "Test FAIL" ./*log | grep -c ":1"
grep -l "Test FAIL" ./*log
