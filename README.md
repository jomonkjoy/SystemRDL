# SystemRDL
https://peakrdl.readthedocs.io/en/latest/index.html

### Install
```
# 1. Remove the broken venv (created under sudo)
sudo rm -rf ./peakrdl_env

# 2. Re-run as your normal user — NO sudo
chmod +x install_peakrdl.sh
./install_peakrdl.sh

# 3. Activate the environment
source peakrdl_env/bin/activate
```

### Common Field Properties
```
field {} my_field[4] = 4'h0 {
    desc = "My register field";
    reset = 4'hF;        // reset value
    hw = r;              // hardware reads only
    sw = rw;             // software read/write
    we;                  // write-enable qualifier
    singlepulse;         // auto-clears after one cycle
};
```
