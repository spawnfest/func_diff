# FuncDiff

Diff ~~Erlang~~™/Elixir projects by modules and functions (including its doc and typespec) across git branches.

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

Feel free to try it out on any Elixir projects, though it might not always work (it fails on `absinthe` for example). Another example that works is one of my toy project, like this: `new_diff("HaloWordApp/halosir", "46744072915c21bfe1a98b4ffbb0f77ea67ed78c", "2.1.0")`

To use it as a library, check the next section.

## Architecture & Tests

I created the project as an [umbrella project](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html#umbrella-projects) because we're a distributed team and each of us sort of have different areas to focus on.

We started with `runner` for executing external programs like `git` and `diff`, and `parser` for reading Elixir source code to extract modules and functions list.

Then `fd_api` is the integration point of these two underlying parts, it also wraps "execution context" that different parts need in an Erlang Process (I prefer to simply call it "Actor", hence the `FuncDiffAPI.ComparisonActor` name). This also provides a place to introduce caching or lazy loading behaviours (not implemented yet).

Finally `interactive` is an frontend example, basically further wrapping `fd_api` and hide "implementation details" behind the opaque type "token". With the "token" we can access different level of diff in a straightforward way.

The only place we have comprehensive test is `parser`, I relied on those during the refactor into `Parser.Unify`. I later fixed several bugs in diff format parsing as well, I forgot I have a simple test case setup, so in the end just fixed inline, but more test would certainly help.

## Future Ideas & TODOs

Of course there're always more ideas to explore, and we have a few of our own to start with, discussed during the development, and just other random ideas if other people find this project interesting/useful and would like to follow up :)

- parse Erlang code, to be fair this was the original request >,< I tried a few things ([a](https://github.com/efcasado/forms), [b](http://erlang.org/doc/man/epp.html#parse_file-2)) prior but couldn't really figure out how to get rid of preprocessing, mostly because I want a non-intrusive way of parsing another code base. These ref [a](https://stackoverflow.com/questions/28084192/what-am-i-doing-wrong-with-erl-parseparse-form) [b](http://studzien.github.io/hack-vm/part1.html#slide-0) might be useful but for this SpawnFest we decide to start with Elixir first and didn' really have time to look into parsing Erlang code.
- diff module content, we're only looking at source code diff for functions, but modules can also have attributes and even "function body" as well, so it would be more accurate if we can account for module content.
- check for `use`, `use` is a special macro that would inject code from another module's `__using__/1` macro output. The idea here is to track `__using__/1` changes and mark modules that `use` it according to the diff status.
- use `elixirc_paths` and `erlc_paths`, not sure whether this is a sane idea, but I tried anyway (the code is still in `Runner.Mix`). The problem is to account for using a function to source this value instead of literal values, I kinda have to `mix run` within the project, and even though I can provide `"--no-start", "--no-deps-check", "--no-compile"` to disable compiling/running the actual target project code as much as possible, in the end I still need to load the mix configuration. And that proves to be a big problem for example if the project tries to import a "secret" config file that is (correctly) not tracked in the git repo. With `erlc_paths` the issue is it doesn't have "include" paths which I think is important to track for Erlang projects. So for now I'm hardcoding where to search Elixir and Erlang codes.
- arbitary git repo, this is already supported by lower-level functions, just need to expose it in outer interface
- "move" as a diff status, like what `git mv` provides, we thought about maybe checking similarities of AST, but didn't go too far on this front.
- more accurate semver check, even integration into packaging services. We discussed several ideas on what should be count as "public API", one idea is to check whether it's documented with `@moduledoc` and `@doc`, but due to limited time we didn't really work on this. But if we have some solid way to determine public APIs then my idea is to provide the semver requirement like [Elm's packaging ecosystem](https://github.com/elm-lang/elm-package/blob/a8248bb4fa9433a816360b430be24e30be10dcff/README.md#version-rules)
