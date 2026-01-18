import argparse
import random
import string
import os
from docker import from_env
import docker 
from pathlib import Path

script_dir=Path(__file__).resolve().parent
    
def generate_password(length=64):
    """Generate a random password."""
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

def find_free_port():
    """Find a free port for forwarding that is not 3306."""
    import socket
    while True:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', 0))
            port = s.getsockname()[1]
            if port != 3306:
                return port

def create_my_cnf(env_name, username, password, host="127.0.0.1", port=3306):
    """Create a .my.cnf file for easy connection."""
    config_content = f"""[client]
user={username}
password={password}
host={host}
port={port}
"""
    file_path = f"{env_name}.my.cnf"
    with open(file_path, 'w') as f:
        f.write(config_content)
    os.chmod(file_path, 0o600)  # Secure permissions
    print("ℹ️ ", f"Configuration file generated: {file_path}")

def generate_bash_alias(env_name, port, password):
    """Generate useful Bash aliases for a MySQL environment."""
    exporte = f"export MYSQL_DEFAULTS_FILE_{env_name}={script_dir}/{env_name}.my.cnf"
    aliases = [
        f"alias {env_name}='docker exec -it {env_name} mysql -uroot -p\"{password}\"'",
        f"alias {env_name}c='docker exec -i {env_name} mysql -uroot -p\"{password}\"'",
        f"alias {env_name}dump='docker exec -it {env_name} mysqldump -uroot -p\"{password}\"'",
        f"alias {env_name}flush='docker exec -it {env_name} mysql -uroot -p\"{password}\" -e \"FLUSH PRIVILEGES;\"'",
        f"alias {env_name}dblist='docker exec -it {env_name} mysql -uroot -p\"{password}\" -e \"SHOW DATABASES;\"'",
        f"alias {env_name}sh='docker exec -it {env_name} bash'",
        f"alias {env_name}logs='docker logs {env_name}'",
        f"alias {env_name}stop='docker stop {env_name}'",
        f"alias {env_name}start='docker start {env_name}'",
    ]

    bashrc_path = "mysql.bashrc"
    with open(bashrc_path, 'a') as f:
        f.write(f"{exporte}\n")
        for alias in aliases:
            f.write(f"{alias}\n")
        f.write("\n")

    print(f"Aliases added to {bashrc_path}:")
    for alias in aliases:
        print(f"  {alias}")

def launch_container(env_name, db_type, version, username, password, debug=False):
    version = version or 'latest'
    """Launch a Docker container for MySQL/MariaDB."""
    if debug:
      print("🐞 Debug: Initializing Docker client")
    docker_client = from_env()

    image = f"{db_type}:{version}"
    port = find_free_port()
    container_name = env_name
    if debug:
        print(f"🐞 Debug: Checking if container '{container_name}' exists")
    try:
        container = docker_client.containers.get(container_name)
        if container.status == "running":
          print(f"Container {container_name} is already running.")
        else:
            if debug:
                print(f"🐞 Debug: Starting container '{container_name}'")
            container.start()
            print(f"Container {container_name} started successfully.")
        return    
    except docker.errors.NotFound:
      print(f"{container_name} not found")
    except e:
      print(f"Erreur: {e}")
      return
 
    if debug:
        print(f"🐞 Debug: Container '{container_name}' not found, attempting to run a new container")
    password = password or generate_password()
    try:
        if debug:
            print(f"🐞 Debug: Running container with image '{image}', name '{container_name}', port '{port}'")
        container = docker_client.containers.run(
            image,
            detach=True,
            name=container_name,
            ports={'3306/tcp': port},
            environment={
                "MYSQL_ROOT_PASSWORD": password,
                "MYSQL_USER": username,
                "MYSQL_PASSWORD": password,
                "MYSQL_DATABASE": f"{env_name}_db"
            }
        )
        print(f"Container {db_type} v{version} launched successfully!")
        print(f"Container name: {container_name}")
        print(f"Access port: {port}")
    except docker.errors.ImageNotFound as e:
        print(f"Image Not Found '{version}': {e}")
        return
    except Exception as e:
        print(f"Error launching container: {e}")
    
    if 'container' in locals() and container:
        if 'container' in locals() and container:
            create_my_cnf(env_name, username, password, port=port)
            generate_bash_alias(env_name, port, password)

def stop_container(env_name, debug=False):
    """Stop a Docker container."""
    docker_client = from_env()
    container_name = env_name

    try:
        container = docker_client.containers.get(container_name)
        container.stop()
        print(f"Container {container_name} stopped successfully.")
    except Exception as e:
        print(f"Error stopping container: {e}")

