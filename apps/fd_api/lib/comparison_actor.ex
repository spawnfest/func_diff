defmodule FuncDiffAPI.ComparisonActor do
  @moduledoc """
  Holds state for a comparison (repo + base + target).

  This runs as a `GenServer` so we can cache data and load more
  stuff as requested instead of spending a long time loading
  everything upfront.
  """
  use GenServer

  defstruct [
    :runner_git_repo,
    :base_ref,
    :target_ref,
    :mix_file,
    :base_modules,
    :target_modules
  ]

  ## APIs

  @doc """
  Start a new comparison. Accept keyword as `opts`:

    - `github`: specify a repo on github, in the format of `user/repo`
    - `git`: specify a raw git remote address, overrides `github` (TODO)
    - `base_ref`: a git ref (branch, tag, commit hash) as comparison base
    - `target_ref`: a git ref to be compared against `base_ref`
  """
  def start_link([github: _github, base_ref: _base, target_ref: _target] = opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def start_link(_), do: {:error, :missing_opts}

  def async_status(ca_pid) do
    GenServer.cast(ca_pid, {:status, self()})
  end

  def get_state(ca_pid) do
    GenServer.call(ca_pid, :get_state)
  end

  @impl true
  def init(github: github, base_ref: base, target_ref: target) do
    wd = Application.get_env(:fd_api, :working_dir)
    r = Runner.Git.Repo.from_github(github, working_dir: wd)

    init_state = %__MODULE__{
      runner_git_repo: r,
      base_ref: base,
      target_ref: target,
      mix_file: Path.join(r.full_path, "mix.exs")
    }

    {:ok, init_state, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state) do
    Runner.Git.clone_or_pull(state.runner_git_repo)

    Runner.Git.checkout(state.runner_git_repo, state.base_ref)
    {ex_files, _erl_files} = Runner.Mix.list_source_files(state.mix_file)
    base_modules = Parser.process(ex_files)

    Runner.Git.checkout(state.runner_git_repo, state.target_ref)
    {ex_files, _erl_files} = Runner.Mix.list_source_files(state.mix_file)
    target_modules = Parser.process(ex_files)

    new_state = %{
      state
      | base_modules: base_modules,
        target_modules: target_modules
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:status, reply_pid}, state) do
    # Using handle_continue ensures the actor is ready when handling further messages
    Process.send(reply_pid, :ready, [])
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end
end
