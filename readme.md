

## Test Execution

```powershell
cd project/pyuvm_tb

# Five I-Cache reads on CPU0
python run_tb.py --test five_trans_test

# Mixed read/write across all 4 CPUs concurrently
python run_tb.py --test base_test

# Verbose debug output
python run_tb.py --test base_test --log-level DEBUG
```