def remove_environment(env_name, debug=False):
    """Remove Docker container, image, .my.cnf file, and alias for the given environment."""
    docker_client = from_env()
    container_name = env_name
    my_cnf_path = f"{env_name}.my.cnf"
    bashrc_path = "mysql.bashrc"

    # Remove container
    try:
        container = docker_client.containers.get(container_name)
        container.remove(force=True)
        print(f"Container {container_name} removed successfully.")
    except Exception as e:
        print(f"Error removing container: {e}")

    # Remove image
    try:
        image_name = f"{container.image.tags[0]}"
        docker_client.images.remove(image=image_name, force=True)
        print(f"Image {image_name} removed successfully.")
    except Exception as e:
        print(f"Error removing image: {e}")

    # Remove .my.cnf file
    if os.path.exists(my_cnf_path):
        os.remove(my_cnf_path)
        print(f"Configuration file {my_cnf_path} removed successfully.")
    else:
        print(f"Configuration file {my_cnf_path} does not exist.")

    # Remove alias from bashrc
    try:
        if os.path.exists(bashrc_path):
            with open(bashrc_path, 'r') as f:
                lines = f.readlines()
            with open(bashrc_path, 'w') as f:
                for line in lines:
                    if f"{env_name}" not in line and line.strip():
                        f.write(line)
            # If the bashrc file is now empty, delete it
            if os.path.getsize(bashrc_path) == 0:
                os.remove(bashrc_path)
                print(f"{bashrc_path} was empty and has been removed.")
            else:
                print(f"Alias for {env_name} removed from {bashrc_path}.")
    except Exception as e:
        print(f"Error removing alias: {e}")
    except Exception as e:
        print(f"Error removing alias: {e}")

def list_containers(status_filter=None, debug=False):
    """List all active Docker containers."""
    docker_client = from_env()
    try:
        containers = docker_client.containers.list(all=True)
    except Exception as e:
        print(f"Error retrieving container list: {e}")
        return
    data = []
    for container in containers:
        if status_filter and container.status != status_filter:
            continue
        try:
            image = container.image.tags[0] if container.image.tags else "<none>"
        except Exception:
            image = "<image not found>"
        if any(db in image.lower() for db in ["mysql", "mariadb", "percona"]):
            name = container.name
            status = "Running" if container.status == "running" else "Stopped"
            port_bindings = container.attrs['NetworkSettings']['Ports']
            if '3306/tcp' in port_bindings and port_bindings['3306/tcp']:
                host_port = port_bindings['3306/tcp'][0]['HostPort']
            else:
                host_port = "<none>"
            data.append([name, image, host_port, status])

    # Print the results as a table
    headers = ["Name", "Image", "HostPort", "Status"]
    column_widths = [max(len(str(row[i])) for row in data) for i in range(len(headers))] if data else [len(header) for header in headers]
    column_widths = [max(len(header), width) for header, width in zip(headers, column_widths)]

    def format_row(row):
        return "  ".join(str(value).ljust(width) for value, width in zip(row, column_widths))

    # Print header
    print(format_row(headers))
    print("  ".join("=" * width for width in column_widths))

    # Print rows
    for row in data:
        print(format_row(row))

def main(debug=False):
    parser = argparse.ArgumentParser(description="Manage MySQL/MariaDB containers.")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Command to list environments
    list_parser = subparsers.add_parser("list", help="List all active environments.")
    list_parser.add_argument("--status", choices=["running", "stopped"], help="Filter by container status.")

    # Command to start a container
    start_parser = subparsers.add_parser("start", help="Start a new container.")
    start_parser.add_argument("env_name", type=str, help="Logical name of the environment.")
    start_parser.add_argument("--db_type", choices=["mysql", "mariadb", "percona"], default="mysql", help="Database type.")
    start_parser.add_argument("--version", type=str, default="latest", help="Database version.")
    start_parser.add_argument("--username", type=str, default="admin", help="Username.")
    start_parser.add_argument("--password", type=str, help="Password (automatically generated if not provided).")

    # Command to stop a container
    stop_parser = subparsers.add_parser("stop", help="Stop a container.")
    stop_parser.add_argument("env_name", type=str, help="Name of the environment to stop.")

    # Command to remove an environment
    rm_parser = subparsers.add_parser("rm", help="Remove an environment.")
    rm_parser.add_argument("env_name", type=str, help="Name of the environment to remove.")

    # Command to generate useful information
    info_parser = subparsers.add_parser("info", help="Generate useful information.")
    info_parser.add_argument("env_name", type=str, help="Name of the environment.")
    info_parser.add_argument("port", type=int, help="Port used for the environment.")
    info_parser.add_argument("--username", type=str, default="admin", help="Username.")
    info_parser.add_argument("--password", type=str, required=True, help="Password.")

    parser.add_argument('--debug', action='store_true', help='Enable debug mode for detailed information')
    args = parser.parse_args()

    if args.debug:
        print("🐞 Debug: Arguments received -", vars(args))
    if args.command == "list":
        list_containers(status_filter=args.status, debug=args.debug)
    elif args.command == "start":
        launch_container(args.env_name, args.db_type, args.version, args.username, args.password, debug=args.debug)
    elif args.command == "stop":
        stop_container(args.env_name, debug=args.debug)
    elif args.command == "rm":
        remove_environment(args.env_name, debug=args.debug)
    elif args.command == "info":
        create_my_cnf(args.env_name, args.username, args.password, port=args.port)
        generate_bash_alias(args.env_name, args.port)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
