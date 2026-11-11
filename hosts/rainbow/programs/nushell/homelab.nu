# Rainbow homelab: one-liners for the agent VMs (Incus project `dev`).
# Autoloaded on rainbow only (hosts/rainbow/home.nix). The runbook behind
# these is hosts/rainbow/HOMELAB.md.
#
#   vm ls                  state, address, last backup; pool usage
#   vm up [vm...]          start (all by default)
#   vm down [vm...]        clean shutdown (all by default)
#   vm backup [vm...]      export home volumes off the pool (VMs stopped)

def vm-state [] {
    ^incus list --project dev --columns ns4 --format csv
    | from csv --noheaders
    | rename name state ipv4
    # One "addr (iface)" per line; prefer the bridge over tailscale0.
    | update ipv4 {|r|
        let addrs = ($r.ipv4 | lines | parse "{addr} ({iface})")
        $addrs | where iface == enp5s0 | append $addrs | get addr.0?
    }
}

def vm-complete [] { vm-state | get name }

# Expand no names to every instance; reject names that don't exist.
def vm-pick [names: list<string>] {
    let all = (vm-state | get name)
    if ($names | is-empty) { return $all }
    let bad = ($names | where $it not-in $all)
    if ($bad | is-not-empty) {
        error make {msg: $"no such VM: ($bad | str join ', ') \(have: ($all | str join ', ')\)"}
    }
    $names
}

def vm-backup-dir [] { $env.HOME | path join backups homelab }

# One VM's home backups, newest first. Never use `ls` in this file:
# config.nu aliases it to eza, and autoload runs after config.nu. The
# date comes from the file name, which `vm backup` stamps in local time.
def vm-backups [vm: string] {
    glob (vm-backup-dir | path join $vm "*.tar.gz")
    | each {|f|
        let stamp = ($f | path basename | parse --regex '-(?<s>\d{8}-\d{6})\.tar\.gz$' | get s.0?)
        if $stamp != null {
            {
                file: $f
                taken: ($stamp | into datetime --format "%Y%m%d-%H%M%S" --timezone local)
                size: (du $f | get apparent.0)
            }
        }
    }
    | sort-by taken --reverse
}

def vm-pool [] {
    ^incus storage info default | lines | where $it =~ 'space used' | first | str trim
}

# Agent VMs: state, address, newest home backup, and the shared pool.
def "vm ls" [] {
    print $"pool (vm-pool)"
    vm-state | insert backup {|r| vm-backups $r.name | get taken.0? }
}

# Start agent VMs (all by default): `vm up`, `vm up sec eng-app`.
def "vm up" [...names: string@vm-complete] {
    let names = (vm-pick $names)
    let todo = (vm-state | where name in $names and state != RUNNING | get name)
    if ($todo | is-not-empty) { ^incus start --project dev ...$todo }
    vm ls
}

# Shut agent VMs down cleanly (all by default). Each gets --timeout
# seconds to stop; one that doesn't is left running and reported, never
# forced. Check no agent is mid-turn first: a stop ends it.
def "vm down" [
    ...names: string@vm-complete
    --timeout (-t): int = 120
] {
    let names = (vm-pick $names)
    let todo = (vm-state | where name in $names and state == RUNNING | get name)
    if ($todo | is-not-empty) {
        ^incus stop --project dev --timeout $timeout ...$todo
    }
    vm ls
}

