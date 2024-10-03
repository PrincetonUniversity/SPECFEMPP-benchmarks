import pandas as pd


def post_process(csv_file):
    df = pd.read_csv(csv_file)

    # Group data by nxmax and nzmax
    df_grouped = df.groupby(["nxmax", "nzmax"])
    ## Calculate mean and standard deviation of solver_time
    df_mean = df_grouped["solver_time"].mean().reset_index()
    df_std = df_grouped["solver_time"].std().reset_index()

    ## create a final dataframe
    df_final = pd.DataFrame(
        columns=["nxmax", "nzmax", "solver_time_mean", "solver_time_std"]
    )
    for i, row in df_mean.iterrows():
        df_final = pd.concat(
            [
                df_final,
                pd.DataFrame(
                    {
                        "nxmax": row["nxmax"],
                        "nzmax": row["nzmax"],
                        "solver_time_mean": row["solver_time"],
                        "solver_time_std": df_std[
                            (df_std["nxmax"] == row["nxmax"])
                            & (df_std["nzmax"] == row["nzmax"])
                        ]["solver_time"].values[0],
                    },
                    index=[0],
                ),
            ]
        )

    return df_final


def plot_benchmark(ax, baseline, current, label):
    ax.errorbar(
        baseline["nxmax"] * baseline["nzmax"],
        baseline["solver_time_mean"],
        yerr=baseline["solver_time_std"],
        fmt="o",
        color="black",
        label="SPECFEM2D",
    )

    ax.errorbar(
        current["nxmax"] * current["nzmax"],
        current["solver_time_mean"],
        yerr=current["solver_time_std"],
        fmt="^",
        color="black",
        label="SPECFEM++",
    )

    ax.set_xlabel("Number of elements")
    ax.set_ylabel("Solver time (s)")

    ax.set_xscale("log")
    ax.set_yscale("log")
    # grid on dotted lines. transparency 0.5
    ax.grid(True, which="both", linestyle="--", linewidth=0.5, color="gray", alpha=0.5)

    # ticks inside the plot
    ax.tick_params(axis="both", which="both", direction="in", top=True, right=True)

    ax.legend()
    ## put label on the bottom right corner
    ## wrap the label in a white box
    ## multiple lines can be added
    ax.text(
        0.97,
        0.05,
        label,
        verticalalignment="bottom",
        horizontalalignment="right",
        transform=ax.transAxes,
        fontsize=10,
        bbox=dict(facecolor="white", alpha=0.5),
    )

    return


def plot(ax, baseline_csv, current_csv, label):
    baseline = post_process(baseline_csv)
    current = post_process(current_csv)

    plot_benchmark(ax, baseline, current, label)
