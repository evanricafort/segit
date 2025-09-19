#!/bin/bash

# File: lib/discord.sh

# Function to archive and send scan results to Discord
send_to_discord() {
    local webhook_url="$1"
    local dir_name="$2"
    local targets="$3"
    local targets_file="$4"

    # Define the archive file name
    local archive_name="${dir_name}.zip"

    # Create the zip archive in a subshell to avoid changing the main script's CWD
    echo -e "${CYAN}Creating zip archive of results...${NC}"
    if ! (cd .. && zip -r "$dir_name/$archive_name" "$dir_name"); then
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
    message_content+=".\nScan started at: $(cat "$dir_name/start_time.txt")\nScan finished at: $(cat "$dir_name/end_time.txt")"

    # Send the zip file to Discord using curl
    echo -e "${CYAN}Uploading to Discord...${NC}"
    local response=$(curl -s -X POST -H "Content-Type: multipart/form-data" \
        -F "file=@$dir_name/$archive_name" \
        -F "payload_json={\"content\": \"$message_content\"}" \
        "$webhook_url")

    if echo "$response" | grep -q '400: Bad Request' || echo "$response" | grep -q '401: Unauthorized'; then
        echo -e "${RED}Error:${NC} Failed to send results to Discord. Check the webhook URL and permissions."
    else
        echo -e "${GREEN}Successfully sent results to Discord.${NC}"
    fi

    # Clean up the zip file
    rm "$dir_name/$archive_name"
}
