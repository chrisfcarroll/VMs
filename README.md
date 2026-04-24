# VMs and Dockerfiles

Bootstrap scripts for
- A [Docker container for Alpine + Claude + DotNet Dev](/ContainerAlpineClaudeDotNetDev2026),
  - Start it up with [Claude-It.ps1](/ContainerAlpineClaudeDotNetDev2026/Claude-It.ps1)
  - The bash equivalent isn't yet tested: [claude-it.sh](/ContainerAlpineClaudeDotNetDev2026/claude-it.sh)

- A [complete secured Wordpress on Centos Server](/CentOs)
    - this used to be the main point of this repo.

- Basic setup of various BSD dev machines and other Linux boxes
    - these are intended to navigate the varieties of package management for BSD flavours and get
      the basics for a dev desktop machine up and running

Scripts names `bootstrap*.ps1` are intended to run on your own machine in either
bash or powershell (your preference!), and to bootstrap the copying and running 
of files to the target machine.
