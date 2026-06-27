import subprocess
import sys
from datetime import datetime
from pathlib import Path

from airflow.sdk import DAG, task

PROJECT_ROOT = Path("/opt/airflow")
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
DBT_DIR = PROJECT_ROOT / "dbt"
DBT_PROFILE = "enterprise_dw"

DEFAULT_ARGS = {
    "owner":           "ikidevs",
    "depends_on_past": False,
}


def _run(script: str, *args: str) -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPTS_DIR / script), *args],
        capture_output=True, text=True,
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    result.check_returncode()


def _dbt(*args: str) -> None:
    result = subprocess.run(
        ["dbt", *args, "--profiles-dir",
            str(DBT_DIR), "--profile", DBT_PROFILE],
        cwd=str(DBT_DIR), capture_output=True, text=True,
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    result.check_returncode()


with DAG(
    dag_id="multi_subsidiary_enterprise_dw",
    schedule=None,
    start_date=datetime(2026, 6, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["enterprise", "edw", "multi-subsidiary"],
) as dag:

    @task
    def generate_source_files():
        for script in ["generate_sub_a.py", "generate_sub_b.py", "generate_sub_c.py",
                       "generate_sub_d.py", "generate_sub_e.py"]:
            _run(script)
        print("[OK] Source files generated.")

    @task
    def generate_seeds():
        try:
            _run("generate_seeds.py")
        except subprocess.CalledProcessError:
            print("[WARN] Live rates failed — retrying with --fallback ...")
            _run("generate_seeds.py", "--fallback")
        print("[OK] Seed CSVs ready.")

    @task
    def load_init_snowflake():
        _run("load_init_snowflake.py")
        print("[OK] Snowflake init complete.")

    @task
    def load_bronze_data():
        _run("load_bronze.py")
        print("[OK] Bronze loaded.")

    @task
    def run_metadata_ingestion():
        _run("metadata_ingestion_engine.py")
        print("[OK] Metadata ingestion complete.")

    @task
    def dbt_deps():
        _dbt("deps")

    @task
    def dbt_seed():
        _dbt("seed", "--full-refresh")

    @task
    def dbt_run_staging():
        _dbt("run", "--select", "staging")

    @task
    def dbt_run_integration():
        _dbt("run", "--select", "integration")

    @task
    def dbt_run_marts():
        _dbt("run", "--select", "marts")

    @task
    def dbt_test():
        _dbt("test")

    t_generate = generate_source_files()
    t_seeds = generate_seeds()
    t_init = load_init_snowflake()
    t_bronze = load_bronze_data()
    t_ingest = run_metadata_ingestion()
    t_deps = dbt_deps()
    t_seed = dbt_seed()
    t_staging = dbt_run_staging()
    t_integration = dbt_run_integration()
    t_marts = dbt_run_marts()
    t_test = dbt_test()

    # t_generate and t_seeds run in parallel — seeds don't need sub data
    [t_generate, t_seeds] >> t_init >> t_bronze >> t_ingest >> t_deps >> t_seed >> t_staging >> t_integration >> t_marts >> t_test
