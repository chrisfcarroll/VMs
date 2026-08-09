The subdirectories Container* contain multiple versions of what is essentially the same thing -- launch claude code or opencode inside a container. The variations are: powershell vs bash ; claude vs opencode ; apple containers vs docker.

Can you create a new directory called ContainerCodeIt/ that contains:
1) A single dockerfile including both claude and opencode
2) A single code-it.sh that detects macos and uses apple containers if present ; else detects docker and uses that if present ; else suggests what is best for the current platform
2.1) Otherwise doese the same as the multiple existing scripts, of defaulting to current directory, calculating a git user if appropriate, setting up a mount for persisting session information after container is destroyed and a new one created
2.2) adds switches --claude and --opencode with aliases -c and -o for choosing claude or opencode
2.3) Add an 'alias' script claude-it.sh 'for code-it.sh --claude'
2.4) include the same for powershell, except that powershell is allowed to assume docker
3) Write whatever test scripts you can. Ensure that it works on this platform (you are inside a docker shell but you can run both bash and powershell).
