#!/usr/bin/env python3
"""
SSH Client for E2E Testing

Handles SSH connections and command execution on test VMs.
"""

import time
import socket
import logging
from typing import Tuple, Optional, List
from pathlib import Path

import paramiko
from paramiko import SSHClient, AutoAddPolicy, AuthenticationException


class TestSSHClient:
    """SSH client wrapper for test automation"""

    def __init__(self, hostname: str = "localhost", port: int = 22, username: str = "testuser",
                 password: str = None, key_path: str = None, timeout: int = 30):
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.key_path = key_path
        self.timeout = timeout
        self.client: Optional[SSHClient] = None

        # Set up logging
        self.logger = logging.getLogger(f"ssh_client_{hostname}_{port}")

    def connect(self, max_retries: int = 10, retry_delay: int = 5) -> bool:
        """Connect to SSH server with retries"""
        self.client = SSHClient()
        self.client.set_missing_host_key_policy(AutoAddPolicy())

        for attempt in range(max_retries):
            try:
                # Try key-based authentication first
                if self.key_path and Path(self.key_path).exists():
                    self.client.connect(
                        hostname=self.hostname,
                        port=self.port,
                        username=self.username,
                        key_filename=self.key_path,
                        timeout=self.timeout
                    )
                # Fall back to password authentication
                elif self.password:
                    self.client.connect(
                        hostname=self.hostname,
                        port=self.port,
                        username=self.username,
                        password=self.password,
                        timeout=self.timeout
                    )
                else:
                    raise ValueError("Either password or key_path must be provided")

                self.logger.info(f"SSH connection established to {self.hostname}:{self.port}")
                return True

            except (socket.timeout, socket.error, AuthenticationException,
                   paramiko.ssh_exception.NoValidConnectionsError) as e:
                self.logger.warning(f"SSH connection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                continue

        self.logger.error(f"Failed to establish SSH connection after {max_retries} attempts")
        return False

    def execute_command(self, command: str, timeout: int = None,
                       capture_output: bool = True) -> Tuple[int, str, str]:
        """Execute command via SSH and return exit code, stdout, stderr"""
        if not self.client:
            raise RuntimeError("SSH client not connected")

        if timeout is None:
            timeout = self.timeout

        try:
            self.logger.debug(f"Executing command: {command}")
            stdin, stdout, stderr = self.client.exec_command(
                command,
                timeout=timeout,
                get_pty=True  # Get pseudo-terminal for better output handling
            )

            if capture_output:
                stdout_data = stdout.read().decode('utf-8', errors='replace')
                stderr_data = stderr.read().decode('utf-8', errors='replace')
            else:
                stdout_data = ""
                stderr_data = ""

            exit_code = stdout.channel.recv_exit_status()

            self.logger.debug(f"Command exit code: {exit_code}")
            if stdout_data:
                self.logger.debug(f"Command stdout: {stdout_data[:500]}...")
            if stderr_data:
                self.logger.debug(f"Command stderr: {stderr_data[:500]}...")

            return exit_code, stdout_data, stderr_data

        except socket.timeout:
            self.logger.error(f"Command timed out after {timeout} seconds: {command}")
            return -1, "", "Command timed out"
        except Exception as e:
            self.logger.error(f"Error executing command '{command}': {e}")
            return -1, "", str(e)

    def execute_command_stream(self, command: str, timeout: int = None):
        """Execute command and yield output lines as they come"""
        if not self.client:
            raise RuntimeError("SSH client not connected")

        if timeout is None:
            timeout = self.timeout

        try:
            self.logger.debug(f"Executing streaming command: {command}")
            stdin, stdout, stderr = self.client.exec_command(
                command,
                timeout=timeout,
                get_pty=True
            )

            # Set channels to non-blocking
            stdout.channel.settimeout(1.0)
            stderr.channel.settimeout(1.0)

            stdout_buffer = ""
            stderr_buffer = ""

            while not stdout.channel.exit_status_ready():
                # Read stdout
                try:
                    chunk = stdout.channel.recv(1024).decode('utf-8', errors='replace')
                    if chunk:
                        stdout_buffer += chunk
                        lines = stdout_buffer.split('\n')
                        for line in lines[:-1]:  # Yield complete lines
                            yield 'stdout', line
                        stdout_buffer = lines[-1]  # Keep partial line
                except socket.timeout:
                    pass

                # Read stderr
                try:
                    chunk = stderr.channel.recv(1024).decode('utf-8', errors='replace')
                    if chunk:
                        stderr_buffer += chunk
                        lines = stderr_buffer.split('\n')
                        for line in lines[:-1]:  # Yield complete lines
                            yield 'stderr', line
                        stderr_buffer = lines[-1]  # Keep partial line
                except socket.timeout:
                    pass

            # Read any remaining output
            while True:
                try:
                    chunk = stdout.channel.recv(1024).decode('utf-8', errors='replace')
                    if not chunk:
                        break
                    stdout_buffer += chunk
                    lines = stdout_buffer.split('\n')
                    for line in lines[:-1]:
                        yield 'stdout', line
                    stdout_buffer = lines[-1]
                except socket.timeout:
                    break

            # Yield any remaining buffer content
            if stdout_buffer.strip():
                yield 'stdout', stdout_buffer.strip()
            if stderr_buffer.strip():
                yield 'stderr', stderr_buffer.strip()

            exit_code = stdout.channel.recv_exit_status()
            yield 'exit_code', exit_code

        except Exception as e:
            self.logger.error(f"Error executing streaming command '{command}': {e}")
            yield 'error', str(e)

    def upload_file(self, local_path: str, remote_path: str) -> bool:
        """Upload file to remote server"""
        if not self.client:
            raise RuntimeError("SSH client not connected")

        try:
            sftp = self.client.open_sftp()
            sftp.put(local_path, remote_path)
            sftp.close()
            self.logger.info(f"Uploaded {local_path} to {remote_path}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to upload {local_path}: {e}")
            return False

    def download_file(self, remote_path: str, local_path: str) -> bool:
        """Download file from remote server"""
        if not self.client:
            raise RuntimeError("SSH client not connected")

        try:
            sftp = self.client.open_sftp()
            sftp.get(remote_path, local_path)
            sftp.close()
            self.logger.info(f"Downloaded {remote_path} to {local_path}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to download {remote_path}: {e}")
            return False

    def file_exists(self, remote_path: str) -> bool:
        """Check if file exists on remote server"""
        if not self.client:
            raise RuntimeError("SSH client not connected")

        try:
            sftp = self.client.open_sftp()
            sftp.stat(remote_path)
            sftp.close()
            return True
        except FileNotFoundError:
            return False
        except Exception as e:
            self.logger.error(f"Error checking file {remote_path}: {e}")
            return False

    def wait_for_service(self, service_name: str, timeout: int = 60) -> bool:
        """Wait for a service to become active"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            exit_code, _, _ = self.execute_command(
                f"systemctl is-active {service_name}",
                timeout=10
            )
            if exit_code == 0:
                return True
            time.sleep(2)
        return False

    def wait_for_network(self, timeout: int = 60) -> bool:
        """Wait for network connectivity"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            exit_code, _, _ = self.execute_command(
                "ping -c 1 8.8.8.8",
                timeout=10
            )
            if exit_code == 0:
                return True
            time.sleep(2)
        return False

    def is_connected(self) -> bool:
        """Check if SSH connection is active"""
        if not self.client:
            return False

        try:
            # Send a simple command to test connection
            transport = self.client.get_transport()
            return transport and transport.is_active()
        except Exception:
            return False

    def close(self) -> None:
        """Close SSH connection"""
        if self.client:
            try:
                self.client.close()
                self.logger.info("SSH connection closed")
            except Exception as e:
                self.logger.error(f"Error closing SSH connection: {e}")
            finally:
                self.client = None

    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()