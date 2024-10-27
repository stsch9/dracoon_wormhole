# dracoon_wormhole
With `dracoon_wormhole` you can create an S3 download url for a file stored in a DRACOON tenant, which can be called directly via `curl`. This is often very helpful on server without a desktop environment. <br />
You can also send the S3 download url with [magic wormhole](https://magic-wormhole.readthedocs.io/en/latest/) so that the recipient can download the file with it. Therefore, `dracoon_wormhole` is a secure file sharing solution for files stored in a DRACOON tenant. In particular, download shares do not have to be sent via insecure e-mails.
## Usage
```
Usage:
      dracoon_wormhole downloadurl -D,--domain DRACOON DOMAIN -s,--src SOURCE
        Generate Download curl command for file SOURCE
      dracoon_wormhole send -D,--domain DRACOON DOMAIN -s,--src SOURCE
        Send a Download Url via Magic Wormhole
      dracoon_wormhole receive CODE
        Receive Download Url via Magic Wormhole and use Download Url
      dracoon_wormhole help
        Print this help.
```
## Requirements
- [magic wormhole](https://github.com/magic-wormhole/magic-wormhole)
