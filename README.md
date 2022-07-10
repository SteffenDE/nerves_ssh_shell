# NervesSSHShell

This project allows you to connect to your [nerves](https://www.nerves-project.org) devices
using a standard shell. It is useful for debugging and testing purposes and allows
running interactive cli applications like vi on the device.

## Installation

Add `nerves_ssh_shell` to your dependencies.

```elixir
def deps do
  [
    {:nerves_ssh_shell, github: "SteffenDE/nerves_ssh_shell", branch: "main"}
  ]
end
```

Add the following configuration options to your `config/target.exs`:

```elixir
# config/target.exs
config :erlexec,
  root: true,
  user: "root",
  limit_users: ["root"]

config :nerves,
  erlinit: [
    hostname_pattern: "nerves-%s",
    # add this
    env: "SHELL=/bin/sh"
  ]
```

There are two ways to run the shell.

1. Using a dedicated SSH daemon and port.
2. Running as an SSH subsystem next to the normal Elixir shell (e.g. `ssh my-nerves-device -s shell`).

Option two has the following known issues:

* the terminal is only sized correctly after resizing the first time
* directly executing commands is not possible (e.g. `ssh my-nerves-device -s shell echo foo` will not work)
* to achieve correct interactivity, the ssh client has to force pty allocation (e.g. `ssh my-nerves-device -tt -s shell`)
* setting environment variables is not supported (e.g. `ssh -o SetEnv="FOO=Bar" my-nerves-device`)

### Running with two daemons

The default configuration for `nerves_ssh` can be left untouched.
Please notice that this requires a `nerves_ssh` version >= `0.4.0`.

```elixir
def deps do
  [
    {:nerves_ssh_shell, github: "SteffenDE/nerves_ssh_shell", branch: "main"}
  ]
end
```

```elixir
# application.ex
def children(_target) do
  [
    ...
    # run a second ssh daemon on another port
    # but with all other options being the same
    # as the default daemon on port 22
    {NervesSSH,
     NervesSSH.Options.with_defaults(
       Application.get_all_env(:nerves_ssh)
       |> Keyword.merge(
         name: :shell,
         port: 2222,
         shell: :disabled,
         daemon_option_overrides: [{:ssh_cli, {NervesSSHShell.CLI, []}}]
       )
     )}
  ]
end
```

### Running as an SSH subsystem

```elixir
config :nerves_ssh,
  subsystems: [
    :ssh_sftpd.subsystem_spec(cwd: '/'),
    {'shell', {NervesSSHShell.ShellSubsystem, []}},
  ],
  authorized_keys: ...
```

### Running without the IEx shell

If you do not need the default IEx shell, you can also just run one daemon and
override the shell, although I do not recommend this as there is no easy way to
access IEx from an OS shell.

```elixir
def deps do
  [
    {:nerves_ssh_shell, github: "SteffenDE/nerves_ssh_shell", branch: "main"}
  ]
end
```

```elixir
# config/target.exs
config :nerves_ssh,
  shell: :disabled,
  daemon_option_overrides: [{:ssh_cli, {NervesSSHShell.CLI, []}}]
  ...
```
