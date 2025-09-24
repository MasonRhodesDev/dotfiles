#!/usr/bin/env python3
"""
Console Monitor for E2E Testing

Captures and analyzes console output for error detection and test validation.
"""

import re
import time
import logging
import threading
from typing import List, Dict, Callable, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime
from queue import Queue, Empty


@dataclass
class LogEntry:
    """Represents a single log entry"""
    timestamp: datetime
    source: str  # 'stdout', 'stderr', 'system'
    content: str
    level: str = 'info'  # 'debug', 'info', 'warning', 'error'


@dataclass
class ErrorPattern:
    """Error detection pattern"""
    pattern: re.Pattern
    severity: str  # 'warning', 'error', 'fatal'
    description: str
    stop_on_match: bool = False


@dataclass
class SuccessPattern:
    """Success detection pattern"""
    pattern: re.Pattern
    description: str
    required: bool = False


class ConsoleMonitor:
    """Monitors console output and detects errors/success patterns"""

    def __init__(self, test_name: str, config: Dict[str, Any]):
        self.test_name = test_name
        self.config = config
        self.logger = logging.getLogger(f"console_monitor_{test_name}")

        # Log storage
        self.log_entries: List[LogEntry] = []
        self.log_queue = Queue()

        # Pattern matching
        self.error_patterns = self._compile_error_patterns()
        self.success_patterns = self._compile_success_patterns()

        # State tracking
        self.errors_found: List[Dict] = []
        self.successes_found: List[Dict] = []
        self.is_monitoring = False
        self.monitor_thread: Optional[threading.Thread] = None

        # Callbacks
        self.error_callbacks: List[Callable] = []
        self.success_callbacks: List[Callable] = []

    def _compile_error_patterns(self) -> List[ErrorPattern]:
        """Compile error detection patterns from config"""
        patterns = []
        error_config = self.config.get('error_patterns', [])

        # Default error patterns
        default_patterns = [
            (r'Error:', 'error', 'Generic error'),
            (r'FAILED', 'error', 'Failed operation'),
            (r'fatal:', 'fatal', 'Fatal error'),
            (r'command not found', 'error', 'Command not found'),
            (r'Permission denied', 'error', 'Permission denied'),
            (r'No space left on device', 'fatal', 'Disk space error'),
            (r'chezmoi: error:', 'error', 'Chezmoi error'),
            (r'Traceback \(most recent call last\):', 'error', 'Python traceback'),
            (r'panic:', 'fatal', 'Go panic'),
            (r'\[ERROR\]', 'error', 'Error log entry'),
            (r'CRITICAL', 'fatal', 'Critical error'),
        ]

        # Add default patterns
        for pattern_str, severity, description in default_patterns:
            patterns.append(ErrorPattern(
                pattern=re.compile(pattern_str, re.IGNORECASE),
                severity=severity,
                description=description,
                stop_on_match=(severity == 'fatal')
            ))

        # Add config patterns
        if isinstance(error_config, list):
            for pattern_str in error_config:
                patterns.append(ErrorPattern(
                    pattern=re.compile(pattern_str, re.IGNORECASE),
                    severity='error',
                    description=f'Custom pattern: {pattern_str}',
                    stop_on_match=False
                ))

        return patterns

    def _compile_success_patterns(self) -> List[SuccessPattern]:
        """Compile success detection patterns from config"""
        patterns = []
        success_config = self.config.get('success_patterns', [])

        # Default success patterns
        default_patterns = [
            (r'chezmoi: no differences', 'Chezmoi apply successful'),
            (r'Apply complete', 'Operation completed successfully'),
            (r'Installation complete', 'Installation finished'),
            (r'Successfully installed', 'Package installation complete'),
            (r'\[OK\]', 'Operation OK'),
            (r'✓', 'Success indicator'),
        ]

        # Add default patterns
        for pattern_str, description in default_patterns:
            patterns.append(SuccessPattern(
                pattern=re.compile(pattern_str, re.IGNORECASE),
                description=description,
                required=False
            ))

        # Add config patterns
        if isinstance(success_config, list):
            for pattern_str in success_config:
                patterns.append(SuccessPattern(
                    pattern=re.compile(pattern_str, re.IGNORECASE),
                    description=f'Custom success: {pattern_str}',
                    required=False
                ))

        return patterns

    def add_error_callback(self, callback: Callable[[Dict], None]) -> None:
        """Add callback for error detection"""
        self.error_callbacks.append(callback)

    def add_success_callback(self, callback: Callable[[Dict], None]) -> None:
        """Add callback for success detection"""
        self.success_callbacks.append(callback)

    def add_log_entry(self, source: str, content: str, level: str = 'info') -> None:
        """Add a log entry to the monitor"""
        entry = LogEntry(
            timestamp=datetime.now(),
            source=source,
            content=content,
            level=level
        )
        self.log_entries.append(entry)
        self.log_queue.put(entry)

    def start_monitoring(self) -> None:
        """Start the console monitoring thread"""
        if self.is_monitoring:
            return

        self.is_monitoring = True
        self.monitor_thread = threading.Thread(
            target=self._monitor_loop,
            daemon=True
        )
        self.monitor_thread.start()
        self.logger.info("Console monitoring started")

    def stop_monitoring(self) -> None:
        """Stop the console monitoring thread"""
        if not self.is_monitoring:
            return

        self.is_monitoring = False
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=5)
        self.logger.info("Console monitoring stopped")

    def _monitor_loop(self) -> None:
        """Main monitoring loop"""
        while self.is_monitoring:
            try:
                # Process log entries from queue
                entry = self.log_queue.get(timeout=1.0)
                self._analyze_log_entry(entry)
            except Empty:
                continue
            except Exception as e:
                self.logger.error(f"Error in monitor loop: {e}")

    def _analyze_log_entry(self, entry: LogEntry) -> None:
        """Analyze a log entry for patterns"""
        content = entry.content.strip()
        if not content:
            return

        # Check error patterns
        for error_pattern in self.error_patterns:
            if error_pattern.pattern.search(content):
                error_info = {
                    'timestamp': entry.timestamp,
                    'source': entry.source,
                    'content': content,
                    'pattern': error_pattern.pattern.pattern,
                    'severity': error_pattern.severity,
                    'description': error_pattern.description,
                    'stop_required': error_pattern.stop_on_match
                }
                self.errors_found.append(error_info)
                self.logger.error(f"Error detected: {error_pattern.description} - {content}")

                # Notify callbacks
                for callback in self.error_callbacks:
                    try:
                        callback(error_info)
                    except Exception as e:
                        self.logger.error(f"Error callback failed: {e}")

                # Stop monitoring if pattern requires it
                if error_pattern.stop_on_match:
                    self.logger.critical(f"Fatal error detected, stopping monitoring: {content}")
                    self.stop_monitoring()
                    return

        # Check success patterns
        for success_pattern in self.success_patterns:
            if success_pattern.pattern.search(content):
                success_info = {
                    'timestamp': entry.timestamp,
                    'source': entry.source,
                    'content': content,
                    'pattern': success_pattern.pattern.pattern,
                    'description': success_pattern.description,
                    'required': success_pattern.required
                }
                self.successes_found.append(success_info)
                self.logger.info(f"Success detected: {success_pattern.description} - {content}")

                # Notify callbacks
                for callback in self.success_callbacks:
                    try:
                        callback(success_info)
                    except Exception as e:
                        self.logger.error(f"Success callback failed: {e}")

    def has_errors(self, severity_filter: Optional[str] = None) -> bool:
        """Check if any errors were detected"""
        if not severity_filter:
            return len(self.errors_found) > 0

        return any(
            error['severity'] == severity_filter
            for error in self.errors_found
        )

    def has_fatal_errors(self) -> bool:
        """Check if any fatal errors were detected"""
        return self.has_errors('fatal')

    def get_errors(self, severity_filter: Optional[str] = None) -> List[Dict]:
        """Get detected errors, optionally filtered by severity"""
        if not severity_filter:
            return self.errors_found.copy()

        return [
            error for error in self.errors_found
            if error['severity'] == severity_filter
        ]

    def get_successes(self) -> List[Dict]:
        """Get detected successes"""
        return self.successes_found.copy()

    def get_log_entries(self, source_filter: Optional[str] = None) -> List[LogEntry]:
        """Get log entries, optionally filtered by source"""
        if not source_filter:
            return self.log_entries.copy()

        return [
            entry for entry in self.log_entries
            if entry.source == source_filter
        ]

    def get_summary(self) -> Dict[str, Any]:
        """Get monitoring summary"""
        return {
            'test_name': self.test_name,
            'total_log_entries': len(self.log_entries),
            'errors_count': len(self.errors_found),
            'successes_count': len(self.successes_found),
            'fatal_errors': self.has_fatal_errors(),
            'error_severities': {
                'warning': len([e for e in self.errors_found if e['severity'] == 'warning']),
                'error': len([e for e in self.errors_found if e['severity'] == 'error']),
                'fatal': len([e for e in self.errors_found if e['severity'] == 'fatal']),
            },
            'monitoring_active': self.is_monitoring
        }

    def export_logs(self, file_path: str, format_type: str = 'text') -> bool:
        """Export logs to file"""
        try:
            with open(file_path, 'w') as f:
                if format_type == 'json':
                    import json
                    log_data = {
                        'test_name': self.test_name,
                        'summary': self.get_summary(),
                        'errors': self.errors_found,
                        'successes': self.successes_found,
                        'log_entries': [
                            {
                                'timestamp': entry.timestamp.isoformat(),
                                'source': entry.source,
                                'content': entry.content,
                                'level': entry.level
                            }
                            for entry in self.log_entries
                        ]
                    }
                    json.dump(log_data, f, indent=2)
                else:
                    # Text format
                    f.write(f"Console Monitor Log - {self.test_name}\n")
                    f.write(f"Generated: {datetime.now().isoformat()}\n")
                    f.write("=" * 80 + "\n\n")

                    # Summary
                    summary = self.get_summary()
                    f.write("SUMMARY:\n")
                    for key, value in summary.items():
                        f.write(f"  {key}: {value}\n")
                    f.write("\n")

                    # Errors
                    if self.errors_found:
                        f.write("ERRORS DETECTED:\n")
                        for error in self.errors_found:
                            f.write(f"  [{error['timestamp']}] {error['severity'].upper()}: {error['description']}\n")
                            f.write(f"    Content: {error['content']}\n")
                            f.write(f"    Source: {error['source']}\n\n")

                    # Successes
                    if self.successes_found:
                        f.write("SUCCESSES DETECTED:\n")
                        for success in self.successes_found:
                            f.write(f"  [{success['timestamp']}] {success['description']}\n")
                            f.write(f"    Content: {success['content']}\n\n")

                    # Full log
                    f.write("FULL LOG:\n")
                    for entry in self.log_entries:
                        f.write(f"[{entry.timestamp}] {entry.source}: {entry.content}\n")

            return True
        except Exception as e:
            self.logger.error(f"Failed to export logs: {e}")
            return False

    def __enter__(self):
        """Context manager entry"""
        self.start_monitoring()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.stop_monitoring()