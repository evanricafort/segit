#!/bin/bash

# File: lib/discord.sh

# Function to archive and send scan results to Discord
send_to_discord() {
    local webhook_url="$1"
    local dir_name="$2"
    local targets="$3"
    local targets_file="$4"
    local start_time="$5"
    local end_time="$6"

    # Define the archive file name
    local archive_name="${dir_name}.zip"

    # Create the start and end time files inside the scan directory
    echo "$start_time" > "start_time.txt"
    echo "$end_time" > "end_time.txt"

    # Create the zip archive in the parent directory using a subshell
    echo -e "${CYAN}Creating zip archive of results...${NC}"
    # The -j flag ensures files are not stored with directory paths
    # The file path is correctly specified to be outside the directory being zipped
    if ! (cd .. && zip -r "$archive_name" "$dir_name" > /dev/null); then
        echo -e "${RED}Error:${NC} Failed to create zip archive. Aborting Discord upload."
        return 1
    fi
    echo -e "${GREEN}Archive created: ${YELLOW}$archive_name${NC}"

    # Prepare a message to send with the file
    local message_content="SegIt! scan results for: "
    if [ -n "$targets" ]; then
        message_content+="$targets"
    elif [ -n "$targets_file" ]; then
        message_content+="targets from file: $targets_file"
    else
        message_content+="unknown targets"
    fi
    message_content+=".\nScan started at: $start_time\nScan finished at: $end_time"

    # Send the zip file to Discord using curl
    echo -e "${CYAN}Uploading to Discord...${NC}"
    local response=$(curl -s -X POST -H "Content-Type: multipart/form-data" \
        -F "file=@../$archive_name" \
        -F "payload_json={\"content\": \"$message_content\"}" \
        "$webhook_url")

    # Check for upload errors
    if echo "$response" | grep -q '{"file": ["File is too large"]}' || echo "$response" | grep -q '400: Bad Request' || echo "$response" | grep -q '401: Unauthorized'; then
        echo -e "${RED}Error:${NC} Failed to send results to Discord. Check the webhook URL, permissions, or file size."
        return 1
    else
        echo -e "${GREEN}Successfully sent results to Discord.${NC}"
    fi

    # Clean up the zip file
    rm "../$archive_name"
    echo -e "${GREEN}Temporary zip file removed.${NC}"
}
