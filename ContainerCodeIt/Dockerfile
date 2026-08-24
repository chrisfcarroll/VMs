FROM alpine:latest
RUN apk add --no-cache zsh
RUN apk add dotnet10-sdk dotnet-sdk-8.0 mono
RUN apk add vim chromium ttf-freefont freetype-dev
RUN apk add nodejs npm git
RUN apk add --no-cache curl doas
RUN apk add --no-cache ca-certificates less ncurses-terminfo-base krb5-libs libgcc libintl libssl3 libstdc++
RUN apk add --no-cache tzdata userspace-rcu zlib icu-libs
RUN apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust openssh-client
# PowerShell: Microsoft only ships musl (Alpine) builds for x64, so on other
# architectures install it as a dotnet tool instead, with gcompat plus a tiny
# shim for two glibc-only symbols its native library needs (verified on aarch64).
RUN set -e; \
    if [ "$(uname -m)" = "x86_64" ]; then \
        curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.5.5/powershell-7.5.5-linux-musl-x64.tar.gz -o /tmp/powershell.tar.gz && \
        mkdir -p /opt/microsoft/powershell/7 && \
        tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
        chmod +x /opt/microsoft/powershell/7/pwsh && \
        ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
        rm -rf /tmp/powershell*; \
    else \
        apk add --no-cache gcompat && \
        apk add --no-cache --virtual .pwsh-build build-base && \
        dotnet tool install --tool-path /opt/microsoft/powershell PowerShell && \
        echo '#include <stdlib.h>'  >  /tmp/chk_shim.c && \
        echo '#include <limits.h>' >> /tmp/chk_shim.c && \
        echo '#include <stdarg.h>' >> /tmp/chk_shim.c && \
        echo '#include <syslog.h>' >> /tmp/chk_shim.c && \
        echo 'char *__realpath_chk(const char *p, char *r, size_t l) { if (l < PATH_MAX) abort(); return realpath(p, r); }' >> /tmp/chk_shim.c && \
        echo 'void __syslog_chk(int pri, int flag, const char *fmt, ...) { va_list ap; va_start(ap, fmt); vsyslog(pri, fmt, ap); va_end(ap); }' >> /tmp/chk_shim.c && \
        gcc -shared -fPIC -o /usr/lib/libpsl-chk-shim.so /tmp/chk_shim.c && \
        rm -f /tmp/chk_shim.c && \
        apk del .pwsh-build && \
        printf '#!/bin/sh\nLD_PRELOAD=/usr/lib/libpsl-chk-shim.so exec /opt/microsoft/powershell/pwsh "$@"\n' > /usr/bin/pwsh && \
        chmod +x /usr/bin/pwsh; \
    fi
RUN apk add docs oh-my-zsh tmux
RUN apk add libgcc libstdc++ ripgrep bash # Claude.AI & opencode dependencies
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
# ---------------------------------------------------------------------
USER agent1
RUN mkdir -p ~/.local/bin
RUN echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
RUN curl -fsSL https://opencode.ai/install | bash
RUN curl -fsSL https://claude.ai/install.sh | bash
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
for d in /vmrepos/*/ ; do git config --global --add safe.directory "$d" ; done
for d in /vmrepos/*/ ; do git config --global --add safe.directory "$d" ; done
case "${CODE_AGENT:-opencode}" in
    opencode) agent_bin=/home/agent1/.opencode/bin/opencode ;;
    claude)   agent_bin=/home/agent1/.local/bin/claude ;;
    *)        echo "Defaulting to opencode" ; agent_bin=/home/agent1/.opencode/bin/opencode ;;
esac
tmux -u new-session -d ; tmux -u new-session "$agent_bin"
EOF
RUN chmod a+x ~/go.sh
RUN mkdir -p ~/.config/opencode
RUN cat <<'EOF' >> ~/.config/opencode/config.json
{
  "yolo":true
}
EOF
WORKDIR /vmrepos
# --------------------------------
# Repos to work on can be mounted at runtime under /vmrepos.
# Also mount the state directories for whichever agent(s) you use, for up to 4 mounts:
# 1. Repos directory
# 2. ~/.claude directory (claude credentials, settings & memory)
# 3. ~/.claude.json file (claude OAuth session data & MCP configs)
# 4. ~/.local/share/opencode directory (opencode data & auth)
# Choose the agent with -e CODE_AGENT=claude (default) or -e CODE_AGENT=opencode
# Example :
#     docker run -it \
#                -e CODE_AGENT=claude \
#                -e GIT_AUTHOR_NAME="Agent1 for $(git config --get user.name)" \
#                -e GIT_AUTHOR_EMAIL="$(git config --get user.email)" \
#                -v ~/vmrepos:/vmrepos \
#                -v ~/.config/code-it/.claude:/home/agent1/.claude \
#                -v ~/.config/code-it/.claude.json:/home/agent1/.claude.json \
#                -v ~/.config/code-it/.local/share/opencode:/home/agent1/.local/share/opencode \
#        alpine-code-dotnet-dev:latest
# --------------------------------
ARG GIT_AUTHOR_NAME
ARG GIT_AUTHOR_EMAIL
ENV GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME
ENV GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL
# --------------------------------
#
RUN if [ -n "$GIT_AUTHOR_NAME"  ] ; then git config --global user.name "Agent1 for $GIT_AUTHOR_NAME" ; fi
RUN if [ -n "$GIT_AUTHOR_EMAIL" ] ; then git config --global user.email "$GIT_AUTHOR_EMAIL" ; fi
ENTRYPOINT ["zsh", "-c", "/home/agent1/go.sh"]
