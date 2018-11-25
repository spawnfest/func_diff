defmodule FuncDiffAPI.ComparisonActor do
  @moduledoc """
  Holds state for a comparison (repo + base + target).

  This runs as a `GenServer` so we can cache data and load more
  stuff as requested instead of spending a long time loading
  everything upfront. (#TODO)

  Diff information is cached at 3 levels:

    - `modules_diff` is a list of `{diff_status, module_name}`
    - `module_diff` is a Map key'ed by `module_name`, the value is a list of `{diff_status, func_id}`
    - `func_diff` is a Map key'ed by `{module_name, func_id}`, the value is a "body diff" (list of
    `{diff_state, line}`)

  `diff_status` can be any of `:add`, `:del`, `:common`, `:change`
  `func_id` is function (or macro) name + "/" + arity, both module name and func_id needs to be String.
  """
  use GenServer

  defstruct [
    :runner_git_repo,
    :base_ref,
    :target_ref,
    :mix_file,
    :base_modules,
    :target_modules,
    :modules_diff,
    :module_diff,
    :func_diff
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
    File.mkdir_p!(wd)
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

    base_modules =
      Parser.process(ex_files) |> Enum.map(fn mod -> {mod.name, mod} end) |> Enum.into(%{})

    Runner.Git.checkout(state.runner_git_repo, state.target_ref)
    {ex_files, _erl_files} = Runner.Mix.list_source_files(state.mix_file)

    target_modules =
      Parser.process(ex_files) |> Enum.map(fn mod -> {mod.name, mod} end) |> Enum.into(%{})

    new_state =
      %{
        state
        | base_modules: base_modules,
          target_modules: target_modules,
          modules_diff: [],
          module_diff: %{},
          func_diff: %{}
      }
      |> diff()

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

  ## private functions
  defp diff(state) do
    base_mods =
      state.base_modules
      |> Map.keys()
      |> Enum.into(MapSet.new())

    target_mods =
      state.target_modules
      |> Map.keys()
      |> Enum.into(MapSet.new())

    MapSet.union(base_mods, target_mods)
    |> Enum.reduce(state, fn module_name, state_acc ->
      a = Map.get(state.base_modules, module_name, nil)
      b = Map.get(state.target_modules, module_name, nil)

      diff_module(state_acc, a, b)
    end)
  end

  # added module
  defp diff_module(state, nil, target_module) do
    new_modules_diff = [{:add, target_module.name} | state.modules_diff]

    mod_diff = Enum.map(target_module.defs, fn df -> {:add, df_id(df)} end)
    new_module_diff = Map.put(state.module_diff, target_module.name, mod_diff)

    new_func_diff =
      Enum.map(target_module.defs, fn df ->
        body_diff = Enum.map(df.body, fn line -> {:add, line} end)
        key = {target_module.name, df_id(df)}
        {key, body_diff}
      end)
      |> Enum.into(%{})
      |> Map.merge(state.func_diff)

    %{
      state
      | modules_diff: new_modules_diff,
        module_diff: new_module_diff,
        func_diff: new_func_diff
    }
  end

  # deleted module
  defp diff_module(state, base_module, nil) do
    new_modules_diff = [{:del, base_module.name} | state.modules_diff]

    mod_diff = Enum.map(base_module.defs, fn df -> {:del, df_id(df)} end)
    new_module_diff = Map.put(state.module_diff, base_module.name, mod_diff)

    new_func_diff =
      Enum.map(base_module.defs, fn df ->
        body_diff = Enum.map(df.body, fn line -> {:del, line} end)
        key = {base_module.name, df_id(df)}
        {key, body_diff}
      end)
      |> Enum.into(%{})
      |> Map.merge(state.func_diff)

    %{
      state
      | modules_diff: new_modules_diff,
        module_diff: new_module_diff,
        func_diff: new_func_diff
    }
  end

  # changed/common module
  defp diff_module(state, base_module, target_module) do
    base_defs_map = base_module.defs |> Enum.map(fn df -> {df_id(df), df} end) |> Enum.into(%{})

    target_defs_map =
      target_module.defs |> Enum.map(fn df -> {df_id(df), df} end) |> Enum.into(%{})

    set_a = base_defs_map |> Map.keys() |> MapSet.new()
    set_b = target_defs_map |> Map.keys() |> MapSet.new()

    defs_diff =
      MapSet.union(set_a, set_b)
      |> Enum.map(fn func_id ->
        a = Map.get(base_defs_map, func_id, nil)
        b = Map.get(target_defs_map, func_id, nil)

        diff_body(a, b)
      end)

    mod_status =
      if Enum.all?(defs_diff, fn {status, _, _} -> status == :common end) do
        :common
      else
        :change
      end

    new_modules_diff = [{mod_status, base_module.name} | state.modules_diff]

    mod_diff = Enum.map(defs_diff, fn {status, id, _} -> {status, id} end)
    new_module_diff = Map.put(state.module_diff, base_module.name, mod_diff)

    new_func_diff =
      Enum.map(defs_diff, fn {_, func_id, body_diff} ->
        key = {target_module.name, func_id}
        {key, body_diff}
      end)
      |> Enum.into(%{})
      |> Map.merge(state.func_diff)

    %{
      state
      | modules_diff: new_modules_diff,
        module_diff: new_module_diff,
        func_diff: new_func_diff
    }
  end

  defp diff_body(nil, target_df) do
    body_diff = Enum.map(target_df.body, fn line -> {:add, line} end)
    {:add, df_id(target_df), body_diff}
  end

  defp diff_body(base_df, nil) do
    body_diff = Enum.map(base_df.body, fn line -> {:del, line} end)
    {:del, df_id(base_df), body_diff}
  end

  defp diff_body(base_df, target_df) do
    text_a = Enum.join(base_df.body, "\n")
    text_b = Enum.join(target_df.body, "\n")

    if String.equivalent?(text_a, text_b) do
      body_diff = Enum.map(target_df.body, fn line -> {:common, line} end)
      {:common, df_id(target_df), body_diff}
    else
      body_diff = Runner.Diff.diff(text_a, text_b)
      {:change, df_id(target_df), body_diff}
    end
  end

  defp df_id(df), do: "#{df.name}/#{df.arity}"
end
