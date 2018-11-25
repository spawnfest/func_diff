# FuncDiff

Diff ~~Erlang~~™/Elixir projects by modules and functions (across git branches).

## Backstory

My desire for this tool comes from the painful experience of upgrading our forked `ejabberd` code base (to follow up on upstream changes). On top of using the provided extension mechanism ([hooks](https://docs.ejabberd.im/developer/guide/#hooks) and [modules](https://docs.ejabberd.im/developer/extending-ejabberd/modules/)) we still have some deep modification of some internal functions. The vanilla `diff` (or `git diff`) experience is not very helpful in helping me to figure out what changes I should take extra care of, and what changes I can "safely ignore".

So I thought if a tool can diff the project by modules and functions, I can have a much better time reviewing the change and focus on smaller pieces instead of drowing in ocean of changes, especially for large-scale open source projects like `ejabberd`, where every version carries nontrivial amount of changes. And [so borns this project idea](https://twitter.com/aquarhead/status/1046799171091615744) :p

Since another team member has previously worked with Elixir's AST, I figured we have a decent chance to pull it off (at least the Elixir part). And indeed after a relatively intense 40+ hours hacking we now have a workable interface, which covers most common cases, able to analyse (only Elixir) community standard libraries like [Plug](https://twitter.com/aquarhead/status/1066788283835981824), even check whether the changes between versions follows [Semantic Versioning](https://semver.org/) or not!

In short, I'm pretty happy with what we've done so far, and learnt a lot during the time. Hopefully this project or idea is also helpful to someone else, and we do have some ideas on what it can be extended into in the final section of this README.

Happy FuncDiff'ing!

## Build & External Dependencies

This is a standard Elixir project, so building it is no more than a `git clone` followed by `mix compile`.

However it does rely on a few external dependencies, namely `git` and `diff` command to be available in `$PATH` when executing the app.

Also, note that when executing `git` operations the app will use a temporary location, by default this is set to `~/func_diff`, this is configurable in `apps/fd_api/config/config.exs`. And it's always safe to delete this entire folder, so don't panic!

## Use Interactively

We provide an "interactive" (as in through interactive Elixir) interface for now. I tried using Scenic but [quit due to technical issues](https://github.com/spawnfest/func_diff/commit/657d005044a6743f367a8cc920802cdc83c54cfb), and didn't bother with a web interface due to limited time, anyway it also makes the project relies on less dependencies (actually only 1 hex package).

To use this interface, go into `apps/interactive`, and run `iex -S mix`.

I recommend importing the interface module, so calling functions are a bit easier. We provide a help function for brave explorers, like this:

```
import Interactive; func_diff_help()
```

Or if you don't like RTFM you can also try this quickstart:

```
import Interactive

t = new_diff("elixir-plug/plug", "v1.6.0", "v1.7.0")

modules(t)

module(t, "Plug.Builder")

func(t, "Plug.Builder", "traverse/2")

semver_check(t)
```

To use it as a library, check the next section.

## Architecture & Tests

I created the project as an [umbrella project](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html#umbrella-projects) because we're a distributed team and each of us sort of have different areas to focus on.

We started with `runner` for executing external programs like `git` and `diff`, and `parser` for reading Elixir source code to extract modules and functions list.

Then `fd_api` is the integration point of these two underlying parts, it also wraps "execution context" that different parts need in an Erlang Process (I prefer to simply call it "Actor", hence the `FuncDiffAPI.ComparisonActor` name). This also provides a place to introduce caching or lazy loading behaviours (not implemented yet).

Finally `interactive` is an frontend example, basically further wrapping `fd_api` and hide "implementation details" behind the opaque type "token". With the "token" we can access different level of diff in a straightforward way.

## Further Ideas & TODOs

- Erlang code
- module content diff
- more accurate semver check, integration into packaging services
- `use`

- `elixirc_paths`

- arbitary git repo, this is already supported by lower-level functions, just need to expose it in outer interface
