# CloudWatch Agent Manager Script

This script installs and configures the AWS CloudWatch Agent on a system running Ubuntu. It supports automatic installation of dependencies, setup of AWS credentials, and monitoring of system metrics (CPU, memory) along with log file tracking. The script ensures that the correct versions of Bash, AWS CLI, and CloudWatch Agent are installed and configured, making it easy to set up CloudWatch monitoring on your Ubuntu instance. 

Current version must be run as root.

## Features

- Checks and updates Bash to version 4.0 if necessary.
- Installs missing dependencies: AWS CLI, CloudWatch Agent, core utilities (like `realpath`).
- Configures AWS credentials for CloudWatch Agent.
- Initializes CloudWatch Agent configuration from a template.
- Allows tracking of system resources (CPU, memory) and log files.
- Supports starting and stopping the CloudWatch Agent.
- Provides flexibility to add custom metrics and logs to the CloudWatch configuration.

## Prerequisites

- Root user
- Ubuntu system (tested on Ubuntu versions with `lsb_release` and `dpkg` commands available).
- Internet access to download required packages.

## Installation

1. Clone or copy this script to your server.
2. Make the script executable:
   ```bash
   chmod +x cloudwatch_manager.sh
   ```   
3. Run the script installation:
   ```bash
   ./cloudwatch_manager.sh --install [-id AWS_IAMS_USER_ACCESS_KEY_ID] [-secret AWS_IAMS_USER_SECRET_ACCESS_KEY] [-region REGION] [-output OUTPUT]
   ```

The script will:
- Update Bash if required.
- Install the AWS CLI if not already installed.
- Install the CloudWatch Agent if it is missing.
- Configure the AWS credentials.
- Set up the CloudWatch configuration file.
- Start the CloudWatch Agent.


## Configuration
Example:
 ```bash
 ./cloudwatch_manager.sh [--track-cpu [metric1, metric2, ...]] [-cloudwatch_config_cpu_key value] [--track-mem [metric1, metric2, ...]] [-cloudwatch_config_mem_key value] [--track-logs logfile1, logfile2, ...] [--untrack-cpu] [--untrack-mem] [--untrack-logs]
 ```

### AWS Credentials

By default, the script assumes you are using a specific AWS profile (`AmazonCloudWatchAgent`). If AWS credentials are not already configured for this profile

You can customize the following parameters in the script:
- `CLOUDWATCH_PROFILE`: The AWS CLI profile to use.
- `CONFIG_REGION`: The AWS region (default is `us-east-1`).
- `CONFIG_ACCESS_KEY_ID` and `CONFIG_SECRET_ACCESS_KEY`: These can be set in the script or environment if you want to provide them explicitly. If not set in either, they must be passed in when using the --install flag (see ./cloudwatch.sh --help)

### Resource Tracking
Example:
 ```bash
 ./cloudwatch_manager.sh --track-cpu  cpu_usage_user cpu_usage_system -metrics_collection_interval 30 -total_cpu false --track-mem mem_used_percent mem_available mem_total -metrics_collection_interval 20
 ```

The script supports tracking CPU and memory metrics by default. You can also add additional metrics or change the collection intervals.

- **CPU Metrics**: `cpu_usage_idle`, `cpu_usage_user`, `cpu_usage_system`, `cpu_usage_active`
- **Memory Metrics**: `mem_used_percent`, `mem_available`, `mem_total`

These can be customized by providing custom metrics in the script's arguments (see ./cloudwatch.sh --help).

### Log File Tracking

You can add log files to be monitored by the CloudWatch Agent by calling the `track_logs` function with file paths as arguments.

Example:
```bash
 ./cloudwatch_manager.sh /var/log/syslog /var/log/auth.log
```

A swap logging script is provided (swap_logger.sh). To check the functionality of Log File tracking, you may run the script via
```bash
  ./cloudwatch_manager.sh chmod +x swap_logger.sh && ./swap_logger.sh &
```
then track the contents of this file with
```bash
  ./cloudwatch_manager.sh /tmp/swap_used_log.json
```

### Starting and Stopping CloudWatch Agent (after configuration)

- To **start** the CloudWatch Agent:
  ```bash
  ./cloudwatch_manager.sh --start
  ```

- To **stop** the CloudWatch Agent:
  ```bash
  ./cloudwatch_manager.sh --stop
  ```

### Formatting and Untracking Resources

The script allows you to format the configuration file to untrack specific resources by removing them from the CloudWatch configuration.

```bash
  ./cloudwatch_manager.sh --untrack-cpu
```
```bash
  ./cloudwatch_manager.sh --untrack-mem
```
```bash
  ./cloudwatch_manager.sh --untrack-logs
```

## Error Handling

The script includes error handling functions to ensure that each step completes successfully. If any command fails, the script will terminate and provide an error message.

## License

This script is licensed under the MIT License.

## Troubleshooting

If you encounter issues, ensure the following:
- Read the help 
```bash
  ./cloudwatch_manager.sh --help
```
- Ensure your system has internet access to install dependencies and download packages.
- Verify that AWS CLI is properly configured with access to your AWS account.
- Check the system logs if CloudWatch Agent fails to start or report metrics.
