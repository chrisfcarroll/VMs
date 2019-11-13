` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [string]$rsa_id_path = (Resolve-Path ~/.ssh/id_rsa.pub).Path,                     #\
       [switch]$andinstall                                                               #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

target=$1
rsa_id_path=${2:-"~/.ssh/id_rsa.pub"}

if [[ ! "$target" =~ ^([A-Za-z0-9\\.-]+@)?[A-Za-z0-9\\.-]+$ ]] ; then
  echo "
  Usage: $0 <[targetlogin@]targetmachine>  [ <rsa_id_path> ]
  "
  exit 1
fi
ssh-copy-id $target
ssh $target 'su - root -ic "export PKG_PATH=\"http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -p)/$(uname -r|cut -f '"'1 2'"' -d.|cut -f 1 -d_)/All\" ; pkg_add -v pkgin"'

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not (test-path $rsa_id_path))
  { throw "$rsa_id_path not found" }
if(-not ($target -match "^[A-Za-z0-9\.-]+@[A-Za-z0-9\.-]+$") )
  { throw "$target doesn't look like a valid user@host" }


cat $rsa_id_path | ssh $target "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
ls *.sh | %{
  "Copying $_ ..."
  cat $_ | ssh $target "cat -> $($_.BaseName)$($_.Extension) ; chmod g+rx $($_.BaseName)$($_.Extension) ; sed -i 's/\r//' *.sh" 
}

ssh $target 'su - root -ic \"export PKG_PATH=\\\"http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -p)/$(uname -r|cut -f '"'1 2'"' -d.|cut -f 1 -d_)/All\\\" ; pkg_add -v pkgin"'


# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"