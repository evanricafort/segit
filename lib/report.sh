# File: lib/report.sh

# Function to generate a comprehensive HTML report
generate_html_report() {
    local targets="$1"
    local targets_file="$2"
    local start_time="$3"
    local end_time="$4"
    local html_file="SegIt_Report.html"
    
    local report_title="SegIt! Network Segmentation Test Report"
    if [ -n "$targets" ]; then
        report_title+=" for $targets"
    elif [ -n "$targets_file" ]; then
        report_title+=" for targets from file: $targets_file"
    fi

    # Check if files exist before reading, and get line counts
    local total_targets_count=0
    if [ -f "../all_targets.txt" ]; then
        total_targets_count=$(wc -l < "../all_targets.txt")
    fi
    
    local live_hosts_count=0
    if [ -f "../live_hosts.txt" ]; then
        live_hosts_count=$(wc -l < "../live_hosts.txt")
    fi

    local tcp_open_ports_count=0
    if [ -f "open_tcp_ports.txt" ]; then
        tcp_open_ports_count=$(awk '{print $1}' open_tcp_ports.txt | wc -l)
    fi

    local udp_open_ports_count=0
    if [ -f "open_udp_ports.txt" ]; then
        udp_open_ports_count=$(awk '{print $1}' open_udp_ports.txt | wc -l)
    fi

    # HTML Header
    cat << EOF > "$html_file"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$report_title</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f4f7f6; color: #333; }
        .container { max-width: 1000px; margin: auto; background: #fff; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); border-radius: 8px; }
        h1, h2, h3 { color: #2c3e50; }
        header { text-align: center; padding: 10px 0; border-bottom: 2px solid #e0e0e0; margin-bottom: 20px; }
        .section { margin-bottom: 30px; }
        .summary-table, .results-table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        .summary-table th, .summary-table td, .results-table th, .results-table td { padding: 12px 15px; text-align: left; border: 1px solid #ddd; }
        .summary-table th, .results-table th { background-color: #ecf0f1; font-weight: bold; }
        .pass { color: #27ae60; font-weight: bold; }
        .fail { color: #c0392b; font-weight: bold; }
        .info { background-color: #f0f3f5; padding: 10px; border-left: 5px solid #3498db; }
        pre { background: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; white-space: pre-wrap; word-wrap: break-word; }
        .tab-menu { display: flex; border-bottom: 2px solid #ddd; }
        .tab-button { background-color: #f4f7f6; border: none; outline: none; cursor: pointer; padding: 14px 20px; transition: 0.3s; font-size: 16px; margin-right: 5px; border-top-left-radius: 5px; border-top-right-radius: 5px; }
        .tab-button:hover { background-color: #e2e4e6; }
        .tab-button.active { background-color: #fff; border: 1px solid #ddd; border-bottom: 1px solid #fff; }
        .tab-content { display: none; padding: 20px 0; border: 1px solid #ddd; border-top: none; }
        .tab-content.active { display: block; }
    </style>
</head>
<body>
<div class="container">
    <header>
        <h1>$report_title</h1>
        <p><strong>Scan Started:</strong> $start_time</p>
        <p><strong>Scan Finished:</strong> $end_time</p>
    </header>
    
    <div class="section">
        <h2>Scan Scope</h2>
        <div class="info">
            This test was performed on the following target(s) or subnet(s).
        </div>
        <pre>$(cat ../all_targets.txt 2>/dev/null)</pre>
    </div>

    <div class="section">
        <h2>Test Summary</h2>
        <div class="info">
            This report details the findings from network segmentation tests. It identifies open ports and services, along with verification attempts to confirm accessibility.
        </div>
        <table class="summary-table">
            <thead>
                <tr>
                    <th>Metric</th>
                    <th>Value</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Total Targets</td>
                    <td>$total_targets_count</td>
                </tr>
                <tr>
                    <td>Live Hosts Found</td>
                    <td>$live_hosts_count</td>
                </tr>
                <tr>
                    <td>Total TCP Open Ports</td>
                    <td>$tcp_open_ports_count</td>
                </tr>
                <tr>
                    <td>Total UDP Open Ports</td>
                    <td>$udp_open_ports_count</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Detailed Findings</h2>
        <div class="tab-menu">
            <button class="tab-button active" onclick="openTab(event, 'all-open-ports')">All Open Ports</button>
            <button class="tab-button" onclick="openTab(event, 'netcat-verifications')">Service Verifications</button>
        </div>

        <div id="all-open-ports" class="tab-content active">
            <h3>All Discovered Open Ports</h3>
            <p>This table lists all ports identified as open by the Nmap scans, regardless of protocol.</p>
            <table class="results-table">
                <thead>
                    <tr>
                        <th>IP Address</th>
                        <th>Port</th>
                        <th>Protocol</th>
                        <th>Service</th>
                    </tr>
                </thead>
                <tbody>
EOF
    # Populate a combined table with all open ports from all Nmap XML files
    if [ -f "nmap_output_files/service_scan.xml" ]; then
        nmap_xml_parser "nmap_output_files/service_scan.xml" "all" >> "$html_file"
    fi
    
    cat << EOF >> "$html_file"
                </tbody>
            </table>
        </div>

        <div id="netcat-verifications" class="tab-content">
            <h3>TCP Verification Results</h3>
            <pre>$(cat tcp_verification_results.txt 2>/dev/null)</pre>
            
            <h3>UDP Verification Results</h3>
            <pre>$(cat udp_verification_results.txt 2>/dev/null)</pre>
        </div>
    </div>
    
    <div class="section">
        <h2>Raw Scan Data</h2>
        <p>For detailed analysis, refer to the original Nmap output files located in the <code>nmap_output_files</code> directory.</p>
    </div>

    <footer>
        <p style="text-align: center; color: #95a5a6;">Generated by SegIt! on $(date +"%Y-%m-%d")</p>
    </footer>

    <script>
        function openTab(evt, tabName) {
            var i, tabcontent, tabbuttons;
            tabcontent = document.getElementsByClassName("tab-content");
            for (i = 0; i < tabcontent.length; i++) {
                tabcontent[i].style.display = "none";
            }
            tabbuttons = document.getElementsByClassName("tab-button");
            for (i = 0; i < tabbuttons.length; i++) {
                tabbuttons[i].className = tabbuttons[i].className.replace(" active", "");
            }
            document.getElementById(tabName).style.display = "block";
            evt.currentTarget.className += " active";
        }
    </script>
</div>
</body>
</html>
EOF
    echo -e "${GREEN}HTML report generated at ${YELLOW}$(pwd)/$html_file${NC}"
}

# Helper function to parse Nmap XML and format for HTML
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
                        echo "<tr><td>$ip</td><td>$port</td><td>$protocol</td><td>$service</td></tr>"
                    fi
                fi
            done
        done
    fi
}
