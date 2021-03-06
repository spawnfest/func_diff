defmodule Runner.Git do
  @moduledoc """
  Operate git repos using `git` CLI in `$PATH`.
  """

  defmodule Repo do
    @moduledoc "Defines struct for git operations."

    @type t :: %__MODULE__{
            working_dir: String.t(),
            local_dir: String.t(),
            remote_addr: String.t(),
            full_path: String.t()
          }
    defstruct [:working_dir, :local_dir, :remote_addr, :full_path]

    @doc """
    Populate the struct from `github_repo`, in the format of "user/repo".

    Accetps addtional keyword `:working_dir`, `:local_dir` in `opts` to further
    customize the struct, otherwise use current directory and repo name as defaults
    respectively.
    """
    def from_github(github_repo, opts \\ []) do
      # basic validation
      [_user, repo] = String.split(github_repo, "/")
      local = Keyword.get(opts, :local_dir, repo)
      work = Keyword.get(opts, :working_dir, ".")

      %__MODULE__{
        remote_addr: "https://github.com/#{github_repo}.git",
        local_dir: local,
        working_dir: work,
        full_path: Path.join(work, local)
      }
    end
  end

  @type result() :: {:ok, String.t()} | {:error, any()}

  @type ref_type() :: :local | :remote | :tag
  @type ref_name() :: String.t()
  @type ref_hash() :: String.t()

  @type git_ref() :: {ref_type(), ref_name(), ref_hash()}

  @doc "Clone a git repo"
  @spec clone(Repo.t()) :: result()
  def clone(%Repo{} = repo) do
    Porcelain.exec(
      "git",
      ["clone", "-q", repo.remote_addr, repo.local_dir],
      dir: repo.working_dir
    )
    |> format_porcelain_result()
  end

  @doc "Pull all remotes of a git repo"
  @spec pull(Repo.t()) :: result()
  def pull(%Repo{} = repo) do
    Porcelain.exec(
      "git",
      ["pull", "--all", "--ff-only", "-q", "--no-stat"],
      dir: repo.full_path
    )
    |> format_porcelain_result()
  end

  @doc "Clone a repo if not locally exist, otherwise pull all remotes"
  @spec clone_or_pull(Repo.t()) :: result()
  def clone_or_pull(%Repo{} = repo) do
    case {File.exists?(repo.full_path), File.dir?(repo.full_path)} do
      {false, false} ->
        clone(repo)
        pull(repo)

      {true, true} ->
        checkout(repo, "master")
        pull(repo)

      _ ->
        {:error, :bad_repo}
    end
  end

  @doc "Checkout a git repo to `target` reference (branch, tag or commit hash)"
  @spec checkout(Repo.t(), ref_hash() | ref_name()) :: result()
  def checkout(%Repo{} = repo, target) do
    Porcelain.exec(
      "git",
      ["checkout", "-q", target],
      dir: repo.full_path
    )
    |> format_porcelain_result()
  end

  @doc "List references to checkout to, including local/remote branches and tags"
  @spec list_references(Repo.t()) :: list(git_ref())
  def list_references(%Repo{} = repo) do
    %Porcelain.Result{out: out} = Porcelain.exec("git", ["show-ref"], dir: repo.full_path)

    out
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      [hash, "refs/" <> ref_detail] = String.split(line)

      case String.split(ref_detail, "/", parts: 2) do
        ["heads", name] ->
          [{:local, name, hash}]

        ["remotes", name] ->
          [{:remote, name, hash}]

        ["tags", name] ->
          [{:tag, name, hash}]

        _ ->
          []
      end
    end)
  end

  @spec format_porcelain_result(any()) :: result()
  defp format_porcelain_result(result) do
    case result do
      %Porcelain.Result{status: 0, out: out} ->
        {:ok, out}

      %Porcelain.Result{err: err} ->
        {:error, err}

      _ ->
        {:error, :unknown}
    end
  end
end
