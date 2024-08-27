```
## cloud shell - power shell 형태에서 실행
```

```
$version = "v2.8.3"
$url = "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-linux-amd64"
$output = "$HOME/argocd"

Invoke-WebRequest -Uri $url -OutFile $output
```

```
chmod +x $HOME/argocd
```

```
mkdir -p $HOME/bin
mv $HOME/argocd $HOME/bin/argocd
```

```
$profile = [Environment]::GetEnvironmentVariable("HOME") + "/.bashrc"
Add-Content -Path $profile -Value "`nexport PATH=`$HOME/bin:`$PATH"
source $profile
```

```
# source 구문이 실행되지 않더라도 밑에 argocd version이 잘 실행되면 상관없음
argocd version
```
