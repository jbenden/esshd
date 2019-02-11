# Elixir SSHd

A very simple way to add SSH server capabilities to an Elixir application.

## Features

* Simple way of adding SSH version 2.0 server capabilities to one's
  application, in a secured manner.
* Acceptable for production systems; due to the secured nature of
  SSH version 2.0, and the ability of fine-grain access control
  and authentication methods available.
* Quick way to drop in to an Elixir or Erlang REPL.
* Easiest way to create remote accessible custom shell-like
  programs.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `esshd` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:esshd, "~> 0.1.0"}]
end
```

After adding `esshd` as a dependency, ensure it is started before your own
application in `mix.exs`:

```elixir
def application do
  [extra_applications: [:esshd]]
end
```

## Usage

This Elixir application offers a number of use-cases; and we recommend
selecting the solution that best matches your project's desired goal.

### Drop-in Secure Remote Elixir REPL

Once installed, add the following configuration to your project:

```elixir
app_dir = Application.app_dir(:myapp)
priv_dir = Path.join([app_dir, "priv"])

config :esshd,
  enabled: true,
  priv_dir: priv_dir,
  handler: "Sshd.ShellHandler.Elixir",
  port: 10_022,
  public_key_authenticator: "Sshd.PublicKeyAuthenticator.AuthorizedKeys"
```

Once the above configuration is added, your application will require OpenSSH
compatible SSH host keys and an `authorized_keys` file stored inside of your
application's `priv` directory.

To generate the needed OpenSSH host keys, change in to your application's
`priv` directory and execute an appropriate command. An example of such
command sequences are as follows:

```sh
$ [ -d priv ] || mkdir priv
$ chmod 700 priv
$ cd priv
$ ssh-keygen -N "" -b 256  -t ecdsa -f ssh_host_ecdsa_key
$ ssh-keygen -N "" -b 1024 -t dsa -f ssh_host_dsa_key
$ ssh-keygen -N "" -b 2048 -t rsa -f ssh_host_rsa_key
$ echo 127.0.0.1,127.0.0.1 `cat ssh_host_ecdsa_key.pub` > known_hosts
$ chmod 644 known_hosts
```

Finally, add all OpenSSH public keys to be accepted in to the `authorized_keys`
file within your application's `priv` directory.

### Drop-in Secure Remote Erlang REPL

Once installed, add the following configuration to your project:

```elixir
app_dir = Application.app_dir(:myapp)
priv_dir = Path.join([app_dir, "priv"])

config :esshd,
  enabled: true,
  priv_dir: priv_dir,
  handler: "Sshd.ShellHandler.Erlang",
  port: 10_022,
  public_key_authenticator: "Sshd.PublicKeyAuthenticator.AuthorizedKeys"
```

Once the above configuration is added, your application will require OpenSSH
compatible SSH host keys and an `authorized_keys` file stored inside of your
application's `priv` directory.

To generate the needed OpenSSH host keys, change in to your application's
`priv` directory and execute an appropriate command. An example of such
command sequences are as follows:

```sh
$ [ -d priv ] || mkdir priv
$ chmod 700 priv
$ cd priv
$ ssh-keygen -N "" -b 256  -t ecdsa -f ssh_host_ecdsa_key
$ ssh-keygen -N "" -b 1024 -t dsa -f ssh_host_dsa_key
$ ssh-keygen -N "" -b 2048 -t rsa -f ssh_host_rsa_key
$ echo 127.0.0.1,127.0.0.1 `cat ssh_host_ecdsa_key.pub` > known_hosts
$ chmod 644 known_hosts
```

Finally, add all OpenSSH public keys to be accepted in to the `authorized_keys`
file within your application's `priv` directory.

### Custom Access Control and Authorization

`esshd` was designed around the concept of easily changing the methods
employed in each of access control and authorization by changing the
utilized "handler" of each component - by way of Elixir Behaviors.

The following behaviors exist and may be implemented and easily
configured for use, at application boot time.

- `Sshd.AccessList`: offers control over the connecting remote IP
  address and ports, by simple return of a boolean value that
  states if the remote connection is accepted. While it may seem
  simplistic, at first, a behavior may be as complex as time-
  based, quantity of already connected peers, etc.
- `Sshd.PasswordAuthenticator`: offers a means for username and
  password verification. The behavior offers NO throttling or any
  such complexity and MUST be securely interfaced to a trusted
  library that performs correct password handling, even under
  the case of an invalid password - to prevent detection of
  actual valid user accounts.
- `Sshd.PublicKeyAuthenticator`: offers a means for username and
  public key verification. While many authentication libraries
  may not offer this ability - when tied to also tasked with
  password authentication - one could still tie to their user
  back-end storage to accommodate this behavior. Also, much like
  password authentication, correct handling it imperative; see
  above.
- `Sshd.ShellHandler`: offers a means for custom, do-it-yourself
  remote shells, whereby you are in full control, and may
  implement any `IO` to-and-from standard input and output
  streams. An example of such a shell is included, as it is
  a mildly complex topic.

## Configuration Options

The following configuration options are available, with the
default setting shown:

* `access_list :: string(Sshd.AccessList.Default)`: A string containing
  the fully qualified module that implements the `Sshd.AccessList`
  behavior.
* `enabled :: boolean(true)`: Determines if the SSH server is
  enabled or not. Useful in complex applications to disable
  all incoming SSH connection functionality, without a full
  recompile and deploy.
* `handler :: string(Sshd.ShellHandler.Default)`: A string containing
  the fully qualified module that implements the
  `Sshd.ShellHandler` behavior.
* `idle_time :: integer(86_400_000 * 3)`: The amount of time, in
  milliseconds, an idle connection may remain, before being automatically
  disconnected. This does not effect actively utilized connections.
* `max_sessions :: integer(50)`: The maximum number of simultaneous
  users connected at one time.
* `negotiation_timeout :: integer(11_000)`: The amount of time,
  in milliseconds, that a connection has to begin correct phases of
  entering in to a valid SSH connection, before being flat out
  disconnected. This setting helps to keep server utilization down
  due to port scans and other similar problems.
* `parallel_login :: boolean(false)`: Determines if
  simultaneous connections are permitted in the authentication
  phase. This does not effect if multiple users may be connected
  simultaneously.
* `password_authenticator :: string(Sshd.PasswordAuthenticator.Default)`:
  A string containing the fully qualified module that implements
  the `Sshd.PasswordAuthenticator` behavior.
* `port :: integer(10_022)`: The TCP port number of the SSH server
  process.
* `preferred_algorithms :: tuple`: The acceptable hashes, ciphers,
  and key exchange mechanizisms of the SSH server. The default
  settings are the same as the underlying
  [`default_algorithms/0`](http://erlang.org/doc/man/ssh.html#default_algorithms-0)
  function. For information about configuring this complex setting,
  please read the similarily named configuration option within
  the function [`daemon/2`](http://erlang.org/doc/man/ssh.html#daemon-2).
* `priv_dir :: string()`: specifies the location to your own application's
  `priv` directory, or any other directory. This directory is utilized
  for the SSH host keys and is utilized by the
  `Sshd.PublicKeyAuthenticator.AuthorizedKeys` module for both user keys and
  the `authorized_keys` file.
* `public_key_authenticator :: string(Sshd.PublicKeyAuthenticator.Default)`:
  A string containing the fully qualified module that implements
  the `Sshd.PublicKeyAuthenticator` behavior.

## License

Copyright (C) 2017 [Joseph Benden](mailto:joe@benden.us).

Licensed under the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
