#!/bin/bash

# Variables
UBUNTU_VERSION=$(lsb_release -r | awk '{print $2}')  # Get the current Ubuntu version.
BASH_VERSION=$(bash --version | head -n 1 | awk '{print $4}')  # Get the current Bash version.

# Default CloudWatch Agent Path Parameters
CLOUDWATCH_AGENT_PATH="/opt/aws/amazon-cloudwatch-agent"  # Path to CloudWatch Agent installation.
CLOUDWATCH_AGENT="$CLOUDWATCH_AGENT_PATH/bin/amazon-cloudwatch-agent-ctl"  # Command to control the CloudWatch Agent.
CLOUDWATCH_PROFILE="AmazonCloudWatchAgent"  # Default AWS profile to be used by CloudWatch Agent.
# CLOUDWATCH_CREDENTIALS_FILE="$HOME/.aws/credentials"  # (commented) Path for AWS credentials file.

# Default Config File Path Parameters
CONFIG_TEMPLATE_FILE="$CLOUDWATCH_AGENT_PATH/etc/amazon-cloudwatch-agent-template.json"  # Path to the CloudWatch Agent config template.
CONFIG_FILE="${CONFIG_TEMPLATE_FILE%-template*}"  # Remove '-template' from the template file to define the final config file.
CONFIG_REGION="us-east-1"  # Default AWS region for CloudWatch.
#CONFIG_ACCESS_KEY_ID=""  # AWS Access Key ID.
#CONFIG_SECRET_ACCESS_KEY="" # AWS Secret Access Key
#CONFIG_OUTPUT="none"  # Default AWS CLI output format (none).
CONFIG_TEMPLATE='{"agent": {"run_as_user": "'"${USER}"'", "region": "'"${CONFIG_REGION}"'"}}'  # JSON template for CloudWatch Agent configuration.
CONFIG_COMMON_FILE="$CLOUDWATCH_AGENT_PATH/etc/common-config.toml"  # Path to the common configuration file for CloudWatch Agent.

# Default CPU Parameters
CPU_METRICS="cpu_usage_idle cpu_usage_user cpu_usage_system cpu_usage_active"  # Default CPU metrics to track.
CPU_INTERVAL=60  # Default interval (in seconds) to collect CPU metrics.
CPU_TOTAL=true  # Whether to track total CPU usage.

# Default Memory Parameters
MEM_METRICS="mem_used_percent mem_available mem_total"  # Default memory metrics to track.
MEM_INTERVAL=60  # Default interval (in seconds) to collect memory metrics.


# Helper function for error handling
check_error() {
    if [ $? -ne 0 ]; then  # Check if the previous command failed.
        echo "Error during $1. Exiting."  # Print error message and exit.
        exit 1
    fi
}

# Update bash to 4.4 if using an older version
update_bash() {
    # Define the required version
    required_version="4.0"  # Set the minimum required Bash version.

    # Compare current version with required version
    if [ "$(echo -e "$BASH_VERSION\n$required_version" | sort -V | head -n 1)" != "$required_version" ]; then
        echo "Bash version is lower than 4.0. Updating Bash..."

        # Update package list and upgrade Bash
        sudo apt update && sudo apt install --only-upgrade bash  # Install the latest Bash version.
        
        # Verify if the update was successful
        new_version=$(bash --version | head -n 1 | awk '{print $4}')
        echo "Bash has been updated to version $new_version"
    else
        echo "Bash is already at version $BASH_VERSION or greater."  # Bash is up-to-date.
    fi
}

# Install coreutils for realpath command if not installed
install_coreutils() {
    if ! command -v realpath &>/dev/null; then  # Check if realpath command is installed.
        echo "command realpath not found, installing..."
        sudo apt-get install coreutils -y  # Install coreutils package to provide the realpath command.
        check_error "installing coreutils"  # Check if the installation was successful.
    else
        echo "command realpath is already available."  # realpath is already installed.
    fi
}

# Install AWS CLI if not installed
install_aws_cli() {
    if ! command -v aws &>/dev/null; then  # Check if AWS CLI is installed.
        echo "AWS CLI not found, installing..."
        sudo snap install aws-cli --classic  # Install AWS CLI using snap package manager.
        check_error "installing AWS CLI"  # Check if the installation was successful.
    else
        echo "AWS CLI is already installed."  # AWS CLI is already installed.
    fi
}

# Install CloudWatch Agent if not installed
install_cloudwatch_agent() {
    if [ ! -f "$CLOUDWATCH_AGENT" ]; then  # Check if CloudWatch Agent is already installed.
        echo "Installing CloudWatch Agent..."
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb  # Download the CloudWatch agent package.
        check_error "downloading CloudWatch agent package"  # Ensure the download succeeded.

        sudo dpkg -i amazon-cloudwatch-agent.deb  # Install the downloaded CloudWatch agent package.
        check_error "installing CloudWatch agent"  # Ensure the installation succeeded.

        rm amazon-cloudwatch-agent.deb  # Clean up by removing the downloaded .deb file.
    else
        echo "CloudWatch Agent is already installed."  # CloudWatch Agent is already installed.
    fi
}

