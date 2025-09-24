#!/usr/bin/env python3
"""
Test Report Generator for E2E Testing

Generates comprehensive HTML and JSON reports from test results.
"""

import json
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict

from jinja2 import Environment, FileSystemLoader


@dataclass
class TestResult:
    """Individual test result"""
    test_name: str
    distribution: str
    status: str  # 'passed', 'failed', 'skipped'
    duration: float
    vm_name: str
    error_message: Optional[str] = None
    console_log_path: Optional[str] = None
    artifacts_path: Optional[str] = None


@dataclass
class TestSuite:
    """Test suite results"""
    suite_name: str
    tests: List[TestResult]
    total_tests: int
    passed_tests: int
    failed_tests: int
    skipped_tests: int
    total_duration: float
    start_time: datetime
    end_time: datetime


@dataclass
class TestReport:
    """Complete test report"""
    report_id: str
    generated_at: datetime
    test_suites: List[TestSuite]
    summary: Dict[str, Any]
    environment: Dict[str, Any]
    artifacts_dir: str


class TestReportGenerator:
    """Generates test reports in multiple formats"""

    def __init__(self, output_dir: str = "test_results"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Set up Jinja2 environment
        template_dir = Path(__file__).parent / "templates"
        self.jinja_env = Environment(
            loader=FileSystemLoader(str(template_dir)),
            autoescape=True
        )

        # Set up logging
        self.logger = logging.getLogger("test_report_generator")

    def create_test_result(self, test_name: str, distribution: str, status: str,
                          duration: float, vm_name: str, error_message: str = None,
                          console_log_path: str = None, artifacts_path: str = None) -> TestResult:
        """Create a test result object"""
        return TestResult(
            test_name=test_name,
            distribution=distribution,
            status=status,
            duration=duration,
            vm_name=vm_name,
            error_message=error_message,
            console_log_path=console_log_path,
            artifacts_path=artifacts_path
        )

    def create_test_suite(self, suite_name: str, test_results: List[TestResult],
                         start_time: datetime, end_time: datetime) -> TestSuite:
        """Create a test suite object from test results"""
        total_tests = len(test_results)
        passed_tests = len([t for t in test_results if t.status == 'passed'])
        failed_tests = len([t for t in test_results if t.status == 'failed'])
        skipped_tests = len([t for t in test_results if t.status == 'skipped'])
        total_duration = sum(t.duration for t in test_results)

        return TestSuite(
            suite_name=suite_name,
            tests=test_results,
            total_tests=total_tests,
            passed_tests=passed_tests,
            failed_tests=failed_tests,
            skipped_tests=skipped_tests,
            total_duration=total_duration,
            start_time=start_time,
            end_time=end_time
        )

    def generate_report(self, test_suites: List[TestSuite], report_id: str = None,
                       environment_info: Dict[str, Any] = None) -> TestReport:
        """Generate a complete test report"""
        if report_id is None:
            report_id = f"e2e_test_{int(time.time())}"

        if environment_info is None:
            environment_info = self._get_default_environment_info()

        # Calculate summary statistics
        total_tests = sum(suite.total_tests for suite in test_suites)
        total_passed = sum(suite.passed_tests for suite in test_suites)
        total_failed = sum(suite.failed_tests for suite in test_suites)
        total_skipped = sum(suite.skipped_tests for suite in test_suites)
        total_duration = sum(suite.total_duration for suite in test_suites)

        # Success rate
        success_rate = (total_passed / total_tests * 100) if total_tests > 0 else 0

        # Distribution breakdown
        distributions = {}
        for suite in test_suites:
            for test in suite.tests:
                dist = test.distribution
                if dist not in distributions:
                    distributions[dist] = {'total': 0, 'passed': 0, 'failed': 0, 'skipped': 0}
                distributions[dist]['total'] += 1
                distributions[dist][test.status] += 1

        summary = {
            'total_tests': total_tests,
            'passed_tests': total_passed,
            'failed_tests': total_failed,
            'skipped_tests': total_skipped,
            'success_rate': round(success_rate, 2),
            'total_duration': round(total_duration, 2),
            'distributions': distributions,
            'test_suites_count': len(test_suites)
        }

        report = TestReport(
            report_id=report_id,
            generated_at=datetime.now(),
            test_suites=test_suites,
            summary=summary,
            environment=environment_info,
            artifacts_dir=str(self.output_dir)
        )

        return report

    def export_html_report(self, report: TestReport, filename: str = None) -> Path:
        """Export report as HTML"""
        if filename is None:
            filename = f"{report.report_id}.html"

        template = self.jinja_env.get_template("report.html")

        # Prepare template context
        context = {
            'report': report,
            'generated_timestamp': report.generated_at.strftime('%Y-%m-%d %H:%M:%S'),
            'duration_formatted': self._format_duration(sum(suite.total_duration for suite in report.test_suites)),
            'status_colors': {
                'passed': '#22c55e',
                'failed': '#ef4444',
                'skipped': '#f59e0b'
            }
        }

        html_content = template.render(context)

        output_path = self.output_dir / filename
        with open(output_path, 'w') as f:
            f.write(html_content)

        self.logger.info(f"HTML report generated: {output_path}")
        return output_path

    def export_json_report(self, report: TestReport, filename: str = None) -> Path:
        """Export report as JSON"""
        if filename is None:
            filename = f"{report.report_id}.json"

        # Convert report to dict for JSON serialization
        report_dict = asdict(report)

        # Convert datetime objects to ISO format strings
        report_dict['generated_at'] = report.generated_at.isoformat()
        for suite in report_dict['test_suites']:
            suite['start_time'] = suite['start_time'].isoformat()
            suite['end_time'] = suite['end_time'].isoformat()

        output_path = self.output_dir / filename
        with open(output_path, 'w') as f:
            json.dump(report_dict, f, indent=2)

        self.logger.info(f"JSON report generated: {output_path}")
        return output_path

    def export_junit_xml(self, report: TestReport, filename: str = None) -> Path:
        """Export report as JUnit XML format"""
        if filename is None:
            filename = f"{report.report_id}_junit.xml"

        template = self.jinja_env.get_template("junit.xml")

        context = {
            'report': report,
            'timestamp': report.generated_at.isoformat(),
        }

        xml_content = template.render(context)

        output_path = self.output_dir / filename
        with open(output_path, 'w') as f:
            f.write(xml_content)

        self.logger.info(f"JUnit XML report generated: {output_path}")
        return output_path

    def create_artifact_archive(self, report: TestReport, archive_name: str = None) -> Path:
        """Create a compressed archive of all test artifacts"""
        import tarfile

        if archive_name is None:
            archive_name = f"{report.report_id}_artifacts.tar.gz"

        archive_path = self.output_dir / archive_name

        with tarfile.open(archive_path, "w:gz") as tar:
            # Add report files
            for suite in report.test_suites:
                for test in suite.tests:
                    if test.console_log_path and Path(test.console_log_path).exists():
                        tar.add(test.console_log_path, arcname=f"logs/{test.vm_name}_console.log")

                    if test.artifacts_path and Path(test.artifacts_path).exists():
                        # Add entire artifacts directory for this test
                        tar.add(test.artifacts_path, arcname=f"artifacts/{test.vm_name}")

        self.logger.info(f"Artifact archive created: {archive_path}")
        return archive_path

    def generate_summary_dashboard(self, reports: List[TestReport], filename: str = "dashboard.html") -> Path:
        """Generate a dashboard summarizing multiple test reports"""
        template = self.jinja_env.get_template("dashboard.html")

        # Aggregate statistics across reports
        total_reports = len(reports)
        total_test_runs = sum(len(report.test_suites) for report in reports)

        # Success rates over time
        success_rates = []
        for report in sorted(reports, key=lambda r: r.generated_at):
            success_rates.append({
                'timestamp': report.generated_at.strftime('%Y-%m-%d %H:%M'),
                'rate': report.summary['success_rate']
            })

        # Distribution breakdown across all reports
        distribution_stats = {}
        for report in reports:
            for dist, stats in report.summary['distributions'].items():
                if dist not in distribution_stats:
                    distribution_stats[dist] = {'total': 0, 'passed': 0, 'failed': 0, 'skipped': 0}
                for key, value in stats.items():
                    distribution_stats[dist][key] += value

        context = {
            'reports': reports,
            'total_reports': total_reports,
            'total_test_runs': total_test_runs,
            'success_rates': success_rates,
            'distribution_stats': distribution_stats,
            'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }

        html_content = template.render(context)

        output_path = self.output_dir / filename
        with open(output_path, 'w') as f:
            f.write(html_content)

        self.logger.info(f"Summary dashboard generated: {output_path}")
        return output_path

    def _get_default_environment_info(self) -> Dict[str, Any]:
        """Get default environment information"""
        import platform
        import subprocess

        env_info = {
            'hostname': platform.node(),
            'platform': platform.platform(),
            'python_version': platform.python_version(),
            'timestamp': datetime.now().isoformat()
        }

        # Try to get git information
        try:
            git_commit = subprocess.check_output(
                ['git', 'rev-parse', 'HEAD'],
                cwd=Path(__file__).parent.parent,
                text=True
            ).strip()
            env_info['git_commit'] = git_commit
        except (subprocess.CalledProcessError, FileNotFoundError):
            env_info['git_commit'] = 'unknown'

        # Try to get QEMU version
        try:
            qemu_version = subprocess.check_output(
                ['qemu-system-x86_64', '--version'],
                text=True
            ).split('\n')[0]
            env_info['qemu_version'] = qemu_version
        except (subprocess.CalledProcessError, FileNotFoundError):
            env_info['qemu_version'] = 'not available'

        return env_info

    def _format_duration(self, seconds: float) -> str:
        """Format duration in human-readable format"""
        if seconds < 60:
            return f"{seconds:.1f}s"
        elif seconds < 3600:
            minutes = int(seconds // 60)
            secs = seconds % 60
            return f"{minutes}m {secs:.1f}s"
        else:
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            secs = seconds % 60
            return f"{hours}h {minutes}m {secs:.1f}s"


def main():
    """CLI interface for report generation"""
    import argparse

    parser = argparse.ArgumentParser(description="Generate E2E test reports")
    parser.add_argument("--input", required=True, help="Input JSON file with test results")
    parser.add_argument("--output-dir", default="test_results", help="Output directory")
    parser.add_argument("--format", choices=["html", "json", "junit", "all"], default="html")
    parser.add_argument("--report-id", help="Report ID")

    args = parser.parse_args()

    generator = TestReportGenerator(args.output_dir)

    # Load test results from JSON
    with open(args.input, 'r') as f:
        data = json.load(f)

    # Convert JSON data to TestReport object
    # This would need to be implemented based on the actual JSON structure
    # For now, this is a placeholder
    print(f"Loading test results from {args.input}")
    print(f"Generating {args.format} report(s) in {args.output_dir}")


if __name__ == "__main__":
    main()