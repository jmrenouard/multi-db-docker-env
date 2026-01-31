import unittest
import subprocess
import os
import sys

# --- Database Laboratory Features & Parameters Validation ---

class TestDatabaseLab(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.db_root_password = os.getenv("DB_ROOT_PASSWORD", "votre_mot_de_passe_super_secret")

    def run_mysql_query(self, query):
        """Executes a SQL query against a running container via Traefik (localhost:3306)."""
        cmd = [
            "mysql",
            "-uroot",
            f"-p{self.db_root_password}",
            "-h127.0.0.1",
            "-P3306",
            "-e", query,
            "--skip-column-names",
            "--batch"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result

    def run_pg_query(self, query):
        """Executes a SQL query against a running PostgreSQL container via Traefik (localhost:5432)."""
        env = os.environ.copy()
        env["PGPASSWORD"] = self.db_root_password
        cmd = [
            "psql",
            "-h", "127.0.0.1",
            "-p", "5432",
            "-U", "postgres",
            "-c", query,
            "-t", "-A"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        return result

    def test_version(self):
        """Check if the active database version is correctly reported."""
        # Try MySQL first
        res = self.run_mysql_query("SELECT VERSION()")
        if res.returncode == 0:
            print(f"\n✅ MySQL Version detected: {res.stdout.strip()}")
            return

        # Try PostgreSQL
        res = self.run_pg_query("SELECT version();")
        if res.returncode == 0:
            print(f"\n✅ PostgreSQL Version detected: {res.stdout.strip()}")
            return
        
        self.fail(f"Could not detect any database version on 3306 or 5432.\nMySQL Error: {res.stderr}")

    def test_employees_schema(self):
        """Check if 'employees' database is present and has data (MySQL only)."""
        if self.run_mysql_query("SELECT 1").returncode != 0:
            self.skipTest("Not a MySQL-compatible engine")
        
        # Special case for mysql96: we skip employees injection in Makefile, so we skip test here too
        # In fact, we can check if the DB exists
        res = self.run_mysql_query("SHOW DATABASES LIKE 'employees'")
        if "employees" not in res.stdout:
             self.skipTest("'employees' database not found (likely skipped during injection)")

        res = self.run_mysql_query("SELECT COUNT(*) FROM employees.employees")
        self.assertEqual(res.returncode, 0, f"Query failed: {res.stderr}")
        count = int(res.stdout.strip())
        self.assertGreater(count, 0)
        print(f"✅ 'employees' count: {count}")

    def test_sakila_schema(self):
        """Check if 'sakila' database is present and has data (MySQL only)."""
        if self.run_mysql_query("SELECT 1").returncode != 0:
            self.skipTest("Not a MySQL-compatible engine")

        res = self.run_mysql_query("SELECT COUNT(*) FROM sakila.actor")
        self.assertEqual(res.returncode, 0, f"Query failed: {res.stderr}")
        count = int(res.stdout.strip())
        self.assertGreater(count, 0)
        print(f"✅ 'sakila' actor count: {count}")

    def test_performance_schema_basics(self):
        """Verify performance_schema is enabled (MySQL only)."""
        if self.run_mysql_query("SELECT 1").returncode != 0:
            self.skipTest("Not a MySQL-compatible engine")

        res = self.run_mysql_query("SHOW VARIABLES LIKE 'performance_schema'")
        self.assertEqual(res.returncode, 0)
        self.assertIn("ON", res.stdout)
        print("✅ performance_schema is ON")

    def test_performance_schema_history(self):
        """Verify Performance Schema history sizes (MySQL only)."""
        if self.run_mysql_query("SELECT 1").returncode != 0:
            self.skipTest("Not a MySQL-compatible engine")
        
        # History size per thread
        res = self.run_mysql_query("SHOW VARIABLES LIKE 'performance_schema_events_transactions_history_size'")
        self.assertEqual(res.returncode, 0)
        parts = res.stdout.strip().split()
        if len(parts) >= 2:
            val = int(parts[1])
            self.assertTrue(val >= 1024, f"History size too low: {val}")
            print(f"✅ performance_schema_events_transactions_history_size is {val}")
        else:
             print(f"⚠️ Could not parse history size output: {res.stdout.strip()}")

        # Global history size
        res = self.run_mysql_query("SHOW VARIABLES LIKE 'performance_schema_events_transactions_history_long_size'")
        self.assertEqual(res.returncode, 0)
        parts = res.stdout.strip().split()
        if len(parts) >= 2:
            val = int(parts[1])
            self.assertTrue(val >= 10000, f"Long history size too low: {val}")
            print(f"✅ performance_schema_events_transactions_history_long_size is {val}")

    def test_performance_schema_consumers(self):
        """Verify Performance Schema consumers (MySQL only)."""
        if self.run_mysql_query("SELECT 1").returncode != 0:
            self.skipTest("Not a MySQL-compatible engine")
        
        res = self.run_mysql_query("SELECT enabled FROM performance_schema.setup_consumers WHERE NAME = 'events_transactions_history'")
        self.assertEqual(res.returncode, 0)
        self.assertIn("YES", res.stdout)
        print("✅ Consumer events_transactions_history is enabled")

        res = self.run_mysql_query("SELECT enabled FROM performance_schema.setup_consumers WHERE NAME = 'events_transactions_history_long'")
        self.assertEqual(res.returncode, 0)
        self.assertIn("YES", res.stdout)
        print("✅ Consumer events_transactions_history_long is enabled")

if __name__ == '__main__':
    unittest.main()
