defmodule Runner.Git do
  @moduledoc false

  defmodule Repo do
    defstruct [:working_dir, :local_dir, :remote_addr]

    def from_github(github_repo, opts \\ []) do
      # basic validation
      [user, repo] = String.split(github_repo, "/")

      %__MODULE__{
        remote_addr: "https://github.com/#{github_repo}.git",
        local_dir: Keyword.get(opts, :local_dir, repo),
        working_dir: Keyword.get(opts, :working_dir, ".")
      }
    end
  end

  def clone_git_repo(%Repo{} = repo) do
    Porcelain.exec("git", ["clone", "-q", repo.remote_addr, repo.local_dir],
      dir: repo.working_dir
    )
    |> format_porcelain_result()
  end

  def git_checkout(%Repo{} = repo, target) do
    Porcelain.exec("git", ["checkout", target], dir: repo.working_dir)
    |> format_porcelain_result()
  end

  defp format_porcelain_result(result) do
    case result do
      %Porcelain.Result{status: 0} ->
        :ok

      %Porcelain.Result{err: err} ->
        {:error, err}

      _ ->
        {:error, :unknown}
    end
  end
end
