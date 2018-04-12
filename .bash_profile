set -u

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
  # Supress `-bash: PROMPT_COMMAND: unbound variable` messasges
  set +u
  eval "$(pyenv virtualenv-init -)"
  set -u
fi

PY2_VERSION="2.7.14"
PY3_VERSION="3.6.3"

pyenv global $PY3_VERSION $PY2_VERSION

export PATH="$HOME/.pyenv/versions/$PY3_VERSION/bin/:$PATH"
export PATH="$HOME/.pyenv/versions/$PY2_VERSION/bin/:$PATH"

eval "$(rbenv init -)"

eval "$(nodenv init -)"

sh -c 'if ! minikube status > /dev/null; then minikube start || (echo failed to start minikube 1>&2); fi' &
eval $(minikube docker-env)

function protoc() {
  docker run --rm -v $(pwd):$(pwd) -w $(pwd) znly/protoc "$@"
}

# Executables intalled via go get -u
export PATH="$HOME/go/bin:$PATH"

# Executables installed manually
export PATH="$HOME/bin:$PATH"

# Supress `-bash: PROMPT_COMMAND: unbound variable` messages
set +u
eval "$(direnv hook bash)"
set -u

alias k=kubectl
alias ks='kubectl --namespace kube-system'
alias kn=kubens
alias kc=kubectx
alias s=stern
alias oal='onelogin-aws-login -u $ONELOGIN_USER'

ki() {
  set -eux

  if [ -z "${KUBECONFIG:-}" ]; then
    default_kubeconfig_path=$(pwd)/kubeconfig
    if [ -e "$default_kubeconfig_path" ]; then
      export KUBECONFIG="$default_kubeconfig_path"
    else
      echo KUBECONFIG should be specified in order for this script to work 1>&2
      exit 1
    fi
  fi

  echo Importing "$KUBECONFIG" to ~/kube/config

  cluster_ca=$(kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority}')
  cluster_server=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
  cluster_name=$(kubectl config view -o jsonpath='{.clusters[0].name}')

  context_cluster_name=$(kubectl config view -o jsonpath='{.contexts[0].context.cluster}')
  context_user_name=$(kubectl config view -o jsonpath='{.contexts[0].context.user}')
  context_name=$(kubectl config view -o jsonpath='{.contexts[0].name}')

  user_name=$(kubectl config view -o jsonpath='{.users[0].name}')
  user_client_cert=$(kubectl config view -o jsonpath='{.users[0].user.client-certificate}')
  user_client_key=$(kubectl config view -o jsonpath='{.users[0].user.client-key}')
  user_token=$(kubectl config view -o jsonpath='{.users[0].user.token}')

  unset KUBECONFIG

  kubectl config set-cluster $cluster_name \
    --server=$cluster_server \
    --certificate-authority=$cluster_ca \
    --embed-certs=true

  kubectl config set-context $context_name \
    --cluster=$context_cluster_name \
    --user=$context_user_name

  cred_flags=""

  if [ ! -z "$user_client_cert" ]; then
    cred_flags="$cred_flags --client-certificate=$user_client_cert"
  fi

  if [ ! -z "$user_client_key" ]; then
    cred_flags="$cred_flags --client-key=$user_client_key"
  fi

  if [ ! -z "$user_token" ]; then
    cred_flags="$cred_flags --token=$user_token"
  fi

  kubectl config set-credentials $user_name \
    --embed-certs \
    $cred_flags

  kubectl config use-context $context_name
}

