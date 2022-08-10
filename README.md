# Open Shift Environments

## Prequisites

You must have virutalization enabled in BIOS settings.

## Spinning Up and Open-Shift Environment

1. To start a new

  ```bash
  crc setup
  crc start
  ```

1. Run `eval $(crc oc-env)` to be able to use `oc`
1. Setup `kubectl` by running `oc login -u <USER> <ADDRESS>`
    * Find credentials by running `crc console --credentials`

