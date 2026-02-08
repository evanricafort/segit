# File: lib/verify.sh

verify_services() {
    local traffic_from="$1"
    local targets_file="$2"
    local suffix="$3" # New argument for Compare Mode
    
    # Define output file with suffix
    local output_csv="segmentation_results${suffix}.csv"
    local nmap_dir="nmap_output_files${suffix}"

    # Detect source IP
    local source_ip=$(ip -o -4 addr show | awk '!/127.0.0.1/ {print $4}' | cut -d/ -f1 | head -n1)
    
    echo -e "${CYAN}Performing Netcat verification (Iteration${suffix:-" Default"})...${NC}"
    
    echo "Traffic From,Traffic To,Status,Source IP,Destination IP,Open Ports,Notes" > "$output_csv"

    # Look for Nmap files in the specific directory
    local nmap_files=$(ls ${nmap_dir}/*.nmap 2>/dev/null)
    
    if [ -z "$nmap_files" ]; then
        echo -e "${RED}Error: No Nmap files found in ${nmap_dir}.${NC}"
        return
    fi

    local combined_data=$(awk '
        /Nmap scan report for/ { ip = $NF }
        /open/ {
            split($1, port_info, "/")
            port = port_info[1]
            protocol = port_info[2]
            service = $3
            if (protocol == "tcp" || protocol == "udp") {
                print ip ":" port ":" protocol ":" service
            }
        }' $nmap_files | sort -t: -k1,1V -k2,2n | uniq)

    # Terminal Output Header
    printf "\n%-17s %-20s %-8s %-15s %-15s %-15s %-30s\n" "Traffic From" "Traffic To" "Status" "Source IP" "Dest IP" "Port/Proto" "Notes"
    printf "%-17s %-20s %-8s %-15s %-15s %-15s %-30s\n" "-------------" "--------------------" "------" "---------------" "---------------" "---------------" "------------------------------"

    if [ -z "$combined_data" ]; then
        echo -e "${YELLOW}No open ports found. Recording PASS.${NC}"
        while read -r target; do
            echo "$traffic_from,$target,PASS,$source_ip,N/A,N/A,No open ports detected" >> "$output_csv"
        done < "$targets_file"
    else
        while IFS=: read -r ip port protocol service; do
            local status="PASS"
            local notes=""
            local traffic_to=$(grep -w "$ip" "$targets_file" || echo "$ip")

            if [ "$protocol" == "tcp" ]; then
                if nc -zv -w 2 "$ip" "$port" &>/dev/null; then
                    status="FAIL"
                    notes=$(nc -zvvv -w 2 "$ip" "$port" 2>&1 | grep -Ei "(open|succeeded|refused)" | sed 's/^.*: //' | sed "s/$/ (TCP)/" | head -n1)
                    if [ -z "$notes" ]; then notes="Connection Successful (TCP)"; fi
                else
                    notes="Connection Refused/Timeout (TCP)"
                fi
            elif [ "$protocol" == "udp" ]; then
                if nc -uzv -w 2 "$ip" "$port" &>/dev/null; then
                    status="FAIL"
                    notes=$(nc -uzvvv -w 2 "$ip" "$port" 2>&1 | grep -Ei "(open|succeeded|refused)" | sed 's/^.*: //' | sed "s/$/ (UDP)/" | head -n1)
                    if [ -z "$notes" ]; then notes="Connection Successful (UDP)"; fi
                else
                    notes="No Response (UDP)"
                fi
            fi

            echo "$traffic_from,$traffic_to,$status,$source_ip,$ip,$port/$protocol,$notes" >> "$output_csv"
            
            local color_status="$GREEN$status$NC"
            if [ "$status" == "FAIL" ]; then color_status="$RED$status$NC"; fi
            
            printf "%-17s %-20s %-18b %-15s %-15s %-15s %-30s\n" \
                "$traffic_from" "${traffic_to:0:20}" "$color_status" "$source_ip" "$ip" "$port/$protocol" "$notes"
                
        done <<< "$combined_data"
    fi
    echo -e "\n${GREEN}Iteration complete. Saved to $output_csv${NC}"
}