# Export each VM's home volume to ~/backups/homelab/<vm>/, outside the
# pool. The home is what a re-roll can't rebuild: harness logins, T3
# state and links, ~/projects. The root disk comes from the image, so it
# isn't backed up. The VMs must be stopped (`vm down`), so ext4 is clean.
# Keeps the newest --keep per VM.
#
# These files hold login tokens: the directory is 0700, and they never
# leave the host. Restore: see HOMELAB.md, "Backups".
def "vm backup" [
    ...names: string@vm-complete
    --keep (-k): int = 2
] {
    if $keep < 1 { error make {msg: "--keep must be at least 1"} }
    let names = (vm-pick $names)
    let running = (vm-state | where name in $names and state == RUNNING | get name)
    if ($running | is-not-empty) {
        error make {msg: $"still running: ($running | str join ', '). `vm down` first."}
    }
    let root = (vm-backup-dir)
    mkdir $root
    ^chmod 700 $root
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    for vm in $names {
        let dir = ($root | path join $vm)
        mkdir $dir
        let file = ($dir | path join $"home-($vm)-($stamp).tar.gz")
        # Write to .part and rename, so a failed export never counts as a
        # backup and never triggers pruning of a good one.
        # The `home` device names the volume (home-<vm>, or another name
        # after a restore).
        let vol = (^incus config device get --project dev $vm home source | str trim)
        ^incus storage volume export --project dev --volume-only --quiet default $vol $"($file).part"
        mv $"($file).part" $file
        vm-backups $vm
        | skip $keep
        | each {|b| rm $b.file; print $"pruned ($b.file | path basename)" }
        | ignore
        print $"($vm): ($file | path basename) \((du $file | get apparent.0)\)"
    }
}

# --- vm watch: a live dashboard (nushell's built-in `tui`) -------------------
#
# One `incus query /1.0/metrics` (~25 ms) per refresh gives every running
# VM's CPU, memory, filesystems, disk and network, read from inside the
# guest by the Incus agent, plus the pool. A stopped VM has no metrics.
#
# Keys act on the highlighted VM: u up, d down (asks first), b backup,
# s or Enter shell. Inside zellij they open a floating pane, so the
# dashboard keeps running; outside it they run in place and come back.

const VM_SELF = path self

# Incus metrics we use, as {metric, labels, value} rows.
def vm-metrics [] {
    ^incus query /1.0/metrics
    | lines
    | where $it =~ '^incus_(cpu_seconds_total|memory_(MemTotal|MemAvailable)_bytes|memory_OOM_kills_total|filesystem_(size|avail)_bytes|disk_written_bytes_total|network_(receive|transmit)_bytes_total|procs_total|storage_pool_(used|size)_bytes)\{'
    | parse --regex '^(?<metric>\w+)\{(?<labels>[^}]*)\} (?<value>\S+)$'
    | each {|r| {
        metric: $r.metric
        labels: ($r.labels | parse --regex '(?<k>\w+)="(?<v>[^"]*)"'
                 | reduce --fold {} {|kv, acc| $acc | insert $kv.k $kv.v })
        value: ($r.value | into float)
    } }
}

# One sample: the time, the pool, and per-VM counters and gauges.
def vm-sample [] {
    let m = (vm-metrics)
    let one = {|rows, metric, cond| $rows | where metric == $metric | where $cond | get value | math sum }
    let any = {|_| true }
    {
        at: (date now)
        pool_used: (do $one $m incus_storage_pool_used_bytes {|r| $r.labels.pool? == default })
        pool_size: (do $one $m incus_storage_pool_size_bytes {|r| $r.labels.pool? == default })
        vms: ($m | where $it.labels.name? != null | group-by {|r| $r.labels.name } | items {|name, rows|
            let cpu = ($rows | where metric == incus_cpu_seconds_total)
            let fs = {|metric, mnt| do $one $rows $metric {|r| $r.labels.mountpoint? == $mnt } }
            {
                name: $name
                busy: ($cpu | where $it.labels.mode not-in [idle iowait steal] | get value | math sum)
                vcpus: ($cpu | get labels.cpu | uniq | length)
                mem_total: (do $one $rows incus_memory_MemTotal_bytes $any)
                mem_avail: (do $one $rows incus_memory_MemAvailable_bytes $any)
                oom: (do $one $rows incus_memory_OOM_kills_total $any)
                procs: (do $one $rows incus_procs_total $any)
                root_size: (do $fs incus_filesystem_size_bytes "/")
                root_avail: (do $fs incus_filesystem_avail_bytes "/")
                home_size: (do $fs incus_filesystem_size_bytes "/home/agent")
                home_avail: (do $fs incus_filesystem_avail_bytes "/home/agent")
                # whole disks only: sda is root, sdb the home volume
                written: (do $one $rows incus_disk_written_bytes_total {|r| $r.labels.device? in [sda sdb] })
                rx: (do $one $rows incus_network_receive_bytes_total {|r| $r.labels.device? == enp5s0 })
                tx: (do $one $rows incus_network_transmit_bytes_total {|r| $r.labels.device? == enp5s0 })
            }
        })
    }
}

