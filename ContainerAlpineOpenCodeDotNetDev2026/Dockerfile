FROM alpine:latest
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
RUN apk add libgcc libstdc++ ripgrep bash # maybe opencode dependencies
RUN apk add musl-locales ncurses-terminfo
RUN apk add krb5
RUN touch /etc/rc.conf
RUN sed -i 's/#unicode="NO"/#unicode="NO"\nunicode="YES"/' /etc/rc.conf
RUN adduser -S agent1 -G wheel
RUN sed -i 's#^\(agent1:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)/sbin/nologin$#\1/bin/zsh#' /etc/passwd
RUN mkdir -p /etc/doas.d
RUN echo "permit nopass agent1 as root cmd apk" > /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd npm" >> /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd dotnet" >> /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd pwsh" >> /etc/doas.d/doas.conf
RUN echo "permit nopass agent1 as root cmd uv" >> /etc/doas.d/doas.conf
USER agent1
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
RUN cat <<'EOF'>>  ~/.config/opencode/config.json # this is why we use a container
{
  "yolo":true
}
EOF
RUN cat <<'EOF' >> ~/.tmux.conf
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",tmux-256color:RGB"
set -ga terminal-overrides ",xterm-256color:RGB"
EOF
RUN cat <<'EOF' >> ~/go.sh
for d in /vmrepos/*/ ; do git config --global --add safe.directory "$d" ; done
tmux -u new-session -d ; tmux -u new-session /home/agent1/.opencode/bin/opencode
EOF
RUN chmod a+x ~/go.sh
RUN mkdir /home/agent1/.local
RUN curl -fsSL https://opencode.ai/install | bash
WORKDIR /vmrepos
# --------------------------------
# Repos to work on can be mounted at runtime under /vmrepos.
# Also mount the opencode config and data directories:
# 1. Repos directory
# 2. ~/.config/opencode directory (opencode config)
# 3. ~/.local/share/opencode directory (opencode data & auth)
# Example :
#     docker run -it
#                -e GIT_AUTHOR_NAME=`"Agent1 for $(git config --get user.name)`" `
#                -e GIT_AUTHOR_NAME=`"$(git config --get user.email)`" `
#                -v ~\vmrepos:/vmrepos `
#                -v ~\.local\share\opencode:/home/agent1/.local/share/opencode `
#        alpineopencode:latest
# --------------------------------
ARG GIT_AUTHOR_NAME
ARG GIT_AUTHOR_EMAIL
ENV GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME
ENV GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL
# --------------------------------
#
RUN if [ -n "$GIT_AUTHOR_NAME"  ] ; then git config --global user.name "AgentO for $GIT_AUTHOR_NAME" ; fi
RUN if [ -n "$GIT_AUTHOR_EMAIL" ] ; then git config --global user.email "$GIT_AUTHOR_EMAIL" ; fi
ENTRYPOINT ["zsh", "-c", "/home/agent1/go.sh"]