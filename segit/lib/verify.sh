# Function to perform advanced, protocol-aware service verification
verify_services() {
    local tcp_results="tcp_verification_results.txt"
    local udp_results="udp_verification_results.txt"

    # Clear previous results
    : > "$tcp_results"
    : > "$udp_results"

    echo -e "\n${CYAN}Starting advanced service verifications...${NC}"

    # Parse open ports from the Nmap XML output
    local open_ports_file="open_ports_with_services.txt"
    if [ -f "nmap_output_files/service_scan.xml" ]; then
        nmap_xml_parser "nmap_output_files/service_scan.xml" "all" > "$open_ports_file"
    fi

    if [ ! -s "$open_ports_file" ]; then
        echo -e "${RED}No open ports found for verification.${NC}"
        return
    fi

    while read -r ip port proto service; do
        echo -e "${MAGENTA}Verifying ${YELLOW}$service ($proto/$port)${MAGENTA} on ${YELLOW}$ip${NC}"
        case "$proto/$port" in
            # HTTP/S checks
            "tcp/80" | "tcp/443")
                # Use curl to send a HEAD request and check for a 200/301/302 response
                if curl --head --connect-timeout 5 "http://$ip:$port" &> /dev/null; then
                    echo -e "${GREEN}  -> Success: Web service confirmed.${NC}" | tee -a "$tcp_results"
                else
                    echo -e "${RED}  -> Failure: Web service did not respond as expected.${NC}" | tee -a "$tcp_results"
                fi
                ;;
            # SSH checks
            "tcp/22")
                # Use ssh-keyscan to grab the server's public key banner
                if ssh-keyscan -T 5 "$ip" 2>/dev/null | grep -q 'ssh-rsa'; then
                    echo -e "${GREEN}  -> Success: SSH service banner received.${NC}" | tee -a "$tcp_results"
                else
                    echo -e "${RED}  -> Failure: SSH service did not respond with a valid banner.${NC}" | tee -a "$tcp_results"
                fi
                ;;
            # DNS checks
            "udp/53" | "tcp/53")
                # Use dig to query a common domain
                if dig @$ip google.com +short &> /dev/null; then
                    echo -e "${GREEN}  -> Success: DNS service responded to query.${NC}" | tee -a "$udp_results"
                else
                    echo -e "${RED}  -> Failure: DNS service did not resolve query.${NC}" | tee -a "$udp_results"
                fi
                ;;
            # Default fallback for other TCP ports
            "tcp/"*)
                # Fallback to a simple netcat connection test
                if nc -z -w 2 "$ip" "$port"; then
                    echo -e "${YELLOW}  -> Note: No specific protocol check available. TCP connection succeeded.${NC}" | tee -a "$tcp_results"
                else
                    echo -e "${RED}  -> Failure: TCP connection refused or timed out.${NC}" | tee -a "$tcp_results"
                fi
                ;;
            # Default fallback for other UDP ports
            "udp/"*)
                # Fallback to a simple netcat connection test
                if nc -u -z -w 2 "$ip" "$port"; then
                    echo -e "${YELLOW}  -> Note: No specific protocol check available. UDP connection succeeded.${NC}" | tee -a "$udp_results"
                else
                    echo -e "${RED}  -> Failure: UDP connection failed or timed out.${NC}" | tee -a "$udp_results"
                fi
                ;;
        esac
    done < "$open_ports_file"

    echo -e "${GREEN}Advanced service verifications completed.${NC}"
}

# Helper function to parse Nmap XML and format for internal use
nmap_xml_parser() {
    local xml_file="$1"
    local proto_filter="$2"
    if [ -f "$xml_file" ]; then
        grep -oP '<host .*?</host>' "$xml_file" | while read -r host_line; do
            ip=$(echo "$host_line" | grep -oP '(?<=addr=").*?(?=")')
            echo "$host_line" | grep -oP '<port protocol=".*?" portid=".*?">.*?</port>' | while read -r port_line; do
                port=$(echo "$port_line" | grep -oP '(?<=portid=").*?(?=")')
                protocol=$(echo "$port_line" | grep -oP '(?<=protocol=").*?(?=")')
                service=$(echo "$port_line" | grep -oP '(?<=<service name=").*?(?=")')
                state=$(echo "$port_line" | grep -oP '(?<=<state state=").*?(?=")')

                if [ "$state" == "open" ]; then
                    if [ "$proto_filter" == "all" ] || [ "$protocol" == "$proto_filter" ]; then
                        echo "$ip $port $protocol $service"
                    fi
                fi
            done
        done
    fi
}