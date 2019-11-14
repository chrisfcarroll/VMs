` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target                                       #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

target=$1
if [[ ! "$target" =~ ^([A-Za-z0-9\\.-]+@)?[A-Za-z0-9\\.-]+$ ]] ; then
  echo "
  Usage: $0 <[targetlogin@]targetmachine>
  "
  exit 1
fi

f="netbsd-install-pkgsrc-pkgin.sh"
ssh $target 'su - root -ic "set -x ; \$HOME/'$f'"'

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not ($target -match "^([A-Za-z0-9\.-]+@)?[A-Za-z0-9\.-]+$") )
{ 
  throw "Usage: $PSCommandPath <[targetlogin@]targetmachine>" 
}

  $f="netbsd-install-pkgsrc-pkgin.sh"
  "Running $f as root ..."
  $cmd='su - root -ic \"set -x ; \$HOME/' + $f + '\"'
  ssh $target $cmd

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"