# Configure AWS credentials (prompt user if not set)
configure_aws_credentials() {
    if ! aws configure list --profile "$CLOUDWATCH_PROFILE" &>/dev/null; then  # Check if AWS credentials are already configured.
        echo "AWS credentials not found, configuring..."
        aws configure set aws_access_key_id "$CONFIG_ACCESS_KEY_ID" --profile "$CLOUDWATCH_PROFILE"  # Set the AWS Access Key ID.
        aws configure set aws_secret_access_key "$CONFIG_SECRET_ACCESS_KEY" --profile "$CLOUDWATCH_PROFILE"  # Set the AWS Secret Access Key.
        aws configure set region "$CONFIG_REGION" --profile "$CLOUDWATCH_PROFILE"  # Set the AWS region.
        aws configure set output "$CONFIG_OUTPUT" --profile "$CLOUDWATCH_PROFILE"  # Set the output format.
        check_error "configuring AWS credentials"  # Ensure the configuration succeeded.
    else
        echo "AWS credentials are already configured."  # AWS credentials are already set.
    fi
}

# Initialize configuration template
initialize_config_template() {
    echo "Initializing configuration template..."
    echo "$CONFIG_TEMPLATE" | jq '.' > "$CONFIG_TEMPLATE_FILE"  # Format and write the configuration template to the file.
    check_error "initializing CloudWatch configuration file"  # Ensure the initialization succeeded.
}

# Initialize common config
#initialize_config_common() {
#    touch "$CONFIG_COMMON_FILE"
#        if [[ ! "$USER" == "root" ]]; then
#           sudo tee "$CONFIG_COMMON_FILE" > /dev/null << EOL
#[credentials]
#    shared_credential_profile = "$CLOUDWATCH_PROFILE"
#    shared_credential_file = "$CLOUDWATCH_CREDENTIALS_FILE"
#[default]
#    region = "$CONFIG_REGION"
#EOL
#       fi
#       check_error "creating common-config.toml"
#}

# Start CloudWatch Agent
start_agent() {
    echo "Starting CloudWatch Agent..."
    sudo $CLOUDWATCH_AGENT -a start  # Start the CloudWatch Agent.
    check_error "starting CloudWatch agent"  # Ensure the agent started successfully.
}

# Stop CloudWatch Agent
stop_agent() {
    echo "Stopping CloudWatch Agent..."
    sudo $CLOUDWATCH_AGENT -a stop  # Stop the CloudWatch Agent.
    check_error "stopping CloudWatch agent"  # Ensure the agent stopped successfully.
}

# Track log files
track_logs() {
    echo "Tracking log files: $@"  # Display the log files being tracked.
    for file in "$@"; do  # Loop through each log file passed as an argument.
        if [ ! -f "$file" ]; then  # Check if the log file exists.
            echo "File $file does not exist. Skipping."  # Skip if the file doesn't exist.
            continue
        fi
        jq ".logs.logs_collected.files.collect_list += [{\"file_path\": \"$(realpath $file)\", \"log_group_name\": \"$(basename "$file")\", \"log_stream_name\": \"$(basename "$file")\"}]" "$CONFIG_TEMPLATE_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_TEMPLATE_FILE"  # Update config with log file details.
        check_error "tracking log file $file"  # Ensure the file tracking was successful.
    done
}

