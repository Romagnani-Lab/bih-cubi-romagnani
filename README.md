# Romagnani Lab: HPC Cluster Guide

> Last checked against the HPC portal: 2026-08-27

We use the BIH HPC cluster for analyses too big for a laptop. RStudio and JupyterLab run in the browser through the portal: [hpc-portal.cubi.bihealth.org](https://hpc-portal.cubi.bihealth.org). No cluster experience needed.

---

## 1. Get VPN access

The portal is only reachable over the Charité VPN.

1. Fill in and sign both forms, scan them, and email them to **vpn@charite.de**, cc Chiara ([chiara.romagnani@charite.de](mailto:chiara.romagnani@charite.de)):
   - [`01_VPN_antrag.pdf`](vpn/01_VPN_antrag.pdf): standard VPN application
   - [`02_VPN_zusatzantrag_B.pdf`](vpn/02_VPN_zusatzantrag_B.pdf): supplement for HPC access
2. Once approved, install OpenVPN: [macOS](vpn/install_VPN_macOS.pdf), [Windows](vpn/install_VPN_windows.pdf).

Approval can take a few days, so send the forms early.

## 2. Request an HPC account

Send Ollie ([oliver.knight@charite.de](mailto:oliver.knight@charite.de)) these details to pass on to CUBI:

```text
- first name:
- last name:
- affiliation: Charite, Institute of Medical Immunology
- institute email:
- user has account with: Charite
- Charite username:
- AG: ag-romagnani
```

Your cluster username is your Charité username plus `_c`, e.g. `doej_c`.

## 3. One-time setup

Log in to the [portal](https://hpc-portal.cubi.bihealth.org) with your Charité username. Open a terminal via **Clusters → \_cubi Shell Access**, then start a compute session and run the setup script:

```sh
srun --time 4:00:00 --mem 8G --pty bash -i
bash /data/cephfs-2/unmirrored/groups/romagnani/work/bin/bih-cubi-romagnani/first_time_setup.sh
```

It asks before each step:

- move cache and config folders out of your 1 GB home directory
- install [pixi](https://pixi.sh), which manages the R and Python environments
- install the R 4.5.0 environment for RStudio (10–20 min)
- install the reticulate Python environment (Python from R)
- install the Jupyter single-cell environment (scanpy, scvelo; large, skip unless you use JupyterLab)
- install the RStudio and Jupyter portal apps

On a new account, answer **y** to everything except Jupyter if you don't need it. Open a new terminal when it finishes. The script is safe to re-run and leaves environments you've already installed (and any packages you've added) alone.

## 4. RStudio

**Interactive Apps → RStudio Server (Sandbox)**, then:

| Setting | Value |
| --- | --- |
| R environment source | Pixi environment |
| Path to pixi project directory | `~/work/bin/pixi/R_4.5.0` |
| Apptainer image | leave as is |
| CPU cores | 8–16 (max 32) |
| Memory (GB) | 32–64 (max 128) |
| Running time | `1d`, or `3d` for long analyses |
| Partition | medium |

Click **Launch**, wait until it says *Running*, then **Connect to RStudio Server**. Smaller requests start sooner.

Install conda packages from the RStudio terminal (Tools → Terminal → New Terminal):

```sh
pixi add --manifest-path ~/work/bin/pixi/R_4.5.0 r-ggplot2
```

GitHub and Bioconductor packages install from R as usual (`remotes::install_github()`, `BiocManager::install()`).

To call Python from R:

```r
library(reticulate)
use_python("~/work/bin/pixi/r-reticulate/.pixi/envs/default/bin/python", required = TRUE)
```

## 5. JupyterLab

**Interactive Apps → Jupyter**, then:

| Setting | Value |
| --- | --- |
| Python environment source | Pixi environment |
| Path to pixi project directory | `~/work/bin/pixi/jupyter` |
| Jupyter Lab/Notebook | Jupyter Lab |
| Working directory | blank (starts in home) |
| CPU cores | 4–8 |
| Memory (GB) | 16–32 |
| Running time | `1d` |
| Partition | medium |

Click **Launch**, wait for *Running*, then **Connect to Jupyter**.

## 6. Storage

Home is only 1 GB. Keep data out of it.

| Shortcut | Path | Use for | Size | Auto-deleted |
| --- | --- | --- | --- | --- |
| `~/` | `/data/cephfs-1/home/users/<user>` | config, symlinks | 1 GB | no |
| `~/work/` | `/data/cephfs-1/work/groups/romagnani/users/<user>` | software, scripts, results | 1 TB | no |
| `~/scratch/` | `/data/cephfs-1/scratch/groups/romagnani/users/<user>` | pipeline runs, temp files | 10 TB | **after 14 days** |
| `~/group/` | `/data/cephfs-2/unmirrored/groups/romagnani` | shared tools, reference genomes | 10 TB | no |
| `~/share/` | `/data/cephfs-2/unmirrored/projects/romagnani-share` | data shared across projects | 1 TB | no |

Scratch cleanup also deletes empty directories untouched for 14 days. To keep one, add a marker file (files inside still expire as normal):

```sh
touch ~/scratch/path/to/folder/.keepdir
```

## 7. Long-running work

Run interactive work inside `tmux` so it survives closing the browser:

```sh
tmux new -s work
srun --time 48:00:00 --cpus-per-task 16 --mem 64G --pty bash -i
```

Detach with `Ctrl+b` then `d`, re-attach with `tmux a -t work`, list sessions with `tmux ls`.

For jobs that run overnight or for days, submit with `sbatch`. See the [SLURM docs](https://hpc-docs.cubi.bihealth.org/slurm/overview/).

## 8. SSH access (optional)

Useful for file transfers and running pipelines from your own terminal.

<details>
<summary>Setup</summary>

1. Create a key: `ssh-keygen -t ed25519` (default location, set a passphrase).
2. Copy the contents of `~/.ssh/id_ed25519.pub` into [zugang.charite.de](https://zugang.charite.de) → **SSH Keys** → **Append**.
3. Add this to `~/.ssh/config`, replacing `username_c`:

   ```text
   Host cubi
       HostName hpc-login-1.cubi.bihealth.org
       User username_c
       ForwardAgent yes
       ForwardX11 yes

   Host cubi2
       HostName hpc-login-2.cubi.bihealth.org
       User username_c
       ForwardAgent yes
       ForwardX11 yes
   ```

4. Connect with `ssh-add && ssh cubi`.

Login nodes are shared, so don't run analyses on them: start an `srun` session first. Use the transfer nodes for large copies:

```sh
scp file.txt username_c@hpc-transfer-1.cubi.bihealth.org:~/work/
```

</details>

## 9. Troubleshooting

**Portal won't load.** Check the VPN is connected. Some on-site buildings need it too.

**`Permission denied (publickey)` on `ssh cubi`.** Check the key is saved at [zugang.charite.de](https://zugang.charite.de), wait a few minutes, retry.

**`srun` stuck in `PENDING`.** The partition is busy. Ask for fewer cores, less memory or a shorter `--time`. Check with `squeue --me`.

**Setup script says `pixi install` failed.** Usually a network hiccup. Re-run the script.

**`No space left on device` in your home directory.** Move large files to `~/work/` or `~/scratch/`.

## 10. Help

1. [BIH HPC docs](https://hpc-docs.cubi.bihealth.org/)
2. [HPC forum](https://hpc-talk.cubi.bihealth.org/)
3. Ollie: [oliver.knight@charite.de](mailto:oliver.knight@charite.de)
4. HPC helpdesk (accounts, access, hardware): [hpc-helpdesk@bih-charite.de](mailto:hpc-helpdesk@bih-charite.de)