kec2() {
  current_context=$(kubectl config current-context)
  cluster_name=$(kubectl config view -o jsonpath='{.contexts[?(@.name == "'$current_context'")].context.cluster}')
  cluster_name=${cluster_name#kube-aws-}
  cluster_name=${cluster_name%-cluster}
  aws ec2 describe-instances --output json --filter Name=tag-key,Values=kubernetes.io/cluster/$cluster_name | jq '[.Reservations[].Instances[] | select(.State.Name == "running") | {InstanceId: .InstanceId, PublicIpAddress: .PublicIpAddress, PrivateIpAddress: .NetworkInterfaces[0].PrivateIpAddress, Name: (.Tags[] | select(.Key == "Name") | .Value)}]'
}

kssh() {
   ssh -i $SSH_PRIVATE_KEY $SSH_USER@$(kec2 | jq -rc .[] | peco | jq -r .PublicIpAddress) "$@"
}

kra() {
  k run alpine-$(date +%s) --image ruby:2.3.5-alpine --rm -i --tty --restart=Never -- "$@"
}

kru() {
  k run xenial-$(date +%s) --image ubuntu:xenial --rm -i --tty --restart=Never -- "$@"
}

dr() {
  docker run -it --rm $@
}

dasg() {
  if [ -z "$1" ]; then
    echo 'Usage: dasg $asg_name' 1>&2
    return 1
  fi

  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $1 | jq -rc '.AutoScalingGroups[] | {DesiredCapacity: .DesiredCapacity}'
}

sasg() {
  if [ -z "$1" -o -z "$2" ]; then
    echo 'Usage: sasg $asg_name $desired_capacity' 1>&2
    return 1
  fi
  
  aws autoscaling set-desired-capacity --auto-scaling-group-name $1 --desired-capacity $2
}

dasi() {
  if [ -z "$1" ]; then
    echo 'Usage: dasi $asg_name' 1>&2
    return 1
  fi

  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $1 | jq -rc '.AutoScalingGroups[].Instances[] | {InstanceId: .InstanceId, HealthStatus: .HealthStatus, LifecycleStatus: .LifecycleState}'
}

di() {
  if [ -z "$1" ]; then
    echo 'Usage: di $instance_id' 1>&2
    return 1
  fi
  aws ec2 describe-instances --instance-ids $1 | jq '.Reservations[].Instances[] | [{PrivateIpAddress: .PrivateIpAddress, ImageId: .ImageId, StateName: .State.Name}]'
}

dlb() {
  conds=$(echo "$@" | jq -cR 'split(" ")')
  echo conds: $conds
  aws elb describe-load-balancers | jq --argjson CONDS "$conds" "[.LoadBalancerDescriptions[] | {LoadBalancerName: .LoadBalancerName, InstanceIds: [.Instances[].InstanceId]} | select(reduce \$CONDS[] as \$item (.LoadBalancerName; if . | contains(\$item) then . else \"\" end) != \"\")]"
}

esl() {
  exec $SHELL -l
}

alias trusty='docker run -it --rm buildpack-deps:trusty /bin/bash'

# https://stackoverflow.com/questions/32723111/how-to-remove-old-and-unused-docker-images
alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '

# https://medium.com/@crashybang/supercharge-vim-with-fzf-and-ripgrep-d4661fc853d2
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'

# https://github.com/junegunn/fzf/wiki/examples#tmux
tm() {
  [[ -n "$TMUX" ]] && change="switch-client" || change="attach-session"
  if [ $1 ]; then
    tmux $change -t "$1" 2>/dev/null || (tmux new-session -d -s $1 && tmux $change -t "$1"); return
  fi
  session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0) &&  tmux $change -t "$session" || echo "No sessions found."
}

fs() {
  local session
  session=$(tmux list-sessions -F "#{session_name}" | \
    fzf --query="$1" --select-1 --exit-0) &&
  tmux switch-client -t "$session"
}

gf() {
  test -z "$(find . -path ./vendor -prune -type f -o -name '*.go' -exec gofmt -d {} + | tee /dev/stderr)" || \
  test -z "$(find . -path ./vendor -prune -type f -o -name '*.go' -exec gofmt -w {} + | tee /dev/stderr)"
}

# Add Visual Studio Code (code)
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin:/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/"

export KUBE_EDITOR='code --wait'