def vm-gib [b: number] { $"($b / 1073741824 | math round --precision 1)" }

def vm-pct [used: number, size: number] {
    if $size > 0 { $used / $size * 100 | math round } else { 0 }
}

def vm-ago [t] {
    if $t == null { return "never" }
    let s = (((date now) - $t) / 1sec)
    if $s < 3600 { $"($s / 60 | math floor)m" } else if $s < 86400 { $"($s / 3600 | math floor)h" } else { $"($s / 86400 | math floor)d" }
}

def vm-gpu [] {
    try {
        let g = (^nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits
                 | str trim | split row ', ' | into int)
        $"gpu ($g.0)% ($g.1 / 1024 | math round --precision 1)/($g.2 / 1024 | math round --precision 1)G ($g.3)°C"
    } catch { "gpu ?" }
}

# The dashboard's rows. `prev` is the last sample (or null), for rates.
def vm-watch-rows [state_file: string] {
    let prev = (try { open $state_file } catch { null })
    let now = (vm-sample)
    $now | to nuon | save --force $state_file
    let dt = (if $prev == null { 0 } else { ($now.at - ($prev.at | into datetime)) / 1sec })
    let pool_pct = (vm-pct $now.pool_used $now.pool_size)
    let flag = (if $pool_pct >= 90 { " CRITICAL" } else if $pool_pct >= 80 { " WARN" } else { "" })
    let host = (sys mem)
    let title = ([
        $"rainbow homelab"
        $"pool (vm-gib $now.pool_used)/(vm-gib $now.pool_size)G ($pool_pct)%($flag)"
        $"host mem avail ($host.available)"
        (vm-gpu)
        ($now.at | format date "%H:%M:%S")
    ] | str join "  ·  ")
    vm-state | each {|s|
        let c = ($now.vms | where name == $s.name | get 0?)
        let p = ($prev.vms? | default [] | where name == $s.name | get 0?)
        let b = (vm-backups $s.name | get 0?)
        let rate = ($c != null and $p != null and $dt > 0)
        {
            name: $s.name
            state: $s.state
            ipv4: ($s.ipv4 | default "")
            cpu: (if $rate { $"(($c.busy - $p.busy) / $dt / $c.vcpus * 100 | math round)%" } else { "" })
            mem: (if $c != null { $"(vm-gib ($c.mem_total - $c.mem_avail))/(vm-gib $c.mem_total)G" } else { "" })
            root: (if $c != null { $"(vm-pct ($c.root_size - $c.root_avail) $c.root_size)%" } else { "" })
            home: (if $c != null { $"(vm-pct ($c.home_size - $c.home_avail) $c.home_size)%" } else { "" })
            write: (if $rate { $"(($c.written - $p.written) / $dt / 1048576 | math round --precision 1) MB/s" } else { "" })
            backup: (vm-ago $b.taken?)
            # hidden columns, read by the title, bars and detail pane
            title: $title
            pool_pct: $pool_pct
            mem_pct: (if $c != null { vm-pct ($c.mem_total - $c.mem_avail) $c.mem_total } else { 0 })
            root_pct: (if $c != null { vm-pct ($c.root_size - $c.root_avail) $c.root_size } else { 0 })
            home_pct: (if $c != null { vm-pct ($c.home_size - $c.home_avail) $c.home_size } else { 0 })
            detail: (if $c == null { $"($s.name) is ($s.state | str lowercase): no metrics." } else { [
                $"vcpus ($c.vcpus)   procs ($c.procs | into int)   oom kills ($c.oom | into int)"
                $"mem    (vm-gib ($c.mem_total - $c.mem_avail)) / (vm-gib $c.mem_total) GiB"
                $"root   (vm-gib ($c.root_size - $c.root_avail)) / (vm-gib $c.root_size) GiB"
                $"home   (vm-gib ($c.home_size - $c.home_avail)) / (vm-gib $c.home_size) GiB"
                $"since boot: wrote (vm-gib $c.written) GiB, net rx (vm-gib $c.rx) / tx (vm-gib $c.tx) GiB"
                (if $b == null { "backup  none" } else { $"backup  ($b.file | path basename) \(($b.size)\)" })
            ] | str join "\n" })
        }
    }
}

