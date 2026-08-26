FROM alpine:3.23
# alpine 3.24 dotnet not yet working? https://github.com/dotnet/dotnet-docker/issues/7334
RUN apk add --no-cache zsh
RUN apk add dotnet10-sdk dotnet-sdk-8.0 mono
RUN apk add vim chromium ttf-freefont freetype-dev
RUN apk add nodejs npm git
RUN apk add --no-cache curl doas
RUN apk add --no-cache ca-certificates less ncurses-terminfo-base krb5-libs libgcc libintl libssl3 libstdc++
RUN apk add --no-cache tzdata userspace-rcu zlib icu-libs
RUN apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust openssh-client
RUN curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.5.5/powershell-7.5.5-linux-musl-x64.tar.gz -o /tmp/powershell.tar.gz
RUN mkdir -p /opt/microsoft/powershell/7
RUN tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
RUN chmod +x /opt/microsoft/powershell/7/pwsh
RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
RUN rm -rf /tmp/powershell*
RUN apk add docs oh-my-zsh tmux
RUN apk add libgcc libstdc++ ripgrep bash # Claude.AI dependencies
RUN apk add musl-locales ncurses-terminfo
RUN apk add krb5
RUN touch /etc/rc.conf
RUN sed -i 's/#unicode="NO"/#unicode="NO"\nunicode="YES"/' /etc/rc.conf
RUN adduser -S agent1 -G wheel
RUN sed -i 's#^\(agent1:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)/sbin/nologin$#\1/bin/zsh#' /etc/passwd
RUN mkdir -p /etc/doas.d
RUN echo "permit nopass agent1 as root cmd apk" > /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd dotnet" >> /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd uv" >> /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd npm" >> /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd node" >> /etc/doas.d/doas.conf
USER agent1
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
RUN git config --global rerere.enabled true
RUN git config --global alias.root 'rev-parse --show-toplevel'
RUN git config --global alias.lg  "log --color --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --graph"
RUN git config --global alias.glog "log --color --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
RUN git config --global core.autocrlf true
RUN cat <<'EOF' >> ~/.zshrc
export PS1='%2~]'
alias glogg='git log --color --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit --graph'
alias glog='git log --color --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gco='git checkout'
alias gaa='git add -A'
alias gitacom='git commit -am'
alias gb='git branch'
alias grv='git remote -v'
alias gs='git status'
alias la='ls -A'
alias ll='ls -alF'
alias tms='tmux switch'
alias tml='tmux ls'
alias tma='tmux a'
export LESS="-FRX"
plugins=(git)
ZSH_THEME="robbyrussell"
source /usr/share/oh-my-zsh/oh-my-zsh.sh
EOF
RUN cat <<'EOF' >> ~/.tmux.conf
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",tmux-256color:RGB"
set -ga terminal-overrides ",xterm-256color:RGB"
EOF
RUN cat <<'EOF' >> ~/go.sh
git config --global --add safe.directory /repos
for d in /repos/*/ ; do git config --global --add safe.directory "$d" ; done
tmux -u new-session -d ; tmux -u new-session /home/agent1/.local/bin/claude
EOF
RUN chmod a+x ~/go.sh
WORKDIR /repos
# --------------------------------
# Repos to work on can be mounted at runtime under /repos.
# Also mount the file and directory for claude settings & memory, for a total of 3 mounts:
# 1. Repos directory
# 2. ~/.claude directory
# 3. ~/.claude.json file
# Example : 
#     docker run -it --rm
#                -e GIT_AUTHOR_NAME=`"Agent1 for $(git config --get user.name)`" `
#                -e GIT_AUTHOR_NAME=`"$(git config --get user.email)`" `
#                -v ~/repos:/repos `
#                -v ~\claude-home\.claude:/home/agent1/.claude `
#                -v ~\claude-home\.claude.json:/home/agent1/.claude.json `
#        alpineclaude:latest
# --------------------------------
ARG GIT_AUTHOR_NAME
ARG GIT_AUTHOR_EMAIL
ENV GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME
ENV GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL
# --------------------------------
#
RUN if [ -n "$GIT_AUTHOR_NAME"  ] ; then git config --global user.name "AgentC for $GIT_AUTHOR_NAME" ; fi
RUN if [ -n "$GIT_AUTHOR_EMAIL" ] ; then git config --global user.email "$GIT_AUTHOR_EMAIL" ; fi
ENTRYPOINT ["zsh", "-c", "/home/agent1/go.sh"]