# Track resource usage metrics
track_resource() {
    local RESOURCE="$1"  # The resource type (e.g., CPU, memory).
    local METRICS_TYPE="${RESOURCE^^}_METRICS"  # Convert resource name to uppercase for metrics variable.
    local INTERVAL_TYPE="${RESOURCE^^}_INTERVAL"  # Convert resource name to uppercase for interval variable.

    # Fetch the default metrics and interval values using eval
    eval "METRICS_DEFAULT=\$${METRICS_TYPE}"  # Get default metrics for the resource.
    eval "INTERVAL_DEFAULT=\$$INTERVAL_TYPE"  # Get default interval for the resource.
    echo "${METRICS_DEFAULT}"
    # Shift out the resource type argument
    shift

    METRICS_ARR=()  # Array to hold custom metrics passed in arguments.
    declare -A PARAMS_ARR  # Associative array to hold parameters.

    # Set defaults
    PARAMS_ARR["metrics_collection_interval"]="$INTERVAL_DEFAULT"  # Set the default interval for metrics collection.

    if [[ $RESOURCE == "CPU" ]]; then  # If the resource is CPU, set the total CPU usage parameter.
        PARAMS_ARR["cpu_total"]="$CPU_TOTAL"
    fi

    # Parse command-line arguments for custom metrics and intervals
    while [[ "$1" != "" && ! "$1" =~ ^-- ]]; do
        if [[ "$1" =~ ^- && "$2" != "" && ! "$2" =~ ^-- ]]; then
            KEY="${1#-}"
            PARAMS_ARR["$KEY"]="$2"
            shift
        else
            # Append to the "metrics" array within the associative array
            METRICS_ARR+=("$1")
        fi
        shift
    done

    # If no metrics were passed in, use the default metrics
    if [[ ${#METRICS_ARR[@]} -eq 0 ]]; then
        METRICS_ARR=(${METRICS_DEFAULT})
    fi

    echo "Tracking $RESOURCE usage metrics: ${METRICS_ARR[@]}"

    # Construct JSON array of metrics
    local METRICS="["  # Start JSON array
    for METRIC in "${METRICS_ARR[@]}"; do
        METRICS+="\"$METRIC\", "
    done
    METRICS="${METRICS%, }"
    METRICS+="]"  # Close JSON array

    # Update the configuration file with the new metrics
    jq --arg RESOURCE "$RESOURCE" \
       --argjson METRICS "$METRICS" \
       '.metrics.metrics_collected[$RESOURCE] = { "measurement": $METRICS, "resources": ["*"] }' \
       "$CONFIG_TEMPLATE_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_TEMPLATE_FILE"

    # Apply additional parameters
    for KEY in "${!PARAMS_ARR[@]}"; do
        jq --arg RESOURCE "$RESOURCE" --arg KEY "$KEY" --argjson VALUE "${PARAMS_ARR[$KEY]}" '.metrics.metrics_collected[$RESOURCE][$KEY] = $VALUE' \
                "$CONFIG_TEMPLATE_FILE" > tmp_file && mv tmp_file "$CONFIG_TEMPLATE_FILE"
done

    check_error "tracking $RESOURCE usage"
}

# Untrack all log files or metrics from the CloudWatch configuration.
untrack_resource() {
    # Log the action of removing tracking for a specific resource type (logs or metrics).
    echo "Removing all ${1##*.} tracking..."
    
    # Use `jq` to delete the resource (logs or metrics) from the configuration file.
    # The resource type is passed as an argument, and it removes the corresponding section from the JSON file.
    jq "del($1)" "$CONFIG_TEMPLATE_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_TEMPLATE_FILE"

    # Check for any errors in removing the tracking information from the configuration file.
    check_error "removing log tracking"
}


# Format the configuration template by applying necessary changes before the CloudWatch agent uses it.
format_config_template() {
    # Check if the 'metrics' section exists and is empty (no metrics are collected).
    # If true, delete the 'metrics' section from the configuration template to clean it up.
    if [ "$(jq -e '.metrics | select(has("metrics_collected") and (.metrics_collected | length == 0))' "$CONFIG_TEMPLATE_FILE")" ]; then
        jq 'del(.metrics)' "$CONFIG_TEMPLATE_FILE" > tmp.$$.json && mv tmp.$$.json "$CONFIG_TEMPLATE_FILE"
    fi

    # If the configuration template file exists, apply the configuration to the CloudWatch agent.
    if [ -f "$CONFIG_TEMPLATE_FILE" ]; then
        # Log that the configuration is being applied.
        echo "Applying configuration..."
        
        # Copy the template configuration to the target configuration file.
        cp "$CONFIG_TEMPLATE_FILE" "$CONFIG_FILE"
        
        # Use the CloudWatch agent command to fetch and apply the configuration file.
        # The `-a fetch-config` option tells the agent to fetch the configuration.
        sudo $CLOUDWATCH_AGENT -a fetch-config -m onPremise -c file:"$CONFIG_FILE"

        # Check for errors in applying the configuration.
        check_error "applying CloudWatch agent configuration"
    fi
}


# Display the usage instructions and available options for the script.
show_help() {
    # Print a description of the script's purpose and available command-line options.
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script manages the AWS CloudWatch Agent and tracks system logs and metrics."
    echo ""
    echo "Options:"
    echo "  --install [-secret string] [-id string] [-region string] [-output string]"
    echo "      Installs necessary components (AWS CLI, CloudWatch Agent, coreutils) and configures CloudWatch with the given parameters."
    echo "      -id       AWS Access Key ID for CloudWatch authentication."
    echo "      -secret   AWS Secret Access Key for CloudWatch authentication."
    echo "      -region   AWS region for the CloudWatch Agent configuration."
    echo "      -output   AWS CLI output format (default: none)."
    echo ""
    echo "  --start"
    echo "      Starts the CloudWatch Agent."
    echo ""
    echo "  --stop"
    echo "      Stops the CloudWatch Agent."
    echo ""
    echo "  --track-logs logfile1 [logfile2 ...]"
    echo "      Tracks specified log files in CloudWatch."
    echo "      Example: $0 --track-logs /var/log/syslog /var/log/auth.log"
    echo ""
    echo "  --untrack-logs"
    echo "      Removes all tracked logs from the CloudWatch configuration."
    echo ""
    echo "  --track-cpu [metrics] [-metrics_collection_interval number]"
    echo "      Tracks specified CPU metrics in CloudWatch."
    echo "      Available CPU metrics include: cpu_usage_idle, cpu_usage_user, cpu_usage_system, cpu_usage_active"
    echo "      -metrics_collection_interval   Interval (in seconds) to collect CPU metrics (default: 60)."
    echo "      Example: $0 --track-cpu cpu_usage_idle -metrics_collection_interval 30"
    echo ""
    echo "  --untrack-cpu"
    echo "      Removes all tracked CPU metrics from the CloudWatch configuration."
    echo ""
    echo "  --track-mem [metrics] [-metrics_collection_interval number]"
    echo "      Tracks specified memory metrics in CloudWatch."
    echo "      Available memory metrics include: mem_used_percent, mem_available, mem_total"
    echo "      -metrics_collection_interval   Interval (in seconds) to collect memory metrics (default: 60)."
    echo "      Example: $0 --track-mem mem_used_percent -metrics_collection_interval 30"
    echo ""
    echo "  --untrack-mem"
    echo "      Removes all tracked memory metrics from the CloudWatch configuration."
    echo ""
    echo "  --help"
    echo "      Displays this help message."
    echo ""
    echo "Example Usage:"
    echo "  $0 --install -id YOUR_ACCESS_KEY -secret YOUR_SECRET_KEY -region us-east-1"
    echo "  $0 --track-logs /var/log/syslog"
    echo "  $0 --track-cpu cpu_usage_idle -metrics_collection_interval 30"
    echo "  $0 --start"
    echo ""
}

# Main logic for processing command-line arguments and flags
while [[ "$1" != "" ]]; do
    case $1 in
        # Handling the --install flag and its associated parameters.
        --install )
            shift

            # Declare an associative array to store the parameters for installation.
            declare -A PARAMS_ARR

            # Loop through any flags with values and store them in the associative array.
            while [[ "$1" != "" && "$1" =~ ^- && "$2" != "" && ! "$2" =~ ^-- ]]; do
                KEY="${1#-}"
                PARAMS_ARR["$KEY"]="$2"
                shift 2
            done

            # Set the configuration parameters from the provided or default values.
            CONFIG_ACCESS_KEY_ID=${PARAMS_ARR["id"]:-$CONFIG_ACCESS_KEY_ID}
            CONFIG_SECRET_ACCESS_KEY=${PARAMS_ARR["secret"]:-$CONFIG_SECRET_ACCESS_KEY}
            CONFIG_REGION=${PARAMS_ARR["region"]:-$CONFIG_REGION}
            CONFIG_OUTPUT=${PARAMS_ARR["output"]:-$CONFIG_OUTPUT}

            # Install core utilities if the Ubuntu version is below 12.04.
            if dpkg --compare-versions "$UBUNTU_VERSION" lt "12.04"; then
                update_bash
                install_coreutils
            fi

            # Install AWS CLI, CloudWatch agent, and configure the credentials.
            install_aws_cli
            install_cloudwatch_agent
            configure_aws_credentials

            # Initialize and format the configuration template.
            initialize_config_template
            format_config_template

            # Move past additional arguments if any are provided.
            while [[ "$1" != "" && ! "$1" =~ ^-- ]]; do
                shift
            done
            ;;
        # Handling other flags such as --start, --stop, --track-logs, etc.
        --start )
            shift
            start_agent
            ;;
        --stop )
            shift
            stop_agent
            ;;
        --track-logs )
            shift
            track_logs "$@"
            format_config_template
            while [[ "$1" != "" && ! "$1" =~ ^-- ]]; do
                shift
            done
            ;;
        --untrack-logs )
            shift
            untrack_resource ".logs"
            format_config_template
            ;;
        --track-cpu )
            shift
            track_resource "cpu" "$@"
            format_config_template
            while [[ "$1" != "" && ! "$1" =~ ^-- ]]; do
                shift
            done
            ;;
        --untrack-cpu )
            shift
            untrack_resource ".metrics.metrics_collected.cpu"
            format_config_template
            ;;
        --track-mem )
            shift
            track_resource "mem" "$@"
            format_config_template
            while [[ "$1" != "" && ! "$1" =~ ^-- ]]; do
                shift
            done
            ;;
        --untrack-mem )
            shift
            untrack_resource ".metrics.metrics_collected.mem"
            format_config_template
            ;;
        --help )
            show_help
            exit 0
            ;;
        * )
            # Handle unknown options and display the help message.
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done