def vm-watch-ui [] {
    let rows = $in
    let key = {|op| {|s| {action: submit, selected: {op: $op, vm: $s.values.vms.row.name}} } }
    $rows | tui label --titlebar --from vms {|r| $r.title }
    | tui split --vertical --sizes [1 "1fr" 9] [
        (tui progress --total 100 --from vms --label "pool" {|r| $r.pool_pct })
        (tui table --id vms --focus --title "agent VMs"
            --columns [name state ipv4 cpu mem root home write backup])
        (tui split --ratio 40 [
            (tui box "selected" [
                (tui progress --total 100 --from vms --label "mem " {|r| $r.mem_pct })
                (tui progress --total 100 --from vms --label "root" {|r| $r.root_pct })
                (tui progress --total 100 --from vms --label "home" {|r| $r.home_pct })
            ])
            (tui preview --from vms --title "detail" {|r| $r.detail })
        ])
    ]
    | tui label --status "u up · d down · b backup · s/enter shell · q quit"
    | tui bind u (do $key up)
    | tui bind d (do $key down)
    | tui bind b (do $key backup)
    | tui bind s (do $key shell)
}

def vm-confirm [question: string] {
    let r = ([no yes] | tui label --titlebar $question | tui select | tui run --dialog --size [40 8])
    $r.action == submit and $r.selected == yes
}

# Run an action on one VM: a floating pane inside zellij, else in place.
def vm-dispatch [op: string, vm: string] {
    let cmd = (if $op == shell {
        [incus exec --project dev $vm -- su - agent]
    } else {
        [nu -c $"source '($VM_SELF)'; vm ($op) ($vm)"]
    })
    if ($env.ZELLIJ? != null) {
        # a shell pane closes with the shell; the others stay to show the result
        let close = (if $op == shell { [--close-on-exit] } else { [] })
        ^zellij run --floating ...$close --name $"($op) ($vm)" -- ...$cmd
    } else {
        run-external ...$cmd
        if $op != shell { input "press enter to return " | ignore }
    }
}

# Live dashboard of the agent VMs and the pool. See the keys above.
def "vm watch" [--refresh (-r): duration = 3sec] {
    let state_file = ($env.XDG_RUNTIME_DIR? | default "/tmp" | path join $"vm-watch-($nu.pid).nuon")
    loop {
        let r = (vm-watch-rows $state_file
                 | vm-watch-ui
                 | tui run --refresh $refresh { vm-watch-rows $state_file })
        if $r.action != submit { break }
        let op = ($r.selected.op? | default shell)
        let vm = ($r.selected.vm? | default $r.selected.name?)
        if $vm == null { continue }
        if $op == down and not (vm-confirm $"stop ($vm)?") { continue }
        vm-dispatch $op $vm
    }
    rm --force $state_file
}
