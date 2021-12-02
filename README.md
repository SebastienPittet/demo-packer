# About demo-packer
demo-packer is all about Hashicorp Packer, a tool to automate the creation of custom templates. It benefits from the idea of Infrastructure as Code (IaC).

## Files of demo-packer
* README : this file
* packer-plugins.pkr.hcl : configuration of the Exoscale plugin
* demo-webapp.pkr.hcl : Describe the creation of a template based on Debian 11 (Bullseye) with nginx, gunicorn and a Python Flask application (taken from Github)
* variables.auto.pkr.hcl : still unused (initial commit)
* deploy.sh : script used to deploy nginx + gunicorn + Python/Flask application. Variables to be adapted.
  
## Usage
To run, use the following:

    export PKR_VAR_api_key=EXO...
    export PKR_VAR_api_secret=...
    packer build demo-webapp.pkr.hcl